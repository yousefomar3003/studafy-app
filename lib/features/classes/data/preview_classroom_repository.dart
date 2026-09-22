import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../studafy_database.dart';
import '../domain/classroom.dart';
import '../domain/classroom_repository.dart';

/// Preview (synthetic) adapter. This is the old preview read path — the
/// exact `StudafyDatabase.classes()` query the legacy page used — wrapped
/// behind the port and mapped onto typed entities. Dynamic map handling
/// lives here, in the data layer, and nowhere else.
class PreviewClassroomRepository implements ClassroomRepository {
  const PreviewClassroomRepository();

  static const _palette = [
    0xFF241D73,
    0xFF20C6E8,
    0xFF7737EE,
    0xFFFF6B6B,
    0xFF20B981,
  ];

  @override
  Future<List<ClassroomSummary>> listClasses() async {
    final rows = await StudafyDatabase.instance.classes();
    return [
      for (final row in rows)
        ClassroomSummary(
          id: ClassroomId('${row['id'] as int}'),
          name: '${row['name']}',
          grade: '${row['grade']}',
          section: '${row['section']}',
          room: row['room'] == null ? null : '${row['room']}',
          colorValue: row['color'] as int?,
          studentCount: (row['student_count'] as int?) ?? 0,
          weeklySessions: row['weekly_sessions'] as int?,
        ),
    ];
  }

  @override
  Future<void> createClass(NewClassDraft draft) {
    return StudafyDatabase.instance.addClassWithSchedule(
      {
        'name': draft.name,
        'grade': draft.grade,
        'section': draft.section,
        'room': draft.room,
        'start_time': draft.firstSessionStart,
        'end_time': draft.firstSessionEnd,
        'weekly_sessions': draft.weeklySessions,
        'color': _palette[DateTime.now().microsecond % _palette.length],
      },
      [
        for (var i = 0; i < draft.sessions.length; i++)
          {
            'weekday': draft.sessions[i].weekday,
            'session_number': i + 1,
            'start_time': draft.sessions[i].startTime,
            'end_time': draft.sessions[i].endTime,
          },
      ],
    );
  }

  @override
  Future<String> inviteLinkFor(ClassroomId id) {
    final localId = int.tryParse(id.value);
    if (localId == null) {
      throw StateError('Preview invite links need a local class id.');
    }
    return StudafyDatabase.instance.createInviteLink(localId);
  }

  @override
  Future<ClassJoinLinkInfo?> activeJoinLink(String classroomId) async => null;

  @override
  Future<void> revokeJoinLink(String linkId) async =>
      throw const Failure.unsupported('Join links need the school service.');

  @override
  Future<JoinedClass> joinWithLink(String token) {
    throw const Failure.unsupported(
      'Joining a class by link needs the school service.',
    );
  }
}
