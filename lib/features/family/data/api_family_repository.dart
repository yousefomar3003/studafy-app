import 'dart:io';

import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/family.dart';

Future<T> _guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on V1ApiException catch (error) {
    if (error.isUnauthenticated) throw Failure.unauthorized;
    if (error.isReauthRequired) {
      throw const Failure('REAUTH_REQUIRED', 'REAUTH_REQUIRED');
    }
    if (error.code == 'FORBIDDEN') throw Failure.forbidden;
    if (error.code == 'NOT_FOUND') throw Failure.notFound;
    throw Failure(error.code, error.code);
  } on SocketException {
    throw Failure.network;
  } on HttpException {
    throw Failure.network;
  }
}

/// Authoritative `/v1` family reads and link requests for a guardian.
class ApiFamilyRepository implements FamilyRepository, StudentFamilyRepository {
  ApiFamilyRepository(this._client);

  final V1ApiClient _client;

  /// Upper bound on pages read to summarise one child. A school year of
  /// grades and attendance fits well inside this.
  static const _maxPages = 10;

  final Map<String, String> _schoolByStudent = {};

  @override
  Future<List<GuardianChild>> children() => _guard(() async {
    final response = await _client.listMyGuardianLinks();
    final children = [
      for (final link in response.items)
        GuardianChild(
          linkId: link.id,
          studentId: link.studentId,
          studentName: link.studentName,
          schoolId: link.schoolId,
          schoolName: link.schoolName,
          status: guardianLinkStatusFromWire(link.status),
          expiresAt: link.expiresAt == null
              ? null
              : DateTime.parse(link.expiresAt!),
          messagingEnabled: link.messagingEnabled ?? true,
        ),
    ];
    for (final child in children) {
      _schoolByStudent[child.studentId] = child.schoolId;
    }
    return children;
  });

  @override
  Future<LocatedStudent?> locate(String studafyId, {String? captchaToken}) =>
      _guard(() async {
        final response = await _client.locateStudent(
          V1LocateStudentRequestDto(
            studafyId: studafyId,
            captchaToken: captchaToken,
          ),
        );
        final id = response.studentId;
        final name = response.displayName;
        if (!response.found || id == null || name == null) return null;
        return LocatedStudent(studentId: id, displayName: name);
      });

  @override
  Future<GuardianChild> requestLink(String studentId, {String? relationship}) =>
      _guard(() async {
        await _client.requestGuardianLink(
          V1RequestGuardianLinkRequestDto(
            studentId: studentId,
            relationship: relationship,
          ),
        );
        // Re-read so the new link arrives with its school and child name.
        final all = await children();
        return all.firstWhere(
          (child) => child.studentId == studentId,
          orElse: () => throw Failure.notFound,
        );
      });

  @override
  Future<ChildProgress> progress(String studentId) => _guard(() async {
    if (!_schoolByStudent.containsKey(studentId)) await children();
    final schoolId = _schoolByStudent[studentId];
    // Only a child with a link row is ever queried; the server re-checks
    // that the link is verified on every read.
    if (schoolId == null) throw Failure.notFound;
    // Grades and attendance at once: neither waits on the other, and each
    // may take several pages. Future.wait rather than a record's wait, as it
    // rethrows the first failure as it was, so _guard still tells a refusal
    // from a dropped connection.
    final both = await Future.wait<Object>([
      _gradesFor(schoolId, studentId),
      _attendanceFor(schoolId, studentId),
    ], eagerError: true);
    final (scored, percentTotal) = both[0] as (int, double);
    final (present, late, absent, excused) = both[1] as (int, int, int, int);

    return ChildProgress(
      gradedCount: scored,
      averagePercent: scored == 0 ? null : percentTotal / scored,
      present: present,
      late: late,
      absent: absent,
      excused: excused,
    );
  });

  /// How many published grades the child has, and their percentages summed.
  Future<(int, double)> _gradesFor(String schoolId, String studentId) async {
    var scored = 0;
    var percentTotal = 0.0;
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final grades = await _client.listGradeResults(
        schoolId: schoolId,
        studentId: studentId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final grade in grades.items) {
        final score = grade.score;
        if (grade.state != 'published' || score == null) continue;
        if (grade.maximumScore <= 0) continue;
        scored++;
        percentTotal += score * 100 / grade.maximumScore;
      }
      cursor = grades.nextCursor;
      if (cursor == null) break;
    }
    return (scored, percentTotal);
  }

  /// The child's attendance marks: present, late, absent, excused.
  Future<(int, int, int, int)> _attendanceFor(
    String schoolId,
    String studentId,
  ) async {
    var present = 0, late = 0, absent = 0, excused = 0;
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final attendance = await _client.listAttendance(
        schoolId: schoolId,
        studentId: studentId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final record in attendance.items) {
        switch (record.state) {
          case 'present':
            present++;
          case 'late':
            late++;
          case 'absent':
            absent++;
          case 'excused':
            excused++;
        }
      }
      cursor = attendance.nextCursor;
      if (cursor == null) break;
    }
    return (present, late, absent, excused);
  }

  @override
  Future<StudentFamily> studentFamily() => _guard(() async {
    final value = await _client.getStudentFamily();
    return StudentFamily(
      identities: [
        for (final item in value.studentIds)
          StudentIdentity(
            id: item['id'] as String,
            studafyId: item['studafyId'] as String,
            name: item['displayName'] as String,
          ),
      ],
      requests: [
        for (final item in value.requests)
          StudentGuardianRequest(
            id: item['id'] as String,
            guardianId: item['guardianId'] as String,
            guardianName: item['guardianName'] as String,
            status: guardianLinkStatusFromWire(item['status'] as String),
          ),
      ],
    );
  });
  @override
  Future<void> decideGuardian(String linkId, String decision) =>
      _guard(() async {
        await _client.decideGuardianLink(
          V1DecideGuardianLinkRequestDto(decision: decision),
          guardianLinkId: linkId,
        );
      });
}
