import '../../../core/account_lifecycle.dart';
import '../../../core/result.dart';
import '../domain/account_repository.dart';
import '../domain/data_export.dart';
import '../domain/profile_repository.dart';

/// Drives the account-rights flows (AUTH-030).
///
/// The screen never talks to a repository directly, and never decides on its
/// own what deletion does: [loadImpact] returns the server's computation, and
/// that same summary is what the server stores with the request.
class AccountInteractor {
  const AccountInteractor(
    this._repository, {
    DataExportRepository? exports,
    ProfileRepository? profiles,
  })
    // ignore: prefer_initializing_formals
    : _exports = exports,
       // ignore: prefer_initializing_formals
       _profiles = profiles;

  final AccountRepository _repository;
  final DataExportRepository? _exports;
  final ProfileRepository? _profiles;

  /// Whether this build can read and rename the person's own profile.
  bool get profileAvailable => _profiles != null;

  Future<Result<OwnProfile>> ownProfile() =>
      runCatching(() => _profiles!.readOwn());

  /// Saves a new display name. Refuses an empty or over-long one before it
  /// reaches the server, which checks the same again.
  Future<Result<OwnProfile>> rename(String raw) => runCatching(() async {
    final name = normaliseDisplayName(raw);
    if (name == null) {
      throw const FormatException('A name must be 1-160 characters.');
    }
    return _profiles!.rename(name);
  });

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
