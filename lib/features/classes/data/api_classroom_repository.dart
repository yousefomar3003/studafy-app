import '../../../core/class_join_link.dart';
import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../domain/classroom.dart';
import '../domain/classroom_repository.dart';
import '../../../core/idempotency.dart';

/// Authoritative API-041 classroom adapter. It never reads or writes the
/// local preview database and never falls back when the service is offline.
class ApiClassroomRepository implements ClassroomRepository {
  ApiClassroomRepository(
    this._client, {
    required ActiveContextController context,
  }) : _context = context;

  final V1ApiClient _client;
  final ActiveContextController _context;
  final _keys = PendingIdempotencyKeys();

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
    final key = _keys.keyFor('class', fingerprint);
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
    _keys.completed('class', fingerprint);
  }

  @override
  Future<ClassInvite> inviteLinkFor(ClassroomId id) async {
    // Only called to make a new link - none exists yet, or the teacher asked
    // for a new code - and a new link supersedes the old, so the key is per
    // call. Showing the existing code is activeJoinLink's job.
    final response = await _client.createClassJoinLink(
      // A code is shared once, at the start: it lasts the school year unless
      // the teacher replaces it.
      V1CreateClassJoinLinkRequestDto(
        expiresAt: DateTime.now()
            .add(const Duration(days: 365))
            .toUtc()
            .toIso8601String(),
      ),
      classroomId: id.value,
      idempotencyKey: newIdempotencyKey('join-link'),
    );
    return ClassInvite(
      link: classJoinLinkUrl(response.token),
      code: response.code,
    );
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
        invite: link.token == null
            ? null
            : ClassInvite(link: classJoinLinkUrl(link.token!), code: link.code),
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
      idempotencyKey: newIdempotencyKey('revoke-link'),
    );
  }

  @override
  Future<JoinedClass> joinWithLink(String token) async {
    // Deliberately does not read _schoolId: the joiner has no membership at
    // this school yet, and the token is the whole credential.
    final response = await _client.redeemClassJoinLink(
      V1RedeemClassJoinLinkRequestDto(token: token),
      idempotencyKey: newIdempotencyKey('join-redeem'),
    );
    return JoinedClass(
      schoolId: response.schoolId,
      classroomId: ClassroomId(response.classroomId),
      classroomName: response.classroomName,
    );
  }

  @override
  Future<JoinedClass> joinWithCode(String code) async {
    // Same reasoning as joinWithLink: no membership exists yet, so nothing
    // here may depend on one. The server hashes the code under its own key
    // and resolves it to exactly one live link, or refuses.
    final response = await _client.redeemClassJoinLink(
      V1RedeemClassJoinLinkRequestDto(code: code),
      idempotencyKey: newIdempotencyKey('join-code'),
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
