import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/teacher_workspace_repository.dart';

/// Drives the one action on a new teacher's first screen.
class TeacherWorkspaceInteractor {
  const TeacherWorkspaceInteractor({
    required this.repository,
    required this.telemetry,
  });

  final TeacherWorkspaceRepository repository;
  final Telemetry telemetry;

  Future<Result<void>> create({
    required String locale,
    String? timezone,
  }) async {
    final result = await runCatching(
      () => repository.createForCurrentTeacher(
        locale: locale,
        timezone: timezone,
      ),
    );
    result.fold(
      onSuccess: (_) => telemetry.event('teacher_workspace_created', const {}),
      onFailure: (failure) =>
          telemetry.event('teacher_workspace_failed', {'code': failure.code}),
    );
    return result;
  }
}
