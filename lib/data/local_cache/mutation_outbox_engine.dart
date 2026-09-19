import 'dart:async';

import '../contracts/v1_http_transport.dart';
import 'offline_cache_store.dart';
import 'uuid.dart';

/// What happened when a queued mutation was replayed against the server.
sealed class MutationOutcome {
  const MutationOutcome();
}

/// The server accepted it. Carries the response body so the caller can
/// reconcile the cache with any server-assigned fields.
class MutationDone extends MutationOutcome {
  const MutationDone(this.response);
  final Map<String, dynamic> response;
}

/// The server had already applied this exact idempotency key before —
/// itself a success, just not a fresh one. Kept distinct from [MutationDone]
/// so telemetry can tell a first-time success from a replay landing safely.
class MutationAlreadyApplied extends MutationOutcome {
  const MutationAlreadyApplied();
}

/// A transient failure (network unreachable, timeout, 5xx, another replay of
/// the same key still in flight). The mutation stays queued and is retried
/// with backoff.
class MutationTransientFailure extends MutationOutcome {
  const MutationTransientFailure(this.reason);
  final String reason;
}

/// The entity moved under this mutation (`VERSION_CONFLICT`). The mutation
/// is not retried as-is: it is removed from the active queue and the caller
/// is told to reconcile, because blindly retrying would silently overwrite
/// someone else's change.
class MutationConflict extends MutationOutcome {
  const MutationConflict(this.reason);
  final String reason;
}

/// A permanent, non-retryable rejection (validation, forbidden, not found).
/// Retrying would never succeed, so it is parked as failed rather than
/// looping forever.
class MutationRejected extends MutationOutcome {
  const MutationRejected(this.reason);
  final String reason;
}

/// The session itself is gone. Draining stops entirely — every other queued
/// mutation stays pending untouched, because attempting them now would just
/// produce the same session-lost result and mask it behind a batch of
/// spurious "failed" entries.
class MutationSessionLost extends MutationOutcome {
  const MutationSessionLost();
}

typedef MutationExecutor = Future<MutationOutcome> Function(
  QueuedMutation mutation,
);

/// Drains one feature's mutation queue against its own executor (MOB-070).
///
/// Generic over the entity/kind: a feature's data adapter supplies the
/// executor that knows how to turn a queued payload into a `/v1` call. The
/// engine only owns retry timing, duplicate-safety (the idempotency key is
/// generated once at enqueue time and never changes across retries), and the
/// conflict/session-lost/failure classification shared by every slice.
class MutationOutboxEngine {
  MutationOutboxEngine({
    required OfflineCacheStore store,
    required MutationExecutor executor,
    void Function(QueuedMutation mutation, String reason)? onConflict,
    void Function(QueuedMutation mutation, String reason)? onRejected,
    Duration Function(int attempts)? backoff,
  }) // Not initializing formals: the fields are private, and `this._store`
    // would put the underscored spelling in every call site.
    // ignore_for_file: prefer_initializing_formals
    : _store = store,
       _executor = executor,
       _onConflict = onConflict,
       _onRejected = onRejected,
       _backoff = backoff ?? _defaultBackoff;

  final OfflineCacheStore _store;
  final MutationExecutor _executor;
  final void Function(QueuedMutation mutation, String reason)? _onConflict;
  final void Function(QueuedMutation mutation, String reason)? _onRejected;
  final Duration Function(int attempts) _backoff;

  bool _draining = false;

  static Duration _defaultBackoff(int attempts) {
    final seconds = (1 << attempts.clamp(0, 8)).clamp(1, 300);
    return Duration(seconds: seconds);
  }

  /// Queues [payload] under [kind] and returns the id assigned to it. The
  /// idempotency key travels with the mutation for its entire life, so a
  /// replay after a crash mid-flight is provably the same request to the
  /// server, not a duplicate.
  Future<String> enqueue({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    final id = generateUuidV4();
    await _store.enqueueMutation(
      QueuedMutation(
        id: id,
        kind: kind,
        idempotencyKey: generateUuidV4(),
        payload: payload,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        attempts: 0,
        nextAttemptAt: DateTime.now().toUtc(),
        status: 'pending',
      ),
    );
    return id;
  }

  /// Attempts every mutation due for retry, in FIFO order. Safe to call from
  /// a connectivity-regained listener, an app-resume hook, or a manual
  /// pull-to-refresh — concurrent calls collapse into the call already in
  /// flight instead of racing the same rows.
  ///
  /// [force] skips the backoff timer: an explicit "try now" signal (the
  /// caller just detected reconnection, or the user pulled to refresh)
  /// should not still be waiting out a delay computed from the last
  /// unattended automatic failure.
  Future<void> drain({bool force = false}) async {
    if (_draining) return;
    _draining = true;
    try {
      final due = force
          ? await _store.allPending()
          : await _store.duePending(DateTime.now().toUtc());
      for (final mutation in due) {
        final outcome = await _attempt(mutation);
        if (outcome is MutationSessionLost) return;
      }
    } finally {
      _draining = false;
    }
  }

  Future<MutationOutcome> _attempt(QueuedMutation mutation) async {
    MutationOutcome outcome;
    try {
      outcome = await _executor(mutation);
    } on V1ApiException catch (error) {
      outcome = _classify(error);
    } catch (error) {
      outcome = MutationTransientFailure(error.toString());
    }

    switch (outcome) {
      case MutationDone() || MutationAlreadyApplied():
        await _store.markDone(mutation.id);
      case MutationTransientFailure(:final reason):
        await _store.markRetry(
          mutation.id,
          mutation.attempts + 1,
          DateTime.now().toUtc().add(_backoff(mutation.attempts + 1)),
          reason,
        );
      case MutationConflict(:final reason):
        await _store.markConflict(mutation.id, reason);
        _onConflict?.call(mutation, reason);
      case MutationRejected(:final reason):
        await _store.markFailed(mutation.id, reason);
        _onRejected?.call(mutation, reason);
      case MutationSessionLost():
        // Left pending on purpose: this mutation did nothing wrong, the
        // session did. It replays once a new session exists.
        break;
    }
    return outcome;
  }

  static MutationOutcome _classify(V1ApiException error) {
    if (error.isUnauthenticated || error.isReauthRequired) {
      return const MutationSessionLost();
    }
    if (error.code == 'IDEMPOTENCY_KEY_REUSED') {
      return MutationConflict(error.code);
    }
    if (error.code == 'IDEMPOTENCY_IN_PROGRESS') {
      return MutationTransientFailure(error.code);
    }
    if (error.code == 'VERSION_CONFLICT') {
      return MutationConflict(error.code);
    }
    if (error.status == 429 || error.status >= 500) {
      return MutationTransientFailure(error.code);
    }
    return MutationRejected(error.code);
  }
}
