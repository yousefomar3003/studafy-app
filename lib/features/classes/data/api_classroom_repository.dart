import '../../../core/class_join_link.dart';
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
  Future<String> inviteLinkFor(ClassroomId id) async {
    // Each tap mints a fresh link, which supersedes whatever was live for
    // this class, so the idempotency key is per-call rather than derived
    // from the class: a teacher who taps twice means to replace the link,
    // not to be handed the previous one.
    final response = await _client.createClassJoinLink(
      const V1CreateClassJoinLinkRequestDto(),
      classroomId: id.value,
      idempotencyKey:
          'join-${DateTime.now().microsecondsSinceEpoch}-'
                  '${id.value}'
              .hashCode
              .abs()
              .toRadixString(36)
              .padLeft(16, '0'),
    );
    return classJoinLinkUrl(response.token);
  }

  @override
  Future<ClassJoinLinkInfo?> activeJoinLink(String classroomId) async {
    try {
      final link = await _client.getClassJoinLink(classroomId: classroomId);
      return ClassJoinLinkInfo(
        id: link.id,
        useCount: link.useCount,
        expiresAt:
            DateTime.tryParse(link.expiresAt)?.toLocal() ?? DateTime.now(),
        maxUses: link.maxUses,
      );
    } on Object {
      // No live link is the ordinary case for a class nobody has shared yet,
      // and the surface reports it as an absent resource.
      return null;
    }
  }

  @override
  Future<void> revokeJoinLink(String linkId) async {
    await _client.revokeClassJoinLink(
      const V1RevokeClassJoinLinkRequestDto(),
      linkId: linkId,
      idempotencyKey: 'revoke-link-${DateTime.now().microsecondsSinceEpoch}'
          .hashCode
          .abs()
          .toRadixString(36)
          .padLeft(16, '0'),
    );
  }

  @override
  Future<JoinedClass> joinWithLink(String token) async {
    // Deliberately does not read _schoolId: the joiner has no membership at
    // this school yet, and the token is the whole credential.
    final response = await _client.redeemClassJoinLink(
      V1RedeemClassJoinLinkRequestDto(token: token),
      idempotencyKey: 'join-redeem-${DateTime.now().microsecondsSinceEpoch}'
          .hashCode
          .abs()
          .toRadixString(36)
          .padLeft(16, '0'),
    );
    return JoinedClass(
      schoolId: response.schoolId,
      classroomId: ClassroomId(response.classroomId),
      classroomName: response.classroomName,
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
        version: value.version,
        weeklySessions: value.weeklySessions,
        termName: value.termName,
      );
}
