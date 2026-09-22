import 'dart:math';

import '../../../core/failures.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../domain/school_operations_repository.dart';

class ApiSchoolOperationsRepository implements SchoolOperationsRepository {
  ApiSchoolOperationsRepository(
    this._client, {
    ActiveContextController? context,
  }) : _context = context ?? ActiveContextController.instance;

  final V1ApiClient _client;
  final ActiveContextController _context;
  final Map<String, String> _pendingKeys = {};

  String get _schoolId {
    final membership = _context.membership;
    if (membership == null || !membership.active) throw Failure.unauthorized;
    return membership.schoolId;
  }

  String _key(String operation, String fingerprint) => _pendingKeys.putIfAbsent(
    '$operation|$fingerprint',
    () =>
        '$operation-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
  );

  void _done(String operation, String fingerprint) =>
      _pendingKeys.remove('$operation|$fingerprint');

  @override
  Future<List<SchoolTerm>> listTerms() async {
    final result = <SchoolTerm>[];
    String? cursor;
    do {
      final page = await _client.listTerms(
        schoolId: _schoolId,
        cursor: cursor,
        pageSize: 100,
      );
      result.addAll(page.items.map(_term));
      cursor = page.nextCursor;
    } while (cursor != null);
    return result;
  }

  @override
  Future<SchoolTerm> createTerm({
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    if (!endsOn.isAfter(startsOn)) {
      throw const FormatException('The end date must be after the start date.');
    }
    final fingerprint = '$name|${_date(startsOn)}|${_date(endsOn)}';
    final value = await _client.createTerm(
      V1CreateTermRequestDto(
        name: name.trim(),
        startsOn: _date(startsOn),
        endsOn: _date(endsOn),
      ),
      schoolId: _schoolId,
      idempotencyKey: _key('term', fingerprint),
    );
    _done('term', fingerprint);
    return _term(value);
  }

  @override
  Future<List<RosterStudent>> listStudents(String classroomId) async {
    final result = <RosterStudent>[];
    String? cursor;
    do {
      final page = await _client.listClassroomStudents(
        classroomId: classroomId,
        schoolId: _schoolId,
        cursor: cursor,
        pageSize: 100,
      );
      result.addAll(
        page.items.map(
          (v) => RosterStudent(
            id: v.id,
            displayName: v.displayName,
            studafyId: v.studafyId,
          ),
        ),
      );
      cursor = page.nextCursor;
    } while (cursor != null);
    return result;
  }

  @override
  Future<RosterStudent> createStudent({
    required String displayName,
    String? userId,
  }) async {
    final cleanName = displayName.trim();
    final cleanUserId = userId?.trim();
    final fingerprint = '$cleanName|${cleanUserId ?? ''}';
    final value = await _client.createStudent(
      V1CreateStudentRequestDto(
        displayName: cleanName,
        userId: cleanUserId?.isEmpty == true ? null : cleanUserId,
      ),
      schoolId: _schoolId,
      idempotencyKey: _key('student', fingerprint),
    );
    _done('student', fingerprint);
    return RosterStudent(
      id: value.id,
      displayName: value.displayName,
      studafyId: value.studafyId,
    );
  }

  @override
  Future<void> enrollStudent({
    required String classroomId,
    required String studentId,
  }) => _mutation(
    'enroll',
    '$classroomId|$studentId',
    (key) => _client.enrollStudent(
      V1EnrollStudentRequestDto(studentId: studentId),
      classroomId: classroomId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<void> withdrawStudent({
    required String classroomId,
    required String studentId,
  }) => _mutation(
    'withdraw',
    '$classroomId|$studentId',
    (key) => _client.withdrawStudent(
      V1WithdrawStudentRequestDto(studentId: studentId),
      classroomId: classroomId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<void> transferStudent({
    required String classroomId,
    required String studentId,
    required String targetClassroomId,
  }) => _mutation(
    'transfer',
    '$classroomId|$studentId|$targetClassroomId',
    (key) => _client.transferEnrollment(
      V1TransferEnrollmentRequestDto(
        studentId: studentId,
        targetClassroomId: targetClassroomId,
      ),
      classroomId: classroomId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<List<ClassroomStaffMember>> listStaff(String classroomId) async {
    final result = <ClassroomStaffMember>[];
    String? cursor;
    do {
      final page = await _client.listClassroomStaff(
        classroomId: classroomId,
        schoolId: _schoolId,
        cursor: cursor,
        pageSize: 100,
      );
      result.addAll(
        page.items.map(
          (v) => ClassroomStaffMember(
            assignmentId: v.id,
            userId: v.userId,
            displayName: v.displayName,
            role: v.role,
          ),
        ),
      );
      cursor = page.nextCursor;
    } while (cursor != null);
    return result;
  }

  @override
  Future<void> assignStaff({
    required String classroomId,
    required String userId,
    required String role,
  }) => _mutation(
    'staff-assign',
    '$classroomId|$userId|$role',
    (key) => _client.assignClassroomStaff(
      V1AssignClassroomStaffRequestDto(userId: userId.trim(), role: role),
      classroomId: classroomId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<void> removeStaff({
    required String classroomId,
    required String assignmentId,
  }) => _mutation(
    'staff-remove',
    '$classroomId|$assignmentId',
    (key) => _client.removeClassroomStaff(
      V1RemoveClassroomStaffRequestDto(staffAssignmentId: assignmentId),
      classroomId: classroomId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<String> verifyGuardianLink({
    required String linkId,
    int? expiresInDays,
  }) async {
    final value = await _client.verifyGuardianLink(
      V1VerifyGuardianLinkRequestDto(expiresInDays: expiresInDays),
      guardianLinkId: linkId.trim(),
      idempotencyKey: _key('guardian-verify', linkId),
    );
    _done('guardian-verify', linkId);
    return value.status;
  }

  @override
  Future<String> revokeGuardianLink(String linkId) async {
    final value = await _client.revokeGuardianLink(
      const V1RevokeGuardianLinkRequestDto(),
      guardianLinkId: linkId.trim(),
      idempotencyKey: _key('guardian-revoke', linkId),
    );
    _done('guardian-revoke', linkId);
    return value.status;
  }

  @override
  Future<ManagedMeeting> requestMeeting({
    required String classroomId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    required String audience,
  }) async {
    if (!endsAt.isAfter(startsAt)) {
      throw const FormatException('The meeting end must be after its start.');
    }
    final fingerprint =
        '$classroomId|$title|${startsAt.toUtc()}|${endsAt.toUtc()}|$audience';
    final value = await _client.requestMeeting(
      V1RequestMeetingRequestDto(
        title: title.trim(),
        startsAt: startsAt.toUtc().toIso8601String(),
        endsAt: endsAt.toUtc().toIso8601String(),
        audience: audience,
      ),
      classroomId: classroomId,
      idempotencyKey: _key('meeting', fingerprint),
    );
    _done('meeting', fingerprint);
    return _meeting(value);
  }

  @override
  Future<ManagedMeeting> getMeeting(String meetingId) async => _meeting(
    (await _client.getMeetingStatus(meetingId: meetingId.trim())).meeting,
  );

  @override
  Future<ManagedMeeting> cancelMeeting({
    required String meetingId,
    required int expectedVersion,
  }) async => _meeting(
    await _client.cancelMeeting(
      V1CancelMeetingRequestDto(expectedVersion: expectedVersion),
      meetingId: meetingId,
      idempotencyKey: _key('meeting-cancel', '$meetingId|$expectedVersion'),
    ),
  );

  Future<void> _mutation(
    String operation,
    String fingerprint,
    Future<Object?> Function(String key) run,
  ) async {
    await run(_key(operation, fingerprint));
    _done(operation, fingerprint);
  }

  static SchoolTerm _term(V1TermDto v) => SchoolTerm(
    id: v.id,
    name: v.name,
    startsOn: DateTime.parse(v.startsOn),
    endsOn: DateTime.parse(v.endsOn),
    status: v.status,
  );
  static ManagedMeeting _meeting(V1MeetingDto v) => ManagedMeeting(
    id: v.id,
    classroomId: v.classroomId,
    title: v.title,
    startsAt: DateTime.parse(v.startsAt).toLocal(),
    endsAt: DateTime.parse(v.endsAt).toLocal(),
    audience: v.audience,
    state: v.state,
    version: v.version,
    recipientCount: v.recipientCount,
    meetUrl: v.meetUrl == null ? null : Uri.tryParse(v.meetUrl!),
  );
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
