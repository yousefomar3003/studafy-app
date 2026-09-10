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
    return runCatching(() => repository.inviteLinkFor(id));
  }
}
