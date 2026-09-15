import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../domain/classroom.dart';
import '../domain/classroom_repository.dart';

/// Authoritative API-041 classroom adapter. It never reads or writes the
/// local preview database and never falls back when the service is offline.
class ApiClassroomRepository implements ClassroomRepository {
  ApiClassroomRepository(this._client, {ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance;

  final V1ApiClient _client;
  final ActiveContextController _context;
  final Map<String, String> _pendingKeys = {};

  String get _schoolId {
    final membership = _context.membership;
    if (membership == null || !membership.active) throw Failure.unauthorized;
    return membership.schoolId;
  }

  @override
  Future<List<ClassroomSummary>> listClasses() async {
    final result = <ClassroomSummary>[];
    String? cursor;
    do {
      final page = await _client.listClassrooms(
        schoolId: _schoolId,
        cursor: cursor,
        pageSize: 100,
      );
      result.addAll(page.items.map(_map));
      cursor = page.nextCursor;
    } while (cursor != null);
    return result;
  }

  @override
  Future<void> createClass(NewClassDraft draft) async {
    final fingerprint = [
      _schoolId,
      draft.name,
      draft.grade,
      draft.section,
      draft.room,
      for (final item in draft.sessions)
        '${item.weekday}:${item.startTime}:${item.endTime}',
    ].join('|');
    final key = _pendingKeys.putIfAbsent(
      fingerprint,
      () => 'class-${DateTime.now().microsecondsSinceEpoch}-$fingerprint'
          .hashCode
          .abs()
          .toRadixString(36)
          .padLeft(16, '0'),
    );
    final today = DateTime.now();
    final effectiveFrom =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _client.createClassroom(
      V1CreateClassroomRequestDto(
        schoolId: _schoolId,
        name: draft.name,
        grade: '${draft.grade}',
        section: draft.section,
        room: draft.room,
        schedule: [
          for (final item in draft.sessions)
            V1ScheduleSlotInputDto(
              weekday: item.weekday,
              startsAt: item.startTime,
              endsAt: item.endTime,
              effectiveFrom: effectiveFrom,
              effectiveUntil: null,
            ),
        ],
      ),
      idempotencyKey: key,
    );
    _pendingKeys.remove(fingerprint);
  }

  @override
  Future<String> inviteLinkFor(ClassroomId id) {
    throw const Failure.unsupported(
      'Invitations are unavailable until API-042.',
    );
  }

  static ClassroomSummary _map(V1AcademicClassroomDto value) =>
      ClassroomSummary(
        id: ClassroomId(value.id),
        name: value.name,
        grade: value.grade,
        section: value.section,
        room: value.room,
        colorValue: null,
        studentCount: value.studentCount,
        weeklySessions: value.weeklySessions,
        termName: value.termName,
      );
}
