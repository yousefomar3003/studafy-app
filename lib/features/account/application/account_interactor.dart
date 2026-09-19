import '../../../core/result.dart';
import '../../../core/account_lifecycle.dart';
import '../domain/account_repository.dart';
import '../domain/data_export.dart';

/// Drives the account-rights flows (AUTH-030).
///
/// The screen never talks to a repository directly, and never decides on its
/// own what deletion does: [loadImpact] returns the server's computation, and
/// that same summary is what the server stores with the request.
class AccountInteractor {
  const AccountInteractor(this._repository, {DataExportRepository? exports})
    // ignore: prefer_initializing_formals
    : _exports = exports;

  final AccountRepository _repository;
  final DataExportRepository? _exports;

  /// Right of access (DL-051). Null when this build offers no export.
  bool get exportAvailable => _exports != null;

  Future<Result<DataExportStatus?>> exportStatus() =>
      runCatching(() async => _exports?.status());

  Future<Result<DataExportStatus>> requestExport() =>
      runCatching(() => _exports!.request());

  Future<Result<String>> downloadExport() =>
      runCatching(() => _exports!.download());

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
