import '../../../core/result.dart';
import '../../../core/account_lifecycle.dart';
import '../domain/account_repository.dart';

/// Drives the account-rights flows (AUTH-030).
///
/// The screen never talks to a repository directly, and never decides on its
/// own what deletion does: [loadImpact] returns the server's computation, and
/// that same summary is what the server stores with the request.
class AccountInteractor {
  const AccountInteractor(this._repository);

  final AccountRepository _repository;

  Future<Result<DeletionImpact>> loadImpact() =>
      runCatching(_repository.deletionImpact);

  Future<Result<DeletionRequest>> requestDeletion({
    required String reasonCode,
  }) => runCatching(
    () => _repository.requestAccountDeletion(reasonCode: reasonCode),
  );

  Future<Result<bool>> cancelDeletion() =>
      runCatching(_repository.cancelAccountDeletion);
}
