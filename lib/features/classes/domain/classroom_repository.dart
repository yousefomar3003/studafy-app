import '../../../core/ids.dart';
import 'classroom.dart';

/// Port for the classes slice. Adapters may throw; the interactor maps every
/// error onto the failure taxonomy before anything reaches presentation.
abstract interface class ClassroomRepository {
  /// Classrooms visible to the current teacher under RLS.
  Future<List<ClassroomSummary>> listClasses();

  /// Creates a classroom. Only implemented by the preview adapter today.
  Future<void> createClass(NewClassDraft draft);

  /// Shareable join link for a classroom, replacing whatever was live.
  Future<String> inviteLinkFor(ClassroomId id);

  /// The classroom's live join link, or null when none is active.
  Future<ClassJoinLinkInfo?> activeJoinLink(String classroomId);

  /// Revokes a join link, so the URL stops working for anyone holding it.
  Future<void> revokeJoinLink(String linkId);

  /// Joins a class from a shared link.
  ///
  /// The caller is not a member of that school yet, which is the whole point
  /// of the link, so this must not depend on an active membership the way
  /// every other call here does.
  Future<JoinedClass> joinWithLink(String token);
}
