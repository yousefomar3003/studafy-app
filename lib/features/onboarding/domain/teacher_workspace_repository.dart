/// Creates the workspace a teacher's own classes hang from.
///
/// The product has no concept of a school, so nothing here is named or shown
/// to anyone: a teacher signs up and starts making classes. The tenant exists
/// because the schema, its row-level security and its audit trail are all
/// scoped to one, not because the person should ever think about it.
abstract class TeacherWorkspaceRepository {
  /// Called once, on the first sign-in of an account with no membership.
  ///
  /// The server refuses a second call for the same account, so this is safe
  /// to retry: a refusal means the workspace is already there.
  Future<void> createForCurrentTeacher({
    required String locale,
    String? timezone,
  });
}
