import '../domain/school_operations_repository.dart';

/// In-memory data used only by the explicitly labelled synthetic build.
class PreviewSchoolOperationsRepository implements SchoolOperationsRepository {
  final List<SchoolTerm> _terms = [
    SchoolTerm(
      id: 'demo-term-2026',
      name: 'Term 1',
      startsOn: DateTime(2026, 9, 1),
      endsOn: DateTime(2026, 12, 20),
      status: 'active',
    ),
  ];
  final Map<String, List<RosterStudent>> _students = {};
  final Map<String, List<ClassroomStaffMember>> _staff = {};
  final Map<String, ManagedMeeting> _meetings = {};
  int _sequence = 0;

  String _id(String kind) => 'demo-$kind-${++_sequence}';

  @override
  Future<List<SchoolTerm>> listTerms() async => List.of(_terms);

  @override
  Future<SchoolTerm> createTerm({
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final value = SchoolTerm(
      id: _id('term'),
      name: name,
      startsOn: startsOn,
      endsOn: endsOn,
      status: 'planned',
    );
    _terms.add(value);
    return value;
  }

  @override
  Future<List<RosterStudent>> listStudents(String classroomId) async =>
      List.of(_students[classroomId] ?? const []);

  @override
  Future<RosterStudent> createStudent({
    required String displayName,
    String? userId,
  }) async => RosterStudent(
    id: _id('student'),
    displayName: displayName,
    studafyId: 'STD-${_sequence.toString().padLeft(5, '0')}',
  );

  @override
  Future<void> enrollStudent({
    required String classroomId,
    required String studentId,
  }) async {
    final list = _students.putIfAbsent(classroomId, () => []);
    if (list.any((item) => item.id == studentId)) return;
    list.add(
      RosterStudent(
        id: studentId,
        displayName: 'Preview student',
        studafyId: 'STD-${studentId.hashCode.abs() % 100000}',
      ),
    );
  }

  @override
  Future<void> withdrawStudent({
    required String classroomId,
    required String studentId,
  }) async =>
      _students[classroomId]?.removeWhere((item) => item.id == studentId);

  @override
  Future<void> transferStudent({
    required String classroomId,
    required String studentId,
    required String targetClassroomId,
  }) async {
    final source = _students[classroomId] ?? [];
    final student = source.where((item) => item.id == studentId).firstOrNull;
    if (student == null) return;
    source.remove(student);
    _students.putIfAbsent(targetClassroomId, () => []).add(student);
  }

  @override
  Future<List<ClassroomStaffMember>> listStaff(String classroomId) async =>
      List.of(_staff[classroomId] ?? const []);

  @override
  Future<void> assignStaff({
    required String classroomId,
    required String userId,
    required String role,
  }) async => _staff
      .putIfAbsent(classroomId, () => [])
      .add(
        ClassroomStaffMember(
          assignmentId: _id('staff'),
          userId: userId,
          displayName: 'Preview teacher',
          role: role,
        ),
      );

  @override
  Future<void> removeStaff({
    required String classroomId,
    required String assignmentId,
  }) async => _staff[classroomId]?.removeWhere(
    (item) => item.assignmentId == assignmentId,
  );

  @override
  Future<String> verifyGuardianLink({
    required String linkId,
    int? expiresInDays,
  }) async => 'verified';

  @override
  Future<String> revokeGuardianLink(String linkId) async => 'revoked';

  @override
  Future<ManagedMeeting> requestMeeting({
    required String classroomId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    required String audience,
  }) async {
    final value = ManagedMeeting(
      id: _id('meeting'),
      classroomId: classroomId,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      audience: audience,
      state: 'requested',
      version: 1,
      recipientCount: 12,
    );
    _meetings[value.id] = value;
    return value;
  }

  @override
  Future<ManagedMeeting> getMeeting(String meetingId) async =>
      _meetings[meetingId] ?? (throw StateError('Meeting not found.'));

  @override
  Future<ManagedMeeting> cancelMeeting({
    required String meetingId,
    required int expectedVersion,
  }) async {
    final current = await getMeeting(meetingId);
    final value = ManagedMeeting(
      id: current.id,
      classroomId: current.classroomId,
      title: current.title,
      startsAt: current.startsAt,
      endsAt: current.endsAt,
      audience: current.audience,
      state: 'cancelled',
      version: current.version + 1,
      recipientCount: current.recipientCount,
      meetUrl: current.meetUrl,
    );
    _meetings[meetingId] = value;
    return value;
  }
}
