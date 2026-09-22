import '../../../core/ids.dart';
import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/classroom.dart';
import '../domain/classroom_repository.dart';

/// Loads and mutates the teacher's class list through the repository port.
/// Presentation code calls this, never a database or provider client.
class ClassListInteractor {
  ClassListInteractor({required this.repository, required this.telemetry});

  final ClassroomRepository repository;
  final Telemetry telemetry;

  Future<Result<List<ClassroomSummary>>> loadClasses() {
    return runCatching(() async {
      final classes = await repository.listClasses();
      telemetry.event('classes_loaded', {'count': classes.length});
      return classes;
    });
  }

  Future<Result<void>> createClass(NewClassDraft draft) {
    return runCatching(() async {
      await repository.createClass(draft);
      telemetry.event('class_created');
    });
  }

  Future<Result<String>> inviteLinkFor(ClassroomId id) {
    return runCatching(() async {
      final link = await repository.inviteLinkFor(id);
      telemetry.event('class_join_link_created');
      return link;
    });
  }

  Future<Result<ClassJoinLinkInfo?>> activeJoinLink(String classroomId) =>
      runCatching(() => repository.activeJoinLink(classroomId));

  Future<Result<void>> revokeJoinLink(String linkId) => runCatching(() async {
    await repository.revokeJoinLink(linkId);
    telemetry.event('class_join_link_revoked');
  });

  /// Redeems a shared class link. The caller is not a member yet, so this is
  /// the one call here that does not presuppose a school.
  Future<Result<JoinedClass>> joinWithLink(String token) {
    return runCatching(() async {
      final joined = await repository.joinWithLink(token);
      telemetry.event('class_joined_via_link');
      return joined;
    });
  }
}
