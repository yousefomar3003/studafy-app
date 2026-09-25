import '../../../data/contracts/v1_client.generated.dart';
import '../domain/teacher_workspace_repository.dart';

/// Calls the one endpoint that can give an account its first membership
/// without a platform operator.
class ApiTeacherWorkspaceRepository implements TeacherWorkspaceRepository {
  ApiTeacherWorkspaceRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<void> createForCurrentTeacher({
    required String locale,
    String? timezone,
  }) async {
    await _client.createTeacherWorkspace(
      V1CreateTeacherWorkspaceRequestDto(
        // The name is left to the server, which uses the teacher's own
        // display name. Asking for one here would put the school back in
        // front of a person the product never shows it to.
        locale: locale == 'ar' ? 'ar' : 'en',
        timezone: timezone,
      ),
      // Derived from nothing random: a retry after a dropped response must
      // not read as a second attempt to create a second workspace.
      idempotencyKey: 'teacher-workspace-v1',
    );
  }
}
