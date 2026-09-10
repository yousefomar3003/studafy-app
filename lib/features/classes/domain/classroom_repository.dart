import '../../../core/ids.dart';
import 'classroom.dart';

/// Port for the classes slice. Adapters may throw; the interactor maps every
/// error onto the failure taxonomy before anything reaches presentation.
abstract interface class ClassroomRepository {
  /// Classrooms visible to the current teacher under RLS.
  Future<List<ClassroomSummary>> listClasses();

  /// Creates a classroom. Only implemented by the preview adapter today.
  Future<void> createClass(NewClassDraft draft);

  /// Invite link for a classroom. Preview-only until the classes service.
  Future<String> inviteLinkFor(ClassroomId id);
}
