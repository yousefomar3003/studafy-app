import '../../../core/account_lifecycle.dart';
import '../domain/account_repository.dart';

/// Adapts the authenticated session surface to the account port (AUTH-030).
///
/// Deletion is an authentication-lifecycle operation — it needs the same
/// recent-auth grant as the rest of that surface — but features may not import
/// one another, so the operations arrive as functions the composition root
/// supplies from the session slice. That keeps exactly one implementation of
/// the deletion calls without coupling the two features.
class SessionAccountRepository implements AccountRepository {
  const SessionAccountRepository({
    required Future<DeletionImpact> Function() loadImpact,
    required Future<DeletionRequest> Function({required String reasonCode})
    submitRequest,
    required Future<bool> Function() cancelRequest,
  }) // Private fields from public parameter names, so call sites read
    // `loadImpact:` rather than `_loadImpact:`.
    // ignore_for_file: prefer_initializing_formals
    : _loadImpact = loadImpact,
       _submitRequest = submitRequest,
       _cancelRequest = cancelRequest;

  final Future<DeletionImpact> Function() _loadImpact;
  final Future<DeletionRequest> Function({required String reasonCode})
  _submitRequest;
  final Future<bool> Function() _cancelRequest;

  @override
  Future<DeletionImpact> deletionImpact() => _loadImpact();

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) => _submitRequest(reasonCode: reasonCode);

  @override
  Future<bool> cancelAccountDeletion() => _cancelRequest();
}

/// Account operations for synthetic builds: refusals, not fake successes.
class UnavailableAccountRepository implements AccountRepository {
  const UnavailableAccountRepository();

  static Never _unavailable() => throw StateError(
    'Account deletion requires the server API (SEC-001 containment).',
  );

  @override
  Future<DeletionImpact> deletionImpact() async => _unavailable();

  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) async => _unavailable();

  @override
  Future<bool> cancelAccountDeletion() async => _unavailable();
}
