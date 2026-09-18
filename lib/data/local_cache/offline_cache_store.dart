import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'offline_cache_database.dart';

/// One cached row. [payload] is the exact JSON the server DTO round-trips
/// through, so the adapter has a single mapping path whether the data came
/// from the network just now or from cache a week ago.
class CachedEntity {
  const CachedEntity({
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    this.version,
    this.tombstoned = false,
  });

  final String entityId;
  final String? version;
  final Map<String, dynamic> payload;
  final String updatedAt;
  final bool tombstoned;
}

/// A mutation waiting to reach the server, or that has already been
/// attempted and is backing off before retrying.
class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.kind,
    required this.idempotencyKey,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.nextAttemptAt,
    required this.status,
    this.lastError,
  });

  final String id;
  final String kind;
  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final String createdAt;
  final int attempts;
  final DateTime nextAttemptAt;
  final String status;
  final String? lastError;
}

/// DAO over one scoped [OfflineCacheDatabase]. Generic across entity types
/// and mutation kinds so every feature slice reuses the same tables instead
/// of growing its own schema (DRY): the type discriminator is a plain string
/// column, not a new table per feature.
class OfflineCacheStore {
  OfflineCacheStore(OfflineCacheDatabase database) : _db = database.raw;

  final Database _db;

  Future<void> putEntities(String entityType, List<CachedEntity> entities) {
    return _db.transaction((tx) async {
      final batch = tx.batch();
      for (final entity in entities) {
        batch.insert('cache_entries', {
          'entity_type': entityType,
          'entity_id': entity.entityId,
          'version': entity.version,
          'payload': jsonEncode(entity.payload),
          'updated_at': entity.updatedAt,
          'tombstoned': entity.tombstoned ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Merges a single field into an already-cached entity's payload without
  /// disturbing the rest of it, keyed by [resolve] so callers can implement
  /// "don't regress a locally-applied change" (e.g. a read receipt) instead
  /// of a plain last-write-wins overwrite.
  Future<void> mergeEntity(
    String entityType,
    String entityId,
    Map<String, dynamic> Function(Map<String, dynamic> current) resolve,
    String updatedAt,
  ) async {
    final rows = await _db.query(
      'cache_entries',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      limit: 1,
    );
    final current = rows.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    final next = resolve(current);
    await _db.insert('cache_entries', {
      'entity_type': entityType,
      'entity_id': entityId,
      'version': next['version']?.toString(),
      'payload': jsonEncode(next),
      'updated_at': updatedAt,
      'tombstoned': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CachedEntity>> entitiesFor(
    String entityType, {
    bool includeTombstoned = false,
  }) async {
    final rows = await _db.query(
      'cache_entries',
      where: includeTombstoned
          ? 'entity_type = ?'
          : 'entity_type = ? AND tombstoned = 0',
      whereArgs: [entityType],
      orderBy: 'updated_at DESC',
    );
    return [
      for (final row in rows)
        CachedEntity(
          entityId: row['entity_id'] as String,
          version: row['version'] as String?,
          payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
          updatedAt: row['updated_at'] as String,
          tombstoned: (row['tombstoned'] as int) == 1,
        ),
    ];
  }

  Future<String?> cursorFor(String entityType) async {
    final rows = await _db.query(
      'sync_cursor',
      where: 'entity_type = ?',
      whereArgs: [entityType],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['cursor'] as String?;
  }

  Future<void> saveCursor(String entityType, String? cursor) =>
      _db.insert('sync_cursor', {
        'entity_type': entityType,
        'cursor': cursor,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> enqueueMutation(QueuedMutation mutation) =>
      _db.insert('mutation_outbox', {
        'id': mutation.id,
        'kind': mutation.kind,
        'idempotency_key': mutation.idempotencyKey,
        'payload': jsonEncode(mutation.payload),
        'created_at': mutation.createdAt,
        'attempts': mutation.attempts,
        'next_attempt_at': mutation.nextAttemptAt.toUtc().toIso8601String(),
        'last_error': mutation.lastError,
        'status': mutation.status,
      });

  Future<List<QueuedMutation>> duePending(DateTime asOf) async {
    final rows = await _db.query(
      'mutation_outbox',
      where: 'status = ? AND next_attempt_at <= ?',
      whereArgs: ['pending', asOf.toUtc().toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return rows.map(_mutationFromRow).toList();
  }

  /// Every pending mutation regardless of backoff timing. Used when the
  /// caller has an explicit "try now" signal (reconnect, pull-to-refresh):
  /// backoff exists to space out unattended automatic retries, not to make
  /// the user wait out a timer they just asked to skip.
  Future<List<QueuedMutation>> allPending() async {
    final rows = await _db.query(
      'mutation_outbox',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
    return rows.map(_mutationFromRow).toList();
  }

  Future<List<QueuedMutation>> all() async {
    final rows = await _db.query('mutation_outbox', orderBy: 'created_at ASC');
    return rows.map(_mutationFromRow).toList();
  }

  QueuedMutation _mutationFromRow(Map<String, Object?> row) => QueuedMutation(
    id: row['id'] as String,
    kind: row['kind'] as String,
    idempotencyKey: row['idempotency_key'] as String,
    payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
    createdAt: row['created_at'] as String,
    attempts: row['attempts'] as int,
    nextAttemptAt: DateTime.parse(row['next_attempt_at'] as String),
    status: row['status'] as String,
    lastError: row['last_error'] as String?,
  );

  Future<void> markDone(String id) => _db.update(
    'mutation_outbox',
    {'status': 'done'},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markRetry(
    String id,
    int attempts,
    DateTime nextAttemptAt,
    String error,
  ) => _db.update(
    'mutation_outbox',
    {
      'attempts': attempts,
      'next_attempt_at': nextAttemptAt.toUtc().toIso8601String(),
      'last_error': error,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markFailed(String id, String error) => _db.update(
    'mutation_outbox',
    {'status': 'failed', 'last_error': error},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> markConflict(String id, String error) => _db.update(
    'mutation_outbox',
    {'status': 'conflict', 'last_error': error},
    where: 'id = ?',
    whereArgs: [id],
  );
}
