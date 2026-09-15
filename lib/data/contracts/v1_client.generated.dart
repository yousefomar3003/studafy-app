// GENERATED CODE — DO NOT EDIT.
// Source: packages/contracts/openapi/v1.json
// Regenerate: bun run generate:dart-client

abstract interface class V1JsonTransport {
  Future<Map<String, dynamic>> get(String path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  });
}

class V1ApiClient {
  const V1ApiClient(this._transport);

  final V1JsonTransport _transport;

  Future<V1MeResponseDto> getMe() async =>
      V1MeResponseDto.fromJson(await _transport.get(_v1Path('/v1/me', {}, {})));

  Future<V1AuthContextResponseDto> getAuthContext() async =>
      V1AuthContextResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/auth/context', {}, {})),
      );

  Future<V1AuthDeviceListResponseDto> listAuthDevices() async =>
      V1AuthDeviceListResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/auth/devices', {}, {})),
      );

  Future<V1AuthDeviceRevokeResponseDto> revokeAuthDevice(
    V1AuthDeviceRevokeRequestDto request, {
    String? idempotencyKey,
  }) async => V1AuthDeviceRevokeResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/devices/revoke', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AuthSignOutResponseDto> signOut(
    V1AuthSignOutRequestDto request, {
    String? idempotencyKey,
  }) async => V1AuthSignOutResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/sign-out', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ReauthChallengeResponseDto> challengeReauth(
    V1ReauthChallengeRequestDto request, {
    String? idempotencyKey,
  }) async => V1ReauthChallengeResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/reauth/challenge', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ReauthVerifyResponseDto> verifyReauth(
    V1ReauthVerifyRequestDto request,
  ) async => V1ReauthVerifyResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/reauth/verify', {}, {}),
      request.toJson(),
    ),
  );

  Future<V1IdentityLinkResponseDto> linkIdentity(
    V1IdentityLinkRequestDto request, {
    String? idempotencyKey,
  }) async => V1IdentityLinkResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/identities/link', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1IdentityUnlinkResponseDto> unlinkIdentity(
    V1IdentityUnlinkRequestDto request, {
    String? idempotencyKey,
  }) async => V1IdentityUnlinkResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/auth/identities/unlink', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1DeletionImpactResponseDto> getDeletionImpact() async =>
      V1DeletionImpactResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/account/deletion-impact', {}, {})),
      );

  Future<V1DeletionRequestResponseDto> requestAccountDeletion(
    V1DeletionRequestRequestDto request, {
    String? idempotencyKey,
  }) async => V1DeletionRequestResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/account/deletion-request', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1DeletionCancelResponseDto> cancelAccountDeletion(
    V1DeletionCancelRequestDto request, {
    String? idempotencyKey,
  }) async => V1DeletionCancelResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/account/deletion-cancel', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SchoolDto> getSchool({required String schoolId}) async =>
      V1SchoolDto.fromJson(
        await _transport.get(
          _v1Path('/v1/schools/{schoolId}', {'schoolId': schoolId}, {}),
        ),
      );

  Future<V1TermPageDto> listTerms({
    required String schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1TermPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/schools/{schoolId}/terms',
        {'schoolId': schoolId},
        {
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1ClassroomPageDto> listClassrooms({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1ClassroomPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/classrooms', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1AcademicClassroomDto> createClassroom(
    V1CreateClassroomRequestDto request, {
    String? idempotencyKey,
  }) async => V1AcademicClassroomDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassroomDetailDto> getClassroom({
    required String classroomId,
  }) async => V1ClassroomDetailDto.fromJson(
    await _transport.get(
      _v1Path('/v1/classrooms/{classroomId}', {'classroomId': classroomId}, {}),
    ),
  );

  Future<V1ClassroomStaffPageDto> listClassroomStaff({
    required String classroomId,
    String? schoolId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1ClassroomStaffPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/classrooms/{classroomId}/staff',
        {'classroomId': classroomId},
        {
          'schoolId': schoolId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1AcademicClassroomDto> updateClassroom(
    V1UpdateClassroomRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1AcademicClassroomDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/update', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassroomDetailDto> replaceClassroomSchedule(
    V1ReplaceScheduleRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1ClassroomDetailDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/schedule/replace', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1StudentPageDto> listClassroomStudents({
    required String classroomId,
    String? schoolId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1StudentPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/classrooms/{classroomId}/students',
        {'classroomId': classroomId},
        {
          'schoolId': schoolId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1ResourcePageDto> listResources({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1ResourcePageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/resources', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ResourceDto> createResource(
    V1CreateResourceRequestDto request, {
    String? idempotencyKey,
  }) async => V1ResourceDto.fromJson(
    await _transport.post(
      _v1Path('/v1/resources', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1LessonSessionPageDto> listLessonSessions({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1LessonSessionPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/lesson-sessions', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ResourceDto> reviseResource(
    V1ReviseResourceRequestDto request, {
    required String resourceId,
    String? idempotencyKey,
  }) async => V1ResourceDto.fromJson(
    await _transport.post(
      _v1Path('/v1/resources/{resourceId}/revise', {
        'resourceId': resourceId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ResourceDto> publishResource(
    V1VersionCommandRequestDto request, {
    required String resourceId,
    String? idempotencyKey,
  }) async => V1ResourceDto.fromJson(
    await _transport.post(
      _v1Path('/v1/resources/{resourceId}/publish', {
        'resourceId': resourceId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ResourceDto> withdrawResource(
    V1VersionCommandRequestDto request, {
    required String resourceId,
    String? idempotencyKey,
  }) async => V1ResourceDto.fromJson(
    await _transport.post(
      _v1Path('/v1/resources/{resourceId}/withdraw', {
        'resourceId': resourceId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssignmentPageDto> listAssignments({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AssignmentPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/assignments', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1AssignmentDto> createAssignment(
    V1CreateAssignmentRequestDto request, {
    String? idempotencyKey,
  }) async => V1AssignmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assignments', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssignmentDto> publishAssignment(
    V1VersionCommandRequestDto request, {
    required String assignmentId,
    String? idempotencyKey,
  }) async => V1AssignmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assignments/{assignmentId}/publish', {
        'assignmentId': assignmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssignmentDto> withdrawAssignment(
    V1VersionCommandRequestDto request, {
    required String assignmentId,
    String? idempotencyKey,
  }) async => V1AssignmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assignments/{assignmentId}/withdraw', {
        'assignmentId': assignmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SubmissionDto> submitAssignment(
    V1SubmitAssignmentRequestDto request, {
    required String assignmentId,
    String? idempotencyKey,
  }) async => V1SubmissionDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assignments/{assignmentId}/submit', {
        'assignmentId': assignmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssignmentDto> getAssignment({required String assignmentId}) async =>
      V1AssignmentDto.fromJson(
        await _transport.get(
          _v1Path('/v1/assignments/{assignmentId}', {
            'assignmentId': assignmentId,
          }, {}),
        ),
      );

  Future<V1SubmissionPageDto> listAssignmentSubmissions({
    required String assignmentId,
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1SubmissionPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/assignments/{assignmentId}/submissions',
        {'assignmentId': assignmentId},
        {
          'schoolId': schoolId,
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1AssessmentPageDto> listAssessments({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AssessmentPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/assessments', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1AssessmentDto> createAssessment(
    V1CreateAssessmentRequestDto request, {
    String? idempotencyKey,
  }) async => V1AssessmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assessments', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssessmentDto> publishAssessment(
    V1VersionCommandRequestDto request, {
    required String assessmentId,
    String? idempotencyKey,
  }) async => V1AssessmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assessments/{assessmentId}/publish', {
        'assessmentId': assessmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssessmentDto> withdrawAssessment(
    V1VersionCommandRequestDto request, {
    required String assessmentId,
    String? idempotencyKey,
  }) async => V1AssessmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assessments/{assessmentId}/withdraw', {
        'assessmentId': assessmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AssessmentQuestionsResponseDto> listAssessmentQuestions({
    required String assessmentId,
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AssessmentQuestionsResponseDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/assessments/{assessmentId}/questions',
        {'assessmentId': assessmentId},
        {
          'schoolId': schoolId,
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1AssessmentAuthoringQuestionsResponseDto>
  listAssessmentAuthoringQuestions({
    required String assessmentId,
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AssessmentAuthoringQuestionsResponseDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/assessments/{assessmentId}/authoring-questions',
        {'assessmentId': assessmentId},
        {
          'schoolId': schoolId,
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1AssessmentAttemptPageDto> listAssessmentAttempts({
    required String assessmentId,
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AssessmentAttemptPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/assessments/{assessmentId}/attempts',
        {'assessmentId': assessmentId},
        {
          'schoolId': schoolId,
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1AssessmentAttemptDto> submitAssessment(
    V1SubmitAssessmentRequestDto request, {
    required String assessmentId,
    String? idempotencyKey,
  }) async => V1AssessmentAttemptDto.fromJson(
    await _transport.post(
      _v1Path('/v1/assessments/{assessmentId}/submit', {
        'assessmentId': assessmentId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GradeResultPageDto> listGradeResults({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1GradeResultPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/grade-results', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1GradeResultDto> reviewGradeResult(
    V1ReviewGradeRequestDto request, {
    required String gradeResultId,
    String? idempotencyKey,
  }) async => V1GradeResultDto.fromJson(
    await _transport.post(
      _v1Path('/v1/grade-results/{gradeResultId}/review', {
        'gradeResultId': gradeResultId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GradeResultDto> publishGradeResult(
    V1VersionCommandRequestDto request, {
    required String gradeResultId,
    String? idempotencyKey,
  }) async => V1GradeResultDto.fromJson(
    await _transport.post(
      _v1Path('/v1/grade-results/{gradeResultId}/publish', {
        'gradeResultId': gradeResultId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GradeResultDto> correctGradeResult(
    V1CorrectGradeRequestDto request, {
    required String gradeResultId,
    String? idempotencyKey,
  }) async => V1GradeResultDto.fromJson(
    await _transport.post(
      _v1Path('/v1/grade-results/{gradeResultId}/correct', {
        'gradeResultId': gradeResultId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GradeResultDto> withdrawGradeResult(
    V1VersionCommandRequestDto request, {
    required String gradeResultId,
    String? idempotencyKey,
  }) async => V1GradeResultDto.fromJson(
    await _transport.post(
      _v1Path('/v1/grade-results/{gradeResultId}/withdraw', {
        'gradeResultId': gradeResultId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AttendancePageDto> listAttendance({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AttendancePageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/attendance', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1AttendanceRosterPageDto> listAttendanceRoster({
    required String classroomId,
    String? schoolId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1AttendanceRosterPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/classrooms/{classroomId}/attendance-roster',
        {'classroomId': classroomId},
        {
          'schoolId': schoolId,
          'studentId': studentId,
          'date': date,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1RecordAttendanceResponseDto> recordAttendance(
    V1RecordAttendanceRequestDto request, {
    String? idempotencyKey,
  }) async => V1RecordAttendanceResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/attendance/record', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1WellbeingPageDto> listWellbeing({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? cursor,
    int? pageSize,
  }) async => V1WellbeingPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/wellbeing', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1WellbeingEventDto> createWellbeing(
    V1CreateWellbeingRequestDto request, {
    String? idempotencyKey,
  }) async => V1WellbeingEventDto.fromJson(
    await _transport.post(
      _v1Path('/v1/wellbeing', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );
}

String _v1Path(
  String template,
  Map<String, Object?> pathValues,
  Map<String, Object?> queryValues,
) {
  var value = template;
  for (final entry in pathValues.entries) {
    value = value.replaceAll(
      '{${entry.key}}',
      Uri.encodeComponent(entry.value.toString()),
    );
  }
  final query = <String, String>{
    for (final entry in queryValues.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };
  return query.isEmpty
      ? value
      : Uri.parse(value).replace(queryParameters: query).toString();
}

class ProblemFieldDto {
  const ProblemFieldDto({required this.path, required this.code});

  factory ProblemFieldDto.fromJson(Map<String, dynamic> json) =>
      ProblemFieldDto(
        path: json['path'] as String,
        code: json['code'] as String,
      );

  final String path;
  final String code;

  Map<String, Object?> toJson() => {'path': path, 'code': code};
}

class ProblemDetailsDto {
  const ProblemDetailsDto({
    required this.type,
    required this.title,
    required this.status,
    required this.code,
    required this.detail,
    required this.requestId,
    this.errors,
  });

  factory ProblemDetailsDto.fromJson(Map<String, dynamic> json) =>
      ProblemDetailsDto(
        type: json['type'] as String,
        title: json['title'] as String,
        status: json['status'] as int,
        code: json['code'] as String,
        detail: json['detail'] as String,
        requestId: json['requestId'] as String,
        errors: json['errors'] == null
            ? null
            : [
                for (final item in json['errors'] as List<dynamic>)
                  ProblemFieldDto.fromJson(item as Map<String, dynamic>),
              ],
      );

  final String type;
  final String title;
  final int status;
  final String code;
  final String detail;
  final String requestId;
  final List<ProblemFieldDto>? errors;

  Map<String, Object?> toJson() => {
    'type': type,
    'title': title,
    'status': status,
    'code': code,
    'detail': detail,
    'requestId': requestId,
    if (errors != null) 'errors': [for (final item in errors!) item.toJson()],
  };
}

class V1MembershipDto {
  const V1MembershipDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    required this.active,
  });

  factory V1MembershipDto.fromJson(Map<String, dynamic> json) =>
      V1MembershipDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        schoolName: json['schoolName'] as String,
        role: json['role'] as String,
        active: json['active'] as bool,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String role;
  final bool active;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'role': role,
    'active': active,
  };
}

class V1MeResponseDto {
  const V1MeResponseDto({
    required this.id,
    required this.displayName,
    required this.memberships,
    required this.activeTermId,
  });

  factory V1MeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1MeResponseDto(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1MembershipDto.fromJson(item as Map<String, dynamic>),
        ],
        activeTermId: json['activeTermId'] as String?,
      );

  final String id;
  final String displayName;
  final List<V1MembershipDto> memberships;
  final String? activeTermId;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'memberships': [for (final item in memberships) item.toJson()],
    'activeTermId': activeTermId,
  };
}

class V1ClassroomDto {
  const V1ClassroomDto({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.studentCount,
    required this.weeklySessions,
    required this.termName,
  });

  factory V1ClassroomDto.fromJson(Map<String, dynamic> json) => V1ClassroomDto(
    id: json['id'] as String,
    name: json['name'] as String,
    grade: json['grade'] as String,
    section: json['section'] as String,
    room: json['room'] as String?,
    studentCount: json['studentCount'] as int,
    weeklySessions: json['weeklySessions'] as int?,
    termName: json['termName'] as String?,
  );

  final String id;
  final String name;
  final String grade;
  final String section;
  final String? room;
  final int studentCount;
  final int? weeklySessions;
  final String? termName;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
    'studentCount': studentCount,
    'weeklySessions': weeklySessions,
    'termName': termName,
  };
}

class V1ClassroomListResponseDto {
  const V1ClassroomListResponseDto({required this.classrooms});

  factory V1ClassroomListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomListResponseDto(
        classrooms: [
          for (final item in json['classrooms'] as List<dynamic>)
            V1ClassroomDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1ClassroomDto> classrooms;

  Map<String, Object?> toJson() => {
    'classrooms': [for (final item in classrooms) item.toJson()],
  };
}

class V1ContextMembershipDto {
  const V1ContextMembershipDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.schoolTimezone,
    required this.role,
    required this.activeTermId,
  });

  factory V1ContextMembershipDto.fromJson(Map<String, dynamic> json) =>
      V1ContextMembershipDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        schoolName: json['schoolName'] as String,
        schoolTimezone: json['schoolTimezone'] as String,
        role: json['role'] as String,
        activeTermId: json['activeTermId'] as String?,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String schoolTimezone;
  final String role;
  final String? activeTermId;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'schoolTimezone': schoolTimezone,
    'role': role,
    'activeTermId': activeTermId,
  };
}

class V1AuthContextResponseDto {
  const V1AuthContextResponseDto({
    required this.userId,
    required this.displayName,
    required this.locale,
    required this.memberships,
    required this.membershipVersion,
    required this.assuranceLevel,
    required this.mfaEnrolled,
    required this.mfaRequired,
    required this.pendingDeletion,
  });

  factory V1AuthContextResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthContextResponseDto(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        locale: json['locale'] as String,
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1ContextMembershipDto.fromJson(item as Map<String, dynamic>),
        ],
        membershipVersion: json['membershipVersion'] as String,
        assuranceLevel: json['assuranceLevel'] as String,
        mfaEnrolled: json['mfaEnrolled'] as bool,
        mfaRequired: json['mfaRequired'] as bool,
        pendingDeletion: json['pendingDeletion'] as bool,
      );

  final String userId;
  final String displayName;
  final String locale;
  final List<V1ContextMembershipDto> memberships;
  final String membershipVersion;
  final String assuranceLevel;
  final bool mfaEnrolled;
  final bool mfaRequired;
  final bool pendingDeletion;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'locale': locale,
    'memberships': [for (final item in memberships) item.toJson()],
    'membershipVersion': membershipVersion,
    'assuranceLevel': assuranceLevel,
    'mfaEnrolled': mfaEnrolled,
    'mfaRequired': mfaRequired,
    'pendingDeletion': pendingDeletion,
  };
}

class V1AuthDeviceDto {
  const V1AuthDeviceDto({
    required this.id,
    required this.platform,
    required this.appVersion,
    required this.displayLabel,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.revokedAt,
    required this.current,
  });

  factory V1AuthDeviceDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceDto(
        id: json['id'] as String,
        platform: json['platform'] as String,
        appVersion: json['appVersion'] as String?,
        displayLabel: json['displayLabel'] as String?,
        firstSeenAt: json['firstSeenAt'] as String,
        lastSeenAt: json['lastSeenAt'] as String,
        revokedAt: json['revokedAt'] as String?,
        current: json['current'] as bool,
      );

  final String id;
  final String platform;
  final String? appVersion;
  final String? displayLabel;
  final String firstSeenAt;
  final String lastSeenAt;
  final String? revokedAt;
  final bool current;

  Map<String, Object?> toJson() => {
    'id': id,
    'platform': platform,
    'appVersion': appVersion,
    'displayLabel': displayLabel,
    'firstSeenAt': firstSeenAt,
    'lastSeenAt': lastSeenAt,
    'revokedAt': revokedAt,
    'current': current,
  };
}

class V1AuthDeviceListResponseDto {
  const V1AuthDeviceListResponseDto({required this.devices});

  factory V1AuthDeviceListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceListResponseDto(
        devices: [
          for (final item in json['devices'] as List<dynamic>)
            V1AuthDeviceDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1AuthDeviceDto> devices;

  Map<String, Object?> toJson() => {
    'devices': [for (final item in devices) item.toJson()],
  };
}

class V1AuthDeviceRevokeRequestDto {
  const V1AuthDeviceRevokeRequestDto({required this.deviceId});

  factory V1AuthDeviceRevokeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceRevokeRequestDto(deviceId: json['deviceId'] as String);

  final String deviceId;

  Map<String, Object?> toJson() => {'deviceId': deviceId};
}

class V1AuthDeviceRevokeResponseDto {
  const V1AuthDeviceRevokeResponseDto({required this.revoked});

  factory V1AuthDeviceRevokeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthDeviceRevokeResponseDto(revoked: json['revoked'] as bool);

  final bool revoked;

  Map<String, Object?> toJson() => {'revoked': revoked};
}

class V1AuthSignOutRequestDto {
  const V1AuthSignOutRequestDto({required this.scope});

  factory V1AuthSignOutRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AuthSignOutRequestDto(scope: json['scope'] as String);

  final String scope;

  Map<String, Object?> toJson() => {'scope': scope};
}

class V1AuthSignOutResponseDto {
  const V1AuthSignOutResponseDto({
    required this.scope,
    required this.revokedBefore,
  });

  factory V1AuthSignOutResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AuthSignOutResponseDto(
        scope: json['scope'] as String,
        revokedBefore: json['revokedBefore'] as String?,
      );

  final String scope;
  final String? revokedBefore;

  Map<String, Object?> toJson() => {
    'scope': scope,
    'revokedBefore': revokedBefore,
  };
}

class V1ReauthChallengeRequestDto {
  const V1ReauthChallengeRequestDto({required this.purpose});

  factory V1ReauthChallengeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthChallengeRequestDto(purpose: json['purpose'] as String);

  final String purpose;

  Map<String, Object?> toJson() => {'purpose': purpose};
}

class V1ReauthChallengeResponseDto {
  const V1ReauthChallengeResponseDto({
    required this.purpose,
    required this.requiredAssurance,
    required this.expiresAt,
  });

  factory V1ReauthChallengeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthChallengeResponseDto(
        purpose: json['purpose'] as String,
        requiredAssurance: json['requiredAssurance'] as String,
        expiresAt: json['expiresAt'] as String,
      );

  final String purpose;
  final String requiredAssurance;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'requiredAssurance': requiredAssurance,
    'expiresAt': expiresAt,
  };
}

class V1ReauthVerifyRequestDto {
  const V1ReauthVerifyRequestDto({required this.purpose});

  factory V1ReauthVerifyRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthVerifyRequestDto(purpose: json['purpose'] as String);

  final String purpose;

  Map<String, Object?> toJson() => {'purpose': purpose};
}

class V1ReauthVerifyResponseDto {
  const V1ReauthVerifyResponseDto({
    required this.purpose,
    required this.grant,
    required this.expiresAt,
  });

  factory V1ReauthVerifyResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ReauthVerifyResponseDto(
        purpose: json['purpose'] as String,
        grant: json['grant'] as String,
        expiresAt: json['expiresAt'] as String,
      );

  final String purpose;
  final String grant;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'purpose': purpose,
    'grant': grant,
    'expiresAt': expiresAt,
  };
}

class V1IdentityLinkRequestDto {
  const V1IdentityLinkRequestDto({
    required this.provider,
    required this.idToken,
    required this.makePrimary,
  });

  factory V1IdentityLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityLinkRequestDto(
        provider: json['provider'] as String,
        idToken: json['idToken'] as String,
        makePrimary: json['makePrimary'] as bool,
      );

  final String provider;
  final String idToken;
  final bool makePrimary;

  Map<String, Object?> toJson() => {
    'provider': provider,
    'idToken': idToken,
    'makePrimary': makePrimary,
  };
}

class V1IdentityLinkResponseDto {
  const V1IdentityLinkResponseDto({required this.outcome});

  factory V1IdentityLinkResponseDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityLinkResponseDto(outcome: json['outcome'] as String);

  final String outcome;

  Map<String, Object?> toJson() => {'outcome': outcome};
}

class V1IdentityUnlinkRequestDto {
  const V1IdentityUnlinkRequestDto({
    required this.provider,
    required this.subject,
  });

  factory V1IdentityUnlinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityUnlinkRequestDto(
        provider: json['provider'] as String,
        subject: json['subject'] as String,
      );

  final String provider;
  final String subject;

  Map<String, Object?> toJson() => {'provider': provider, 'subject': subject};
}

class V1IdentityUnlinkResponseDto {
  const V1IdentityUnlinkResponseDto({required this.outcome});

  factory V1IdentityUnlinkResponseDto.fromJson(Map<String, dynamic> json) =>
      V1IdentityUnlinkResponseDto(outcome: json['outcome'] as String);

  final String outcome;

  Map<String, Object?> toJson() => {'outcome': outcome};
}

class V1DeletionImpactMembershipDto {
  const V1DeletionImpactMembershipDto({
    required this.schoolName,
    required this.role,
  });

  factory V1DeletionImpactMembershipDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionImpactMembershipDto(
        schoolName: json['schoolName'] as String,
        role: json['role'] as String,
      );

  final String schoolName;
  final String role;

  Map<String, Object?> toJson() => {'schoolName': schoolName, 'role': role};
}

class V1DeletionRetainedRecordsDto {
  const V1DeletionRetainedRecordsDto({
    required this.attendance,
    required this.grades,
    required this.submissions,
    required this.wellbeing,
  });

  factory V1DeletionRetainedRecordsDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRetainedRecordsDto(
        attendance: json['attendance'] as int,
        grades: json['grades'] as int,
        submissions: json['submissions'] as int,
        wellbeing: json['wellbeing'] as int,
      );

  final int attendance;
  final int grades;
  final int submissions;
  final int wellbeing;

  Map<String, Object?> toJson() => {
    'attendance': attendance,
    'grades': grades,
    'submissions': submissions,
    'wellbeing': wellbeing,
  };
}

class V1DeletionDeletedDataDto {
  const V1DeletionDeletedDataDto({
    required this.profile,
    required this.devices,
    required this.consents,
    required this.notifications,
  });

  factory V1DeletionDeletedDataDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionDeletedDataDto(
        profile: json['profile'] as int,
        devices: json['devices'] as int,
        consents: json['consents'] as int,
        notifications: json['notifications'] as int,
      );

  final int profile;
  final int devices;
  final int consents;
  final int notifications;

  Map<String, Object?> toJson() => {
    'profile': profile,
    'devices': devices,
    'consents': consents,
    'notifications': notifications,
  };
}

class V1DeletionImpactResponseDto {
  const V1DeletionImpactResponseDto({
    required this.memberships,
    required this.retainedSchoolRecords,
    required this.deletedPersonalData,
    required this.guardianLinks,
    required this.activeEntitlements,
    required this.gracePeriodDays,
  });

  factory V1DeletionImpactResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionImpactResponseDto(
        memberships: [
          for (final item in json['memberships'] as List<dynamic>)
            V1DeletionImpactMembershipDto.fromJson(
              item as Map<String, dynamic>,
            ),
        ],
        retainedSchoolRecords: V1DeletionRetainedRecordsDto.fromJson(
          json['retainedSchoolRecords'] as Map<String, dynamic>,
        ),
        deletedPersonalData: V1DeletionDeletedDataDto.fromJson(
          json['deletedPersonalData'] as Map<String, dynamic>,
        ),
        guardianLinks: json['guardianLinks'] as int,
        activeEntitlements: json['activeEntitlements'] as int,
        gracePeriodDays: json['gracePeriodDays'] as int,
      );

  final List<V1DeletionImpactMembershipDto> memberships;
  final V1DeletionRetainedRecordsDto retainedSchoolRecords;
  final V1DeletionDeletedDataDto deletedPersonalData;
  final int guardianLinks;
  final int activeEntitlements;
  final int gracePeriodDays;

  Map<String, Object?> toJson() => {
    'memberships': [for (final item in memberships) item.toJson()],
    'retainedSchoolRecords': retainedSchoolRecords.toJson(),
    'deletedPersonalData': deletedPersonalData.toJson(),
    'guardianLinks': guardianLinks,
    'activeEntitlements': activeEntitlements,
    'gracePeriodDays': gracePeriodDays,
  };
}

class V1DeletionRequestRequestDto {
  const V1DeletionRequestRequestDto({
    required this.reasonCode,
    required this.confirmation,
  });

  factory V1DeletionRequestRequestDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRequestRequestDto(
        reasonCode: json['reasonCode'] as String,
        confirmation: json['confirmation'] as String,
      );

  final String reasonCode;
  final String confirmation;

  Map<String, Object?> toJson() => {
    'reasonCode': reasonCode,
    'confirmation': confirmation,
  };
}

class V1DeletionRequestResponseDto {
  const V1DeletionRequestResponseDto({
    required this.id,
    required this.state,
    required this.executeAfter,
    required this.created,
  });

  factory V1DeletionRequestResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionRequestResponseDto(
        id: json['id'] as String,
        state: json['state'] as String,
        executeAfter: json['executeAfter'] as String,
        created: json['created'] as bool,
      );

  final String id;
  final String state;
  final String executeAfter;
  final bool created;

  Map<String, Object?> toJson() => {
    'id': id,
    'state': state,
    'executeAfter': executeAfter,
    'created': created,
  };
}

class V1DeletionCancelRequestDto {
  const V1DeletionCancelRequestDto();

  factory V1DeletionCancelRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1DeletionCancelRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1DeletionCancelResponseDto {
  const V1DeletionCancelResponseDto({required this.cancelled});

  factory V1DeletionCancelResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DeletionCancelResponseDto(cancelled: json['cancelled'] as bool);

  final bool cancelled;

  Map<String, Object?> toJson() => {'cancelled': cancelled};
}

class V1AcademicClassroomDto {
  const V1AcademicClassroomDto({
    required this.id,
    required this.schoolId,
    required this.termId,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.status,
    required this.version,
    required this.studentCount,
    required this.weeklySessions,
    required this.termName,
  });

  factory V1AcademicClassroomDto.fromJson(Map<String, dynamic> json) =>
      V1AcademicClassroomDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        termId: json['termId'] as String,
        name: json['name'] as String,
        grade: json['grade'] as String,
        section: json['section'] as String,
        room: json['room'] as String?,
        status: json['status'] as String,
        version: json['version'] as int,
        studentCount: json['studentCount'] as int,
        weeklySessions: json['weeklySessions'] as int,
        termName: json['termName'] as String?,
      );

  final String id;
  final String schoolId;
  final String termId;
  final String name;
  final String grade;
  final String section;
  final String? room;
  final String status;
  final int version;
  final int studentCount;
  final int weeklySessions;
  final String? termName;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'termId': termId,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
    'status': status,
    'version': version,
    'studentCount': studentCount,
    'weeklySessions': weeklySessions,
    'termName': termName,
  };
}

class V1AssessmentDto {
  const V1AssessmentDto({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.category,
    required this.maximumScore,
    required this.scheduledAt,
    required this.delivery,
    required this.state,
    required this.version,
  });

  factory V1AssessmentDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentDto(
        id: json['id'] as String,
        classroomId: json['classroomId'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        maximumScore: json['maximumScore'] as num,
        scheduledAt: json['scheduledAt'] as String?,
        delivery: json['delivery'] as String,
        state: json['state'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String classroomId;
  final String title;
  final String category;
  final num maximumScore;
  final String? scheduledAt;
  final String delivery;
  final String state;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'title': title,
    'category': category,
    'maximumScore': maximumScore,
    'scheduledAt': scheduledAt,
    'delivery': delivery,
    'state': state,
    'version': version,
  };
}

class V1AssessmentAnswerDto {
  const V1AssessmentAnswerDto({
    required this.questionId,
    required this.answerText,
  });

  factory V1AssessmentAnswerDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentAnswerDto(
        questionId: json['questionId'] as String,
        answerText: json['answerText'] as String,
      );

  final String questionId;
  final String answerText;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'answerText': answerText,
  };
}

class V1AssessmentAttemptDto {
  const V1AssessmentAttemptDto({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.submittedAt,
    required this.version,
  });

  factory V1AssessmentAttemptDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentAttemptDto(
        id: json['id'] as String,
        assessmentId: json['assessmentId'] as String,
        studentId: json['studentId'] as String,
        submittedAt: json['submittedAt'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String assessmentId;
  final String studentId;
  final String submittedAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'assessmentId': assessmentId,
    'studentId': studentId,
    'submittedAt': submittedAt,
    'version': version,
  };
}

class V1AssessmentAttemptPageDto {
  const V1AssessmentAttemptPageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1AssessmentAttemptPageDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentAttemptPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AssessmentAttemptDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AssessmentAttemptDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AssessmentAuthoringQuestionDto {
  const V1AssessmentAuthoringQuestionDto({
    required this.id,
    required this.position,
    required this.prompt,
    required this.maximumScore,
    required this.preferredAnswer,
  });

  factory V1AssessmentAuthoringQuestionDto.fromJson(
    Map<String, dynamic> json,
  ) => V1AssessmentAuthoringQuestionDto(
    id: json['id'] as String,
    position: json['position'] as int,
    prompt: json['prompt'] as String,
    maximumScore: json['maximumScore'] as num,
    preferredAnswer: json['preferredAnswer'] as String?,
  );

  final String id;
  final int position;
  final String prompt;
  final num maximumScore;
  final String? preferredAnswer;

  Map<String, Object?> toJson() => {
    'id': id,
    'position': position,
    'prompt': prompt,
    'maximumScore': maximumScore,
    'preferredAnswer': preferredAnswer,
  };
}

class V1AssessmentAuthoringQuestionsResponseDto {
  const V1AssessmentAuthoringQuestionsResponseDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1AssessmentAuthoringQuestionsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1AssessmentAuthoringQuestionsResponseDto(
    items: [
      for (final item in json['items'] as List<dynamic>)
        V1AssessmentAuthoringQuestionDto.fromJson(item as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );

  final List<V1AssessmentAuthoringQuestionDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AssessmentPageDto {
  const V1AssessmentPageDto({required this.items, required this.nextCursor});

  factory V1AssessmentPageDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AssessmentDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AssessmentDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AssessmentQuestionDto {
  const V1AssessmentQuestionDto({
    required this.id,
    required this.position,
    required this.prompt,
    required this.maximumScore,
  });

  factory V1AssessmentQuestionDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentQuestionDto(
        id: json['id'] as String,
        position: json['position'] as int,
        prompt: json['prompt'] as String,
        maximumScore: json['maximumScore'] as num,
      );

  final String id;
  final int position;
  final String prompt;
  final num maximumScore;

  Map<String, Object?> toJson() => {
    'id': id,
    'position': position,
    'prompt': prompt,
    'maximumScore': maximumScore,
  };
}

class V1AssessmentQuestionDraftDto {
  const V1AssessmentQuestionDraftDto({
    required this.position,
    required this.prompt,
    required this.preferredAnswer,
    required this.maximumScore,
  });

  factory V1AssessmentQuestionDraftDto.fromJson(Map<String, dynamic> json) =>
      V1AssessmentQuestionDraftDto(
        position: json['position'] as int,
        prompt: json['prompt'] as String,
        preferredAnswer: json['preferredAnswer'] as String?,
        maximumScore: json['maximumScore'] as num,
      );

  final int position;
  final String prompt;
  final String? preferredAnswer;
  final num maximumScore;

  Map<String, Object?> toJson() => {
    'position': position,
    'prompt': prompt,
    'preferredAnswer': preferredAnswer,
    'maximumScore': maximumScore,
  };
}

class V1AssessmentQuestionsResponseDto {
  const V1AssessmentQuestionsResponseDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1AssessmentQuestionsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1AssessmentQuestionsResponseDto(
    items: [
      for (final item in json['items'] as List<dynamic>)
        V1AssessmentQuestionDto.fromJson(item as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );

  final List<V1AssessmentQuestionDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AssignmentDto {
  const V1AssignmentDto({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.instructions,
    required this.dueAt,
    required this.closesAt,
    required this.state,
    required this.version,
    required this.submissionId,
    required this.submittedAt,
  });

  factory V1AssignmentDto.fromJson(Map<String, dynamic> json) =>
      V1AssignmentDto(
        id: json['id'] as String,
        classroomId: json['classroomId'] as String,
        title: json['title'] as String,
        instructions: json['instructions'] as String?,
        dueAt: json['dueAt'] as String,
        closesAt: json['closesAt'] as String?,
        state: json['state'] as String,
        version: json['version'] as int,
        submissionId: json['submissionId'] as String?,
        submittedAt: json['submittedAt'] as String?,
      );

  final String id;
  final String classroomId;
  final String title;
  final String? instructions;
  final String dueAt;
  final String? closesAt;
  final String state;
  final int version;
  final String? submissionId;
  final String? submittedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'title': title,
    'instructions': instructions,
    'dueAt': dueAt,
    'closesAt': closesAt,
    'state': state,
    'version': version,
    'submissionId': submissionId,
    'submittedAt': submittedAt,
  };
}

class V1AssignmentPageDto {
  const V1AssignmentPageDto({required this.items, required this.nextCursor});

  factory V1AssignmentPageDto.fromJson(Map<String, dynamic> json) =>
      V1AssignmentPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AssignmentDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AssignmentDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AttendanceEntryDto {
  const V1AttendanceEntryDto({
    required this.studentId,
    required this.state,
    required this.reason,
  });

  factory V1AttendanceEntryDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceEntryDto(
        studentId: json['studentId'] as String,
        state: json['state'] as String,
        reason: json['reason'] as String?,
      );

  final String studentId;
  final String state;
  final String? reason;

  Map<String, Object?> toJson() => {
    'studentId': studentId,
    'state': state,
    'reason': reason,
  };
}

class V1AttendancePageDto {
  const V1AttendancePageDto({required this.items, required this.nextCursor});

  factory V1AttendancePageDto.fromJson(Map<String, dynamic> json) =>
      V1AttendancePageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AttendanceRecordDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AttendanceRecordDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AttendanceRecordDto {
  const V1AttendanceRecordDto({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.state,
    required this.reason,
    required this.recordedAt,
  });

  factory V1AttendanceRecordDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceRecordDto(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        studentId: json['studentId'] as String,
        state: json['state'] as String,
        reason: json['reason'] as String?,
        recordedAt: json['recordedAt'] as String,
      );

  final String id;
  final String sessionId;
  final String studentId;
  final String state;
  final String? reason;
  final String recordedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'studentId': studentId,
    'state': state,
    'reason': reason,
    'recordedAt': recordedAt,
  };
}

class V1AttendanceRosterItemDto {
  const V1AttendanceRosterItemDto({
    required this.student,
    required this.record,
  });

  factory V1AttendanceRosterItemDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceRosterItemDto(
        student: V1StudentSummaryDto.fromJson(
          json['student'] as Map<String, dynamic>,
        ),
        record: json['record'] == null
            ? null
            : V1AttendanceRecordDto.fromJson(
                json['record'] as Map<String, dynamic>,
              ),
      );

  final V1StudentSummaryDto student;
  final V1AttendanceRecordDto? record;

  Map<String, Object?> toJson() => {
    'student': student.toJson(),
    'record': record?.toJson(),
  };
}

class V1AttendanceRosterPageDto {
  const V1AttendanceRosterPageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1AttendanceRosterPageDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceRosterPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AttendanceRosterItemDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AttendanceRosterItemDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ClassroomDetailDto {
  const V1ClassroomDetailDto({required this.classroom, required this.schedule});

  factory V1ClassroomDetailDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomDetailDto(
        classroom: V1AcademicClassroomDto.fromJson(
          json['classroom'] as Map<String, dynamic>,
        ),
        schedule: [
          for (final item in json['schedule'] as List<dynamic>)
            V1ScheduleSlotDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final V1AcademicClassroomDto classroom;
  final List<V1ScheduleSlotDto> schedule;

  Map<String, Object?> toJson() => {
    'classroom': classroom.toJson(),
    'schedule': [for (final item in schedule) item.toJson()],
  };
}

class V1ClassroomPageDto {
  const V1ClassroomPageDto({required this.items, required this.nextCursor});

  factory V1ClassroomPageDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AcademicClassroomDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AcademicClassroomDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ClassroomStaffDto {
  const V1ClassroomStaffDto({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory V1ClassroomStaffDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomStaffDto(
        id: json['id'] as String,
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
      );

  final String id;
  final String userId;
  final String displayName;
  final String role;

  Map<String, Object?> toJson() => {
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'role': role,
  };
}

class V1ClassroomStaffPageDto {
  const V1ClassroomStaffPageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1ClassroomStaffPageDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomStaffPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ClassroomStaffDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ClassroomStaffDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1CorrectGradeRequestDto {
  const V1CorrectGradeRequestDto({
    required this.expectedVersion,
    required this.score,
    required this.feedback,
    this.draftId,
    this.questionScores,
    required this.reason,
  });

  factory V1CorrectGradeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CorrectGradeRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        score: json['score'] as num,
        feedback: json['feedback'] as String?,
        draftId: json['draftId'] as String?,
        questionScores: json['questionScores'] == null
            ? null
            : [
                for (final item in json['questionScores'] as List<dynamic>)
                  V1QuestionScoreReviewDto.fromJson(
                    item as Map<String, dynamic>,
                  ),
              ],
        reason: json['reason'] as String,
      );

  final int expectedVersion;
  final num score;
  final String? feedback;
  final String? draftId;
  final List<V1QuestionScoreReviewDto>? questionScores;
  final String reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'score': score,
    'feedback': feedback,
    'draftId': ?draftId,
    if (questionScores != null)
      'questionScores': [for (final item in questionScores!) item.toJson()],
    'reason': reason,
  };
}

class V1CreateAssessmentRequestDto {
  const V1CreateAssessmentRequestDto({
    required this.classroomId,
    required this.title,
    required this.category,
    required this.maximumScore,
    required this.scheduledAt,
    required this.delivery,
    required this.questions,
  });

  factory V1CreateAssessmentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateAssessmentRequestDto(
        classroomId: json['classroomId'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        maximumScore: json['maximumScore'] as num,
        scheduledAt: json['scheduledAt'] as String?,
        delivery: json['delivery'] as String,
        questions: [
          for (final item in json['questions'] as List<dynamic>)
            V1AssessmentQuestionDraftDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String classroomId;
  final String title;
  final String category;
  final num maximumScore;
  final String? scheduledAt;
  final String delivery;
  final List<V1AssessmentQuestionDraftDto> questions;

  Map<String, Object?> toJson() => {
    'classroomId': classroomId,
    'title': title,
    'category': category,
    'maximumScore': maximumScore,
    'scheduledAt': scheduledAt,
    'delivery': delivery,
    'questions': [for (final item in questions) item.toJson()],
  };
}

class V1CreateAssignmentRequestDto {
  const V1CreateAssignmentRequestDto({
    required this.classroomId,
    required this.title,
    required this.instructions,
    required this.dueAt,
    required this.closesAt,
  });

  factory V1CreateAssignmentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateAssignmentRequestDto(
        classroomId: json['classroomId'] as String,
        title: json['title'] as String,
        instructions: json['instructions'] as String?,
        dueAt: json['dueAt'] as String,
        closesAt: json['closesAt'] as String?,
      );

  final String classroomId;
  final String title;
  final String? instructions;
  final String dueAt;
  final String? closesAt;

  Map<String, Object?> toJson() => {
    'classroomId': classroomId,
    'title': title,
    'instructions': instructions,
    'dueAt': dueAt,
    'closesAt': closesAt,
  };
}

class V1CreateClassroomRequestDto {
  const V1CreateClassroomRequestDto({
    required this.schoolId,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.schedule,
  });

  factory V1CreateClassroomRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateClassroomRequestDto(
        schoolId: json['schoolId'] as String,
        name: json['name'] as String,
        grade: json['grade'] as String,
        section: json['section'] as String,
        room: json['room'] as String?,
        schedule: [
          for (final item in json['schedule'] as List<dynamic>)
            V1ScheduleSlotInputDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String schoolId;
  final String name;
  final String grade;
  final String section;
  final String? room;
  final List<V1ScheduleSlotInputDto> schedule;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
    'schedule': [for (final item in schedule) item.toJson()],
  };
}

class V1CreateResourceRequestDto {
  const V1CreateResourceRequestDto({
    required this.schoolId,
    required this.classroomId,
    required this.title,
    required this.resourceType,
    required this.body,
    required this.audience,
  });

  factory V1CreateResourceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateResourceRequestDto(
        schoolId: json['schoolId'] as String,
        classroomId: json['classroomId'] as String?,
        title: json['title'] as String,
        resourceType: json['resourceType'] as String,
        body: json['body'] as String?,
        audience: json['audience'] as String,
      );

  final String schoolId;
  final String? classroomId;
  final String title;
  final String resourceType;
  final String? body;
  final String audience;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'classroomId': classroomId,
    'title': title,
    'resourceType': resourceType,
    'body': body,
    'audience': audience,
  };
}

class V1CreateWellbeingRequestDto {
  const V1CreateWellbeingRequestDto({
    required this.studentId,
    required this.classroomId,
    required this.kind,
    required this.title,
    required this.context,
    required this.followUp,
    required this.visibility,
    required this.severity,
  });

  factory V1CreateWellbeingRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateWellbeingRequestDto(
        studentId: json['studentId'] as String,
        classroomId: json['classroomId'] as String,
        kind: json['kind'] as String,
        title: json['title'] as String,
        context: json['context'] as String?,
        followUp: json['followUp'] as String?,
        visibility: json['visibility'] as String,
        severity: json['severity'] as String?,
      );

  final String studentId;
  final String classroomId;
  final String kind;
  final String title;
  final String? context;
  final String? followUp;
  final String visibility;
  final String? severity;

  Map<String, Object?> toJson() => {
    'studentId': studentId,
    'classroomId': classroomId,
    'kind': kind,
    'title': title,
    'context': context,
    'followUp': followUp,
    'visibility': visibility,
    'severity': severity,
  };
}

class V1GradeResultDto {
  const V1GradeResultDto({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.score,
    required this.maximumScore,
    required this.feedback,
    required this.state,
    required this.version,
    required this.reviewedAt,
    required this.publishedAt,
  });

  factory V1GradeResultDto.fromJson(Map<String, dynamic> json) =>
      V1GradeResultDto(
        id: json['id'] as String,
        assessmentId: json['assessmentId'] as String,
        studentId: json['studentId'] as String,
        score: json['score'] as num?,
        maximumScore: json['maximumScore'] as num,
        feedback: json['feedback'] as String?,
        state: json['state'] as String,
        version: json['version'] as int,
        reviewedAt: json['reviewedAt'] as String?,
        publishedAt: json['publishedAt'] as String?,
      );

  final String id;
  final String assessmentId;
  final String studentId;
  final num? score;
  final num maximumScore;
  final String? feedback;
  final String state;
  final int version;
  final String? reviewedAt;
  final String? publishedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'assessmentId': assessmentId,
    'studentId': studentId,
    'score': score,
    'maximumScore': maximumScore,
    'feedback': feedback,
    'state': state,
    'version': version,
    'reviewedAt': reviewedAt,
    'publishedAt': publishedAt,
  };
}

class V1GradeResultPageDto {
  const V1GradeResultPageDto({required this.items, required this.nextCursor});

  factory V1GradeResultPageDto.fromJson(Map<String, dynamic> json) =>
      V1GradeResultPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1GradeResultDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1GradeResultDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1LessonSessionDto {
  const V1LessonSessionDto({
    required this.id,
    required this.classroomId,
    required this.startsAt,
    required this.endsAt,
    required this.title,
    required this.status,
    required this.version,
  });

  factory V1LessonSessionDto.fromJson(Map<String, dynamic> json) =>
      V1LessonSessionDto(
        id: json['id'] as String,
        classroomId: json['classroomId'] as String,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String,
        title: json['title'] as String?,
        status: json['status'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String classroomId;
  final String startsAt;
  final String endsAt;
  final String? title;
  final String status;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'title': title,
    'status': status,
    'version': version,
  };
}

class V1LessonSessionPageDto {
  const V1LessonSessionPageDto({required this.items, required this.nextCursor});

  factory V1LessonSessionPageDto.fromJson(Map<String, dynamic> json) =>
      V1LessonSessionPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1LessonSessionDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1LessonSessionDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1PageQueryDto {
  const V1PageQueryDto({
    this.schoolId,
    this.classroomId,
    this.studentId,
    this.date,
    this.cursor,
    required this.pageSize,
  });

  factory V1PageQueryDto.fromJson(Map<String, dynamic> json) => V1PageQueryDto(
    schoolId: json['schoolId'] as String?,
    classroomId: json['classroomId'] as String?,
    studentId: json['studentId'] as String?,
    date: json['date'] as String?,
    cursor: json['cursor'] as String?,
    pageSize: json['pageSize'] as int,
  );

  final String? schoolId;
  final String? classroomId;
  final String? studentId;
  final String? date;
  final String? cursor;
  final int pageSize;

  Map<String, Object?> toJson() => {
    'schoolId': ?schoolId,
    'classroomId': ?classroomId,
    'studentId': ?studentId,
    'date': ?date,
    'cursor': ?cursor,
    'pageSize': pageSize,
  };
}

class V1QuestionScoreReviewDto {
  const V1QuestionScoreReviewDto({
    required this.questionId,
    required this.score,
    required this.reason,
  });

  factory V1QuestionScoreReviewDto.fromJson(Map<String, dynamic> json) =>
      V1QuestionScoreReviewDto(
        questionId: json['questionId'] as String,
        score: json['score'] as num,
        reason: json['reason'] as String?,
      );

  final String questionId;
  final num score;
  final String? reason;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'score': score,
    'reason': reason,
  };
}

class V1RecordAttendanceRequestDto {
  const V1RecordAttendanceRequestDto({
    required this.classroomId,
    required this.startsAt,
    required this.endsAt,
    required this.expectedVersion,
    required this.entries,
  });

  factory V1RecordAttendanceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RecordAttendanceRequestDto(
        classroomId: json['classroomId'] as String,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String,
        expectedVersion: json['expectedVersion'] as int,
        entries: [
          for (final item in json['entries'] as List<dynamic>)
            V1AttendanceEntryDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String classroomId;
  final String startsAt;
  final String endsAt;
  final int expectedVersion;
  final List<V1AttendanceEntryDto> entries;

  Map<String, Object?> toJson() => {
    'classroomId': classroomId,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'expectedVersion': expectedVersion,
    'entries': [for (final item in entries) item.toJson()],
  };
}

class V1RecordAttendanceResponseDto {
  const V1RecordAttendanceResponseDto({
    required this.sessionId,
    required this.version,
    required this.recorded,
  });

  factory V1RecordAttendanceResponseDto.fromJson(Map<String, dynamic> json) =>
      V1RecordAttendanceResponseDto(
        sessionId: json['sessionId'] as String,
        version: json['version'] as int,
        recorded: json['recorded'] as int,
      );

  final String sessionId;
  final int version;
  final int recorded;

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'version': version,
    'recorded': recorded,
  };
}

class V1ReplaceScheduleRequestDto {
  const V1ReplaceScheduleRequestDto({
    required this.expectedVersion,
    required this.schedule,
  });

  factory V1ReplaceScheduleRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReplaceScheduleRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        schedule: [
          for (final item in json['schedule'] as List<dynamic>)
            V1ScheduleSlotInputDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int expectedVersion;
  final List<V1ScheduleSlotInputDto> schedule;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'schedule': [for (final item in schedule) item.toJson()],
  };
}

class V1ResourceDto {
  const V1ResourceDto({
    required this.id,
    required this.schoolId,
    required this.classroomId,
    required this.title,
    required this.resourceType,
    required this.body,
    required this.state,
    required this.version,
    required this.publishedAt,
  });

  factory V1ResourceDto.fromJson(Map<String, dynamic> json) => V1ResourceDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    classroomId: json['classroomId'] as String?,
    title: json['title'] as String,
    resourceType: json['resourceType'] as String,
    body: json['body'] as String?,
    state: json['state'] as String,
    version: json['version'] as int,
    publishedAt: json['publishedAt'] as String?,
  );

  final String id;
  final String schoolId;
  final String? classroomId;
  final String title;
  final String resourceType;
  final String? body;
  final String state;
  final int version;
  final String? publishedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'classroomId': classroomId,
    'title': title,
    'resourceType': resourceType,
    'body': body,
    'state': state,
    'version': version,
    'publishedAt': publishedAt,
  };
}

class V1ResourcePageDto {
  const V1ResourcePageDto({required this.items, required this.nextCursor});

  factory V1ResourcePageDto.fromJson(Map<String, dynamic> json) =>
      V1ResourcePageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ResourceDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ResourceDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ReviewGradeRequestDto {
  const V1ReviewGradeRequestDto({
    required this.expectedVersion,
    required this.score,
    required this.feedback,
    this.draftId,
    this.questionScores,
  });

  factory V1ReviewGradeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReviewGradeRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        score: json['score'] as num,
        feedback: json['feedback'] as String?,
        draftId: json['draftId'] as String?,
        questionScores: json['questionScores'] == null
            ? null
            : [
                for (final item in json['questionScores'] as List<dynamic>)
                  V1QuestionScoreReviewDto.fromJson(
                    item as Map<String, dynamic>,
                  ),
              ],
      );

  final int expectedVersion;
  final num score;
  final String? feedback;
  final String? draftId;
  final List<V1QuestionScoreReviewDto>? questionScores;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'score': score,
    'feedback': feedback,
    'draftId': ?draftId,
    if (questionScores != null)
      'questionScores': [for (final item in questionScores!) item.toJson()],
  };
}

class V1ReviseResourceRequestDto {
  const V1ReviseResourceRequestDto({
    required this.expectedVersion,
    required this.title,
    required this.body,
  });

  factory V1ReviseResourceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReviseResourceRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        title: json['title'] as String,
        body: json['body'] as String?,
      );

  final int expectedVersion;
  final String title;
  final String? body;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'title': title,
    'body': body,
  };
}

class V1ScheduleSlotDto {
  const V1ScheduleSlotDto({
    required this.id,
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
    required this.effectiveFrom,
    required this.effectiveUntil,
  });

  factory V1ScheduleSlotDto.fromJson(Map<String, dynamic> json) =>
      V1ScheduleSlotDto(
        id: json['id'] as String?,
        weekday: json['weekday'] as int,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String,
        effectiveFrom: json['effectiveFrom'] as String,
        effectiveUntil: json['effectiveUntil'] as String?,
      );

  final String? id;
  final int weekday;
  final String startsAt;
  final String endsAt;
  final String effectiveFrom;
  final String? effectiveUntil;

  Map<String, Object?> toJson() => {
    'id': id,
    'weekday': weekday,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'effectiveFrom': effectiveFrom,
    'effectiveUntil': effectiveUntil,
  };
}

class V1ScheduleSlotInputDto {
  const V1ScheduleSlotInputDto({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
    required this.effectiveFrom,
    required this.effectiveUntil,
  });

  factory V1ScheduleSlotInputDto.fromJson(Map<String, dynamic> json) =>
      V1ScheduleSlotInputDto(
        weekday: json['weekday'] as int,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String,
        effectiveFrom: json['effectiveFrom'] as String,
        effectiveUntil: json['effectiveUntil'] as String?,
      );

  final int weekday;
  final String startsAt;
  final String endsAt;
  final String effectiveFrom;
  final String? effectiveUntil;

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'effectiveFrom': effectiveFrom,
    'effectiveUntil': effectiveUntil,
  };
}

class V1SchoolDto {
  const V1SchoolDto({
    required this.id,
    required this.name,
    required this.timezone,
    required this.locale,
  });

  factory V1SchoolDto.fromJson(Map<String, dynamic> json) => V1SchoolDto(
    id: json['id'] as String,
    name: json['name'] as String,
    timezone: json['timezone'] as String,
    locale: json['locale'] as String,
  );

  final String id;
  final String name;
  final String timezone;
  final String locale;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'timezone': timezone,
    'locale': locale,
  };
}

class V1StudentPageDto {
  const V1StudentPageDto({required this.items, required this.nextCursor});

  factory V1StudentPageDto.fromJson(Map<String, dynamic> json) =>
      V1StudentPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1StudentSummaryDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1StudentSummaryDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1StudentSummaryDto {
  const V1StudentSummaryDto({
    required this.id,
    required this.displayName,
    required this.studafyId,
  });

  factory V1StudentSummaryDto.fromJson(Map<String, dynamic> json) =>
      V1StudentSummaryDto(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        studafyId: json['studafyId'] as String,
      );

  final String id;
  final String displayName;
  final String studafyId;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'studafyId': studafyId,
  };
}

class V1SubmissionDto {
  const V1SubmissionDto({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.status,
    required this.version,
    required this.answerText,
    required this.submittedAt,
  });

  factory V1SubmissionDto.fromJson(Map<String, dynamic> json) =>
      V1SubmissionDto(
        id: json['id'] as String,
        assignmentId: json['assignmentId'] as String,
        studentId: json['studentId'] as String,
        status: json['status'] as String,
        version: json['version'] as int,
        answerText: json['answerText'] as String?,
        submittedAt: json['submittedAt'] as String?,
      );

  final String id;
  final String assignmentId;
  final String studentId;
  final String status;
  final int version;
  final String? answerText;
  final String? submittedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'assignmentId': assignmentId,
    'studentId': studentId,
    'status': status,
    'version': version,
    'answerText': answerText,
    'submittedAt': submittedAt,
  };
}

class V1SubmissionPageDto {
  const V1SubmissionPageDto({required this.items, required this.nextCursor});

  factory V1SubmissionPageDto.fromJson(Map<String, dynamic> json) =>
      V1SubmissionPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1SubmissionDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1SubmissionDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1SubmitAssessmentRequestDto {
  const V1SubmitAssessmentRequestDto({required this.answers});

  factory V1SubmitAssessmentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SubmitAssessmentRequestDto(
        answers: [
          for (final item in json['answers'] as List<dynamic>)
            V1AssessmentAnswerDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1AssessmentAnswerDto> answers;

  Map<String, Object?> toJson() => {
    'answers': [for (final item in answers) item.toJson()],
  };
}

class V1SubmitAssignmentRequestDto {
  const V1SubmitAssignmentRequestDto({required this.answerText});

  factory V1SubmitAssignmentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SubmitAssignmentRequestDto(answerText: json['answerText'] as String);

  final String answerText;

  Map<String, Object?> toJson() => {'answerText': answerText};
}

class V1TermDto {
  const V1TermDto({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.status,
  });

  factory V1TermDto.fromJson(Map<String, dynamic> json) => V1TermDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    name: json['name'] as String,
    startsOn: json['startsOn'] as String,
    endsOn: json['endsOn'] as String,
    status: json['status'] as String,
  );

  final String id;
  final String schoolId;
  final String name;
  final String startsOn;
  final String endsOn;
  final String status;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'name': name,
    'startsOn': startsOn,
    'endsOn': endsOn,
    'status': status,
  };
}

class V1TermPageDto {
  const V1TermPageDto({required this.items, required this.nextCursor});

  factory V1TermPageDto.fromJson(Map<String, dynamic> json) => V1TermPageDto(
    items: [
      for (final item in json['items'] as List<dynamic>)
        V1TermDto.fromJson(item as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );

  final List<V1TermDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1UpdateClassroomRequestDto {
  const V1UpdateClassroomRequestDto({
    required this.expectedVersion,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
  });

  factory V1UpdateClassroomRequestDto.fromJson(Map<String, dynamic> json) =>
      V1UpdateClassroomRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        name: json['name'] as String,
        grade: json['grade'] as String,
        section: json['section'] as String,
        room: json['room'] as String?,
      );

  final int expectedVersion;
  final String name;
  final String grade;
  final String section;
  final String? room;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
  };
}

class V1VersionCommandRequestDto {
  const V1VersionCommandRequestDto({required this.expectedVersion});

  factory V1VersionCommandRequestDto.fromJson(Map<String, dynamic> json) =>
      V1VersionCommandRequestDto(
        expectedVersion: json['expectedVersion'] as int,
      );

  final int expectedVersion;

  Map<String, Object?> toJson() => {'expectedVersion': expectedVersion};
}

class V1WellbeingEventDto {
  const V1WellbeingEventDto({
    required this.id,
    required this.studentId,
    required this.classroomId,
    required this.kind,
    required this.title,
    required this.context,
    required this.followUp,
    required this.visibility,
    required this.severity,
    required this.createdAt,
  });

  factory V1WellbeingEventDto.fromJson(Map<String, dynamic> json) =>
      V1WellbeingEventDto(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        classroomId: json['classroomId'] as String?,
        kind: json['kind'] as String,
        title: json['title'] as String,
        context: json['context'] as String?,
        followUp: json['followUp'] as String?,
        visibility: json['visibility'] as String,
        severity: json['severity'] as String?,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final String studentId;
  final String? classroomId;
  final String kind;
  final String title;
  final String? context;
  final String? followUp;
  final String visibility;
  final String? severity;
  final String createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'studentId': studentId,
    'classroomId': classroomId,
    'kind': kind,
    'title': title,
    'context': context,
    'followUp': followUp,
    'visibility': visibility,
    'severity': severity,
    'createdAt': createdAt,
  };
}

class V1WellbeingPageDto {
  const V1WellbeingPageDto({required this.items, required this.nextCursor});

  factory V1WellbeingPageDto.fromJson(Map<String, dynamic> json) =>
      V1WellbeingPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1WellbeingEventDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1WellbeingEventDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}
