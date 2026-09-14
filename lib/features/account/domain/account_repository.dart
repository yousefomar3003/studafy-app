import '../../../core/account_lifecycle.dart';

/// Port for the account-rights operations the deletion screen needs
/// (AUTH-030).
///
/// It is a narrow view over the session port rather than a second
/// implementation, so there is exactly one path to the deletion endpoints and
/// exactly one place that obtains the recent-auth grant they require.
abstract interface class AccountRepository {
  /// What deletion removes and what the school retains, computed server-side.
  Future<DeletionImpact> deletionImpact();

  /// Schedules deletion after a recent-auth challenge.
  Future<DeletionRequest> requestAccountDeletion({required String reasonCode});

  /// Cancels a scheduled deletion from inside the app.
  Future<bool> cancelAccountDeletion();
}
