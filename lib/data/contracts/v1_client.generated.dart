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
    String? startsAt,
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
          'startsAt': startsAt,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1TermDto> createTerm(
    V1CreateTermRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1TermDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/terms', {'schoolId': schoolId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassroomPageDto> listClassrooms({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1ClassroomPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/classrooms', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1ResourcePageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/resources', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1LessonSessionPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/lesson-sessions', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1AssignmentPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/assignments', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1AssessmentPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/assessments', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1GradeResultPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/grade-results', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1AttendancePageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/attendance', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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
    String? startsAt,
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
          'startsAt': startsAt,
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
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1WellbeingPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/wellbeing', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
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

  Future<V1SchoolAdminDto> provisionSchool(
    V1ProvisionSchoolRequestDto request, {
    String? idempotencyKey,
  }) async => V1SchoolAdminDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SchoolAdminDto> suspendSchool(
    V1SchoolLifecycleRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1SchoolAdminDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/suspend', {'schoolId': schoolId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SchoolAdminDto> closeSchool(
    V1SchoolLifecycleRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1SchoolAdminDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/close', {'schoolId': schoolId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MembershipRecordDto> grantMembership(
    V1GrantMembershipRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1MembershipRecordDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/memberships/grant', {
        'schoolId': schoolId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MembershipRecordDto> activateMembership(
    V1MembershipLifecycleRequestDto request, {
    required String membershipId,
    String? idempotencyKey,
  }) async => V1MembershipRecordDto.fromJson(
    await _transport.post(
      _v1Path('/v1/memberships/{membershipId}/activate', {
        'membershipId': membershipId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MembershipRecordDto> suspendMembership(
    V1MembershipLifecycleRequestDto request, {
    required String membershipId,
    String? idempotencyKey,
  }) async => V1MembershipRecordDto.fromJson(
    await _transport.post(
      _v1Path('/v1/memberships/{membershipId}/suspend', {
        'membershipId': membershipId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MembershipRecordDto> revokeMembership(
    V1MembershipLifecycleRequestDto request, {
    required String membershipId,
    String? idempotencyKey,
  }) async => V1MembershipRecordDto.fromJson(
    await _transport.post(
      _v1Path('/v1/memberships/{membershipId}/revoke', {
        'membershipId': membershipId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassroomStaffAssignmentDto> assignClassroomStaff(
    V1AssignClassroomStaffRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1ClassroomStaffAssignmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/staff/assign', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassroomStaffAssignmentDto> removeClassroomStaff(
    V1RemoveClassroomStaffRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1ClassroomStaffAssignmentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/staff/remove', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1EnrollmentTransitionDto> enrollStudent(
    V1EnrollStudentRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1EnrollmentTransitionDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/enrollments/enroll', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1EnrollmentTransitionDto> withdrawStudent(
    V1WithdrawStudentRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1EnrollmentTransitionDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/enrollments/withdraw', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1EnrollmentTransitionDto> transferEnrollment(
    V1TransferEnrollmentRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1EnrollmentTransitionDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/enrollments/transfer', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1InvitationPageDto> listInvitations({
    required String schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1InvitationPageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/schools/{schoolId}/invitations',
        {'schoolId': schoolId},
        {
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'startsAt': startsAt,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1IssueInvitationResponseDto> issueInvitation(
    V1IssueInvitationRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1IssueInvitationResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/invitations', {'schoolId': schoolId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1InvitationDto> revokeInvitation(
    V1RevokeInvitationRequestDto request, {
    required String invitationId,
    String? idempotencyKey,
  }) async => V1InvitationDto.fromJson(
    await _transport.post(
      _v1Path('/v1/invitations/{invitationId}/revoke', {
        'invitationId': invitationId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AcceptInvitationResponseDto> acceptInvitation(
    V1AcceptInvitationRequestDto request, {
    String? idempotencyKey,
  }) async => V1AcceptInvitationResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/invitations/accept', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1LocateStudentResponseDto> locateStudent(
    V1LocateStudentRequestDto request, {
    String? idempotencyKey,
  }) async => V1LocateStudentResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/students/locate', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GuardianLinkDto> requestGuardianLink(
    V1RequestGuardianLinkRequestDto request, {
    String? idempotencyKey,
  }) async => V1GuardianLinkDto.fromJson(
    await _transport.post(
      _v1Path('/v1/guardian-links', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GuardianLinkDto> verifyGuardianLink(
    V1VerifyGuardianLinkRequestDto request, {
    required String guardianLinkId,
    String? idempotencyKey,
  }) async => V1GuardianLinkDto.fromJson(
    await _transport.post(
      _v1Path('/v1/guardian-links/{guardianLinkId}/verify', {
        'guardianLinkId': guardianLinkId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1GuardianLinkDto> revokeGuardianLink(
    V1RevokeGuardianLinkRequestDto request, {
    required String guardianLinkId,
    String? idempotencyKey,
  }) async => V1GuardianLinkDto.fromJson(
    await _transport.post(
      _v1Path('/v1/guardian-links/{guardianLinkId}/revoke', {
        'guardianLinkId': guardianLinkId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ConversationPageDto> listConversations({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1ConversationPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/conversations', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ConversationDto> createConversation(
    V1CreateConversationRequestDto request, {
    String? idempotencyKey,
  }) async => V1ConversationDto.fromJson(
    await _transport.post(
      _v1Path('/v1/conversations', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MessagePageDto> listMessages({
    required String conversationId,
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1MessagePageDto.fromJson(
    await _transport.get(
      _v1Path(
        '/v1/conversations/{conversationId}/messages',
        {'conversationId': conversationId},
        {
          'schoolId': schoolId,
          'classroomId': classroomId,
          'studentId': studentId,
          'date': date,
          'startsAt': startsAt,
          'cursor': cursor,
          'pageSize': pageSize,
        },
      ),
    ),
  );

  Future<V1MessageDto> sendMessage(
    V1SendMessageRequestDto request, {
    required String conversationId,
    String? idempotencyKey,
  }) async => V1MessageDto.fromJson(
    await _transport.post(
      _v1Path('/v1/conversations/{conversationId}/messages', {
        'conversationId': conversationId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1AnnouncementPageDto> listAnnouncements({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1AnnouncementPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/announcements', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1AnnouncementDto> createAnnouncement(
    V1CreateAnnouncementRequestDto request, {
    String? idempotencyKey,
  }) async => V1AnnouncementDto.fromJson(
    await _transport.post(
      _v1Path('/v1/announcements', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MeetingDto> requestMeeting(
    V1RequestMeetingRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1MeetingDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/meetings', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MeetingDto> cancelMeeting(
    V1CancelMeetingRequestDto request, {
    required String meetingId,
    String? idempotencyKey,
  }) async => V1MeetingDto.fromJson(
    await _transport.post(
      _v1Path('/v1/meetings/{meetingId}/cancel', {'meetingId': meetingId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1MeetingStatusResponseDto> getMeetingStatus({
    required String meetingId,
  }) async => V1MeetingStatusResponseDto.fromJson(
    await _transport.get(
      _v1Path('/v1/meetings/{meetingId}', {'meetingId': meetingId}, {}),
    ),
  );

  Future<V1NotificationPageDto> listNotifications({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1NotificationPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/notifications', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1UnreadCountResponseDto> getUnreadCount() async =>
      V1UnreadCountResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/notifications/unread-count', {}, {})),
      );

  Future<V1MarkNotificationsReadResponseDto> markNotificationsRead(
    V1MarkNotificationsReadRequestDto request, {
    String? idempotencyKey,
  }) async => V1MarkNotificationsReadResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/notifications/mark-read', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1NotificationPreferencesResponseDto>
  getNotificationPreferences() async =>
      V1NotificationPreferencesResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/notifications/preferences', {}, {})),
      );

  Future<V1NotificationPreferenceDto> updateNotificationPreferences(
    V1UpdateNotificationPreferenceRequestDto request, {
    String? idempotencyKey,
  }) async => V1NotificationPreferenceDto.fromJson(
    await _transport.post(
      _v1Path('/v1/notifications/preferences', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ProfileResponseDto> updateProfile(
    V1UpdateProfileRequestDto request, {
    String? idempotencyKey,
  }) async => V1ProfileResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/account/profile', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1DataExportRequestDto> requestDataExport(
    V1RequestDataExportRequestDto request, {
    String? idempotencyKey,
  }) async => V1DataExportRequestDto.fromJson(
    await _transport.post(
      _v1Path('/v1/account/export-request', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ExportStatusResponseDto> getExportStatus() async =>
      V1ExportStatusResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/account/export-status', {}, {})),
      );

  Future<V1SupportAccessGrantPageDto> listSupportAccessGrants({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1SupportAccessGrantPageDto.fromJson(
    await _transport.get(
      _v1Path('/internal/support-access', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1SupportAccessGrantDto> requestSupportAccess(
    V1RequestSupportAccessRequestDto request, {
    String? idempotencyKey,
  }) async => V1SupportAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/support-access', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SupportAccessGrantDto> approveSupportAccess(
    V1SupportAccessLifecycleRequestDto request, {
    required String supportGrantId,
    String? idempotencyKey,
  }) async => V1SupportAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/support-access/{supportGrantId}/approve', {
        'supportGrantId': supportGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SupportAccessGrantDto> startSupportAccess(
    V1SupportAccessLifecycleRequestDto request, {
    required String supportGrantId,
    String? idempotencyKey,
  }) async => V1SupportAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/support-access/{supportGrantId}/start', {
        'supportGrantId': supportGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SupportAccessGrantDto> revokeSupportAccess(
    V1RevokeSupportAccessRequestDto request, {
    required String supportGrantId,
    String? idempotencyKey,
  }) async => V1SupportAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/support-access/{supportGrantId}/revoke', {
        'supportGrantId': supportGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1SchoolStudentDto> createStudent(
    V1CreateStudentRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1SchoolStudentDto.fromJson(
    await _transport.post(
      _v1Path('/v1/schools/{schoolId}/students', {'schoolId': schoolId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ContentControlsDto> getContentControls({
    required String schoolId,
  }) async => V1ContentControlsDto.fromJson(
    await _transport.get(
      _v1Path('/v1/control-panel/content-controls/{schoolId}', {
        'schoolId': schoolId,
      }, {}),
    ),
  );

  Future<V1ContentControlsDto> updateContentControls(
    V1UpdateContentControlsRequestDto request, {
    required String schoolId,
    String? idempotencyKey,
  }) async => V1ContentControlsDto.fromJson(
    await _transport.post(
      _v1Path('/v1/control-panel/content-controls/{schoolId}', {
        'schoolId': schoolId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ReportPageDto> listReports({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1ReportPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/reports', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ReportDto> createReport(
    V1CreateReportRequestDto request, {
    String? idempotencyKey,
  }) async => V1ReportDto.fromJson(
    await _transport.post(
      _v1Path('/v1/reports', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ReportDto> getReport({required String reportId}) async =>
      V1ReportDto.fromJson(
        await _transport.get(
          _v1Path('/v1/reports/{reportId}', {'reportId': reportId}, {}),
        ),
      );

  Future<V1ReportDto> appealReport(
    V1AppealReportRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1ReportDto.fromJson(
    await _transport.post(
      _v1Path('/v1/reports/{reportId}/appeal', {'reportId': reportId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1BlockPageDto> listBlocks({
    String? schoolId,
    String? cursor,
    int? pageSize,
  }) async => V1BlockPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/blocks', {}, {
        'schoolId': schoolId,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1BlockDto> createBlock(
    V1CreateBlockRequestDto request, {
    String? idempotencyKey,
  }) async => V1BlockDto.fromJson(
    await _transport.post(
      _v1Path('/v1/blocks', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1BlockDto> unblockUser(
    V1UnblockUserRequestDto request, {
    required String blockId,
    String? idempotencyKey,
  }) async => V1BlockDto.fromJson(
    await _transport.post(
      _v1Path('/v1/blocks/{blockId}/unblock', {'blockId': blockId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationOverviewDto> getModerationOverview({
    String? schoolId,
  }) async => V1ModerationOverviewDto.fromJson(
    await _transport.get(
      _v1Path('/internal/moderation/overview', {}, {'schoolId': schoolId}),
    ),
  );

  Future<V1ModerationQueuePageDto> listModerationQueue({
    String? schoolId,
    String? status,
    String? priority,
    String? cursor,
    int? pageSize,
  }) async => V1ModerationQueuePageDto.fromJson(
    await _transport.get(
      _v1Path('/internal/moderation/queue', {}, {
        'schoolId': schoolId,
        'status': status,
        'priority': priority,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ModerationReportDto> getModerationReport({
    required String reportId,
  }) async => V1ModerationReportDto.fromJson(
    await _transport.get(
      _v1Path('/internal/moderation/reports/{reportId}', {
        'reportId': reportId,
      }, {}),
    ),
  );

  Future<V1ModerationReportDto> triageReport(
    V1ReportLifecycleRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1ModerationReportDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/reports/{reportId}/triage', {
        'reportId': reportId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationReportDto> resolveReport(
    V1ResolveReportRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1ModerationReportDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/reports/{reportId}/resolve', {
        'reportId': reportId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationReportDto> escalateReport(
    V1EscalateReportRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1ModerationReportDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/reports/{reportId}/escalate', {
        'reportId': reportId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationReportDto> addReportEvidence(
    V1AddReportEvidenceRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1ModerationReportDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/reports/{reportId}/evidence', {
        'reportId': reportId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1LegalHoldDto> holdReport(
    V1HoldReportRequestDto request, {
    required String reportId,
    String? idempotencyKey,
  }) async => V1LegalHoldDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/reports/{reportId}/hold', {
        'reportId': reportId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1LegalHoldDto> releaseLegalHold(
    V1ReleaseLegalHoldRequestDto request, {
    required String legalHoldId,
    String? idempotencyKey,
  }) async => V1LegalHoldDto.fromJson(
    await _transport.post(
      _v1Path('/internal/legal-holds/{legalHoldId}/release', {
        'legalHoldId': legalHoldId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationAccessGrantPageDto> listModerationAccess({
    String? schoolId,
    String? cursor,
    int? pageSize,
  }) async => V1ModerationAccessGrantPageDto.fromJson(
    await _transport.get(
      _v1Path('/internal/moderation/access', {}, {
        'schoolId': schoolId,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1ModerationAccessGrantDto> requestModerationAccess(
    V1RequestModerationAccessRequestDto request, {
    String? idempotencyKey,
  }) async => V1ModerationAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/access', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationAccessGrantDto> approveModerationAccess(
    V1ModerationAccessLifecycleRequestDto request, {
    required String moderationGrantId,
    String? idempotencyKey,
  }) async => V1ModerationAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/access/{moderationGrantId}/approve', {
        'moderationGrantId': moderationGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationAccessGrantDto> startModerationAccess(
    V1ModerationAccessLifecycleRequestDto request, {
    required String moderationGrantId,
    String? idempotencyKey,
  }) async => V1ModerationAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/access/{moderationGrantId}/start', {
        'moderationGrantId': moderationGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ModerationAccessGrantDto> revokeModerationAccess(
    V1RevokeModerationAccessRequestDto request, {
    required String moderationGrantId,
    String? idempotencyKey,
  }) async => V1ModerationAccessGrantDto.fromJson(
    await _transport.post(
      _v1Path('/internal/moderation/access/{moderationGrantId}/revoke', {
        'moderationGrantId': moderationGrantId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1CreateUploadIntentResponseDto> createUploadIntent(
    V1CreateUploadIntentRequestDto request, {
    String? idempotencyKey,
  }) async => V1CreateUploadIntentResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/uploads', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1UploadSessionDto> getUploadStatus({
    required String uploadId,
  }) async => V1UploadSessionDto.fromJson(
    await _transport.get(
      _v1Path('/v1/uploads/{uploadId}', {'uploadId': uploadId}, {}),
    ),
  );

  Future<V1CompleteUploadResponseDto> completeUpload(
    V1CompleteUploadRequestDto request, {
    required String uploadId,
    String? idempotencyKey,
  }) async => V1CompleteUploadResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/uploads/{uploadId}/complete', {'uploadId': uploadId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1FileDto> getFileStatus({required String fileId}) async =>
      V1FileDto.fromJson(
        await _transport.get(
          _v1Path('/v1/files/{fileId}', {'fileId': fileId}, {}),
        ),
      );

  Future<V1DownloadIntentResponseDto> createFileDownloadIntent(
    V1DownloadIntentRequestDto request, {
    required String fileId,
    String? idempotencyKey,
  }) async => V1DownloadIntentResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/files/{fileId}/download-intent', {'fileId': fileId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1PublishFileResponseDto> publishFile(
    V1PublishFileRequestDto request, {
    required String fileId,
    String? idempotencyKey,
  }) async => V1PublishFileResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/files/{fileId}/publish', {'fileId': fileId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1PurchaseApprovalsResponseDto> listPurchaseApprovals() async =>
      V1PurchaseApprovalsResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/billing/purchase-approvals', {}, {})),
      );

  Future<V1PurchaseApprovalDto> requestPurchaseApproval(
    V1RequestPurchaseApprovalRequestDto request, {
    String? idempotencyKey,
  }) async => V1PurchaseApprovalDto.fromJson(
    await _transport.post(
      _v1Path('/v1/billing/purchase-approvals', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1PurchaseApprovalDto> decidePurchaseApproval(
    V1DecidePurchaseApprovalRequestDto request, {
    required String approvalId,
    String? idempotencyKey,
  }) async => V1PurchaseApprovalDto.fromJson(
    await _transport.post(
      _v1Path('/v1/billing/purchase-approvals/{approvalId}/decision', {
        'approvalId': approvalId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1BillingCatalogueResponseDto> getBillingCatalogue() async =>
      V1BillingCatalogueResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/billing/catalogue', {}, {})),
      );

  Future<V1SubmitPurchaseResponseDto> submitPurchase(
    V1SubmitPurchaseRequestDto request, {
    String? idempotencyKey,
  }) async => V1SubmitPurchaseResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/billing/purchases', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1RestorePurchaseResponseDto> restorePurchase(
    V1RestorePurchaseRequestDto request, {
    String? idempotencyKey,
  }) async => V1RestorePurchaseResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/billing/restore', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1EntitlementsResponseDto> listEntitlements() async =>
      V1EntitlementsResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/billing/entitlements', {}, {})),
      );

  Future<V1SetSelfPurchaseResponseDto> setSelfPurchase(
    V1SetSelfPurchaseRequestDto request, {
    String? idempotencyKey,
  }) async => V1SetSelfPurchaseResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/billing/school-settings/self-purchase', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ContactPageDto> listContacts({
    String? schoolId,
    String? classroomId,
    String? studentId,
    String? date,
    String? startsAt,
    String? cursor,
    int? pageSize,
  }) async => V1ContactPageDto.fromJson(
    await _transport.get(
      _v1Path('/v1/contacts', {}, {
        'schoolId': schoolId,
        'classroomId': classroomId,
        'studentId': studentId,
        'date': date,
        'startsAt': startsAt,
        'cursor': cursor,
        'pageSize': pageSize,
      }),
    ),
  );

  Future<V1MyGuardianLinksResponseDto> listMyGuardianLinks() async =>
      V1MyGuardianLinksResponseDto.fromJson(
        await _transport.get(_v1Path('/v1/me/guardian-links', {}, {})),
      );

  Future<V1DataExportDocumentDto> downloadDataExport() async =>
      V1DataExportDocumentDto.fromJson(
        await _transport.get(_v1Path('/v1/account/export-download', {}, {})),
      );

  Future<V1PushDeviceResponseDto> registerPushDevice(
    V1RegisterPushDeviceRequestDto request, {
    String? idempotencyKey,
  }) async => V1PushDeviceResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/me/push-devices', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1PushDeviceResponseDto> unregisterPushDevice(
    V1UnregisterPushDeviceRequestDto request, {
    String? idempotencyKey,
  }) async => V1PushDeviceResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/me/push-devices/unregister', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassJoinLinkDto> getClassJoinLink({
    required String classroomId,
  }) async => V1ClassJoinLinkDto.fromJson(
    await _transport.get(
      _v1Path('/v1/classrooms/{classroomId}/join-link', {
        'classroomId': classroomId,
      }, {}),
    ),
  );

  Future<V1CreateClassJoinLinkResponseDto> createClassJoinLink(
    V1CreateClassJoinLinkRequestDto request, {
    required String classroomId,
    String? idempotencyKey,
  }) async => V1CreateClassJoinLinkResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/classrooms/{classroomId}/join-link', {
        'classroomId': classroomId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1ClassJoinLinkDto> revokeClassJoinLink(
    V1RevokeClassJoinLinkRequestDto request, {
    required String linkId,
    String? idempotencyKey,
  }) async => V1ClassJoinLinkDto.fromJson(
    await _transport.post(
      _v1Path('/v1/class-join-links/{linkId}/revoke', {'linkId': linkId}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1RedeemClassJoinLinkResponseDto> redeemClassJoinLink(
    V1RedeemClassJoinLinkRequestDto request, {
    String? idempotencyKey,
  }) async => V1RedeemClassJoinLinkResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/class-join-links/redeem', {}, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1CloseLessonSessionResponseDto> closeLessonSession(
    V1CloseLessonSessionRequestDto request, {
    required String lessonSessionId,
    String? idempotencyKey,
  }) async => V1CloseLessonSessionResponseDto.fromJson(
    await _transport.post(
      _v1Path('/v1/lesson-sessions/{lessonSessionId}/close', {
        'lessonSessionId': lessonSessionId,
      }, {}),
      request.toJson(),
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
  );

  Future<V1StudentFamilyDto> getStudentFamily() async =>
      V1StudentFamilyDto.fromJson(
        await _transport.get(_v1Path('/v1/me/student-family', {}, {})),
      );

  Future<V1GuardianLinkDto> decideGuardianLink(
    V1DecideGuardianLinkRequestDto request, {
    required String guardianLinkId,
    String? idempotencyKey,
  }) async => V1GuardianLinkDto.fromJson(
    await _transport.post(
      _v1Path('/v1/guardian-links/{guardianLinkId}/student-decision', {
        'guardianLinkId': guardianLinkId,
      }, {}),
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

class V1AcceptInvitationRequestDto {
  const V1AcceptInvitationRequestDto({required this.token});

  factory V1AcceptInvitationRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AcceptInvitationRequestDto(token: json['token'] as String);

  final String token;

  Map<String, Object?> toJson() => {'token': token};
}

class V1AcceptInvitationResponseDto {
  const V1AcceptInvitationResponseDto({
    required this.id,
    required this.schoolId,
    required this.userId,
    required this.role,
    required this.status,
    required this.version,
  });

  factory V1AcceptInvitationResponseDto.fromJson(Map<String, dynamic> json) =>
      V1AcceptInvitationResponseDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        userId: json['userId'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String userId;
  final String role;
  final String status;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'userId': userId,
    'role': role,
    'status': status,
    'version': version,
  };
}

class V1AddReportEvidenceRequestDto {
  const V1AddReportEvidenceRequestDto({
    required this.schoolId,
    required this.kind,
    this.attachmentFileId,
    this.note,
  });

  factory V1AddReportEvidenceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AddReportEvidenceRequestDto(
        schoolId: json['schoolId'] as String,
        kind: json['kind'] as String,
        attachmentFileId: json['attachmentFileId'] as String?,
        note: json['note'] as String?,
      );

  final String schoolId;
  final String kind;
  final String? attachmentFileId;
  final String? note;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'kind': kind,
    'attachmentFileId': ?attachmentFileId,
    'note': ?note,
  };
}

class V1AnnouncementDto {
  const V1AnnouncementDto({
    required this.id,
    required this.schoolId,
    required this.classroomId,
    required this.title,
    required this.body,
    required this.audience,
    required this.important,
    required this.publishedAt,
  });

  factory V1AnnouncementDto.fromJson(Map<String, dynamic> json) =>
      V1AnnouncementDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        classroomId: json['classroomId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        audience: json['audience'] as String,
        important: json['important'] as bool,
        publishedAt: json['publishedAt'] as String,
      );

  final String id;
  final String schoolId;
  final String? classroomId;
  final String title;
  final String body;
  final String audience;
  final bool important;
  final String publishedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'classroomId': classroomId,
    'title': title,
    'body': body,
    'audience': audience,
    'important': important,
    'publishedAt': publishedAt,
  };
}

class V1AnnouncementPageDto {
  const V1AnnouncementPageDto({required this.items, required this.nextCursor});

  factory V1AnnouncementPageDto.fromJson(Map<String, dynamic> json) =>
      V1AnnouncementPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AnnouncementDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AnnouncementDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1AppealReportRequestDto {
  const V1AppealReportRequestDto({
    required this.expectedVersion,
    required this.reason,
  });

  factory V1AppealReportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1AppealReportRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        reason: json['reason'] as String,
      );

  final int expectedVersion;
  final String reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': reason,
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

class V1AssignClassroomStaffRequestDto {
  const V1AssignClassroomStaffRequestDto({
    required this.userId,
    required this.role,
  });

  factory V1AssignClassroomStaffRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1AssignClassroomStaffRequestDto(
    userId: json['userId'] as String,
    role: json['role'] as String,
  );

  final String userId;
  final String role;

  Map<String, Object?> toJson() => {'userId': userId, 'role': role};
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
    required this.session,
    required this.nextCursor,
  });

  factory V1AttendanceRosterPageDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceRosterPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1AttendanceRosterItemDto.fromJson(item as Map<String, dynamic>),
        ],
        session: json['session'] == null
            ? null
            : V1AttendanceRosterSessionDto.fromJson(
                json['session'] as Map<String, dynamic>,
              ),
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1AttendanceRosterItemDto> items;
  final V1AttendanceRosterSessionDto? session;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'session': session?.toJson(),
    'nextCursor': nextCursor,
  };
}

class V1AttendanceRosterSessionDto {
  const V1AttendanceRosterSessionDto({required this.id, required this.version});

  factory V1AttendanceRosterSessionDto.fromJson(Map<String, dynamic> json) =>
      V1AttendanceRosterSessionDto(
        id: json['id'] as String,
        version: json['version'] as int,
      );

  final String id;
  final int version;

  Map<String, Object?> toJson() => {'id': id, 'version': version};
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

class V1AuthErrorDto {
  const V1AuthErrorDto();

  factory V1AuthErrorDto.fromJson(Map<String, dynamic> json) =>
      const V1AuthErrorDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
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

class V1BillingCatalogueResponseDto {
  const V1BillingCatalogueResponseDto({
    required this.purchaseAccountToken,
    required this.products,
    required this.selfPurchase,
  });

  factory V1BillingCatalogueResponseDto.fromJson(Map<String, dynamic> json) =>
      V1BillingCatalogueResponseDto(
        purchaseAccountToken: json['purchaseAccountToken'] as String,
        products: [
          for (final item in json['products'] as List<dynamic>)
            V1BillingProductDto.fromJson(item as Map<String, dynamic>),
        ],
        selfPurchase: [
          for (final item in json['selfPurchase'] as List<dynamic>)
            V1SetSelfPurchaseResponseDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String purchaseAccountToken;
  final List<V1BillingProductDto> products;
  final List<V1SetSelfPurchaseResponseDto> selfPurchase;

  Map<String, Object?> toJson() => {
    'purchaseAccountToken': purchaseAccountToken,
    'products': [for (final item in products) item.toJson()],
    'selfPurchase': [for (final item in selfPurchase) item.toJson()],
  };
}

class V1BillingProductDto {
  const V1BillingProductDto({
    required this.featureKey,
    required this.platform,
    required this.storeProductId,
  });

  factory V1BillingProductDto.fromJson(Map<String, dynamic> json) =>
      V1BillingProductDto(
        featureKey: json['featureKey'] as String,
        platform: json['platform'] as String,
        storeProductId: json['storeProductId'] as String,
      );

  final String featureKey;
  final String platform;
  final String storeProductId;

  Map<String, Object?> toJson() => {
    'featureKey': featureKey,
    'platform': platform,
    'storeProductId': storeProductId,
  };
}

class V1BillingSelfPurchaseStatusDto {
  const V1BillingSelfPurchaseStatusDto({
    required this.schoolId,
    required this.selfPurchaseEnabled,
  });

  factory V1BillingSelfPurchaseStatusDto.fromJson(Map<String, dynamic> json) =>
      V1BillingSelfPurchaseStatusDto(
        schoolId: json['schoolId'] as String,
        selfPurchaseEnabled: json['selfPurchaseEnabled'] as bool,
      );

  final String schoolId;
  final bool selfPurchaseEnabled;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'selfPurchaseEnabled': selfPurchaseEnabled,
  };
}

class V1BlockDto {
  const V1BlockDto({
    required this.id,
    required this.schoolId,
    required this.blockerId,
    required this.blockedId,
    required this.scope,
    required this.reason,
    required this.expiresAt,
    required this.createdAt,
    required this.version,
  });

  factory V1BlockDto.fromJson(Map<String, dynamic> json) => V1BlockDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    blockerId: json['blockerId'] as String,
    blockedId: json['blockedId'] as String,
    scope: json['scope'] as String,
    reason: json['reason'] as String?,
    expiresAt: json['expiresAt'] as String?,
    createdAt: json['createdAt'] as String,
    version: json['version'] as int,
  );

  final String id;
  final String schoolId;
  final String blockerId;
  final String blockedId;
  final String scope;
  final String? reason;
  final String? expiresAt;
  final String createdAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'blockerId': blockerId,
    'blockedId': blockedId,
    'scope': scope,
    'reason': reason,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    'version': version,
  };
}

class V1BlockPageDto {
  const V1BlockPageDto({required this.items, required this.nextCursor});

  factory V1BlockPageDto.fromJson(Map<String, dynamic> json) => V1BlockPageDto(
    items: [
      for (final item in json['items'] as List<dynamic>)
        V1BlockDto.fromJson(item as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );

  final List<V1BlockDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1CancelMeetingRequestDto {
  const V1CancelMeetingRequestDto({required this.expectedVersion});

  factory V1CancelMeetingRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CancelMeetingRequestDto(
        expectedVersion: json['expectedVersion'] as int,
      );

  final int expectedVersion;

  Map<String, Object?> toJson() => {'expectedVersion': expectedVersion};
}

class V1ClassJoinLinkDto {
  const V1ClassJoinLinkDto({
    required this.id,
    required this.schoolId,
    required this.classroomId,
    required this.classroomName,
    required this.status,
    required this.expiresAt,
    required this.maxUses,
    required this.useCount,
    required this.createdAt,
    required this.version,
  });

  factory V1ClassJoinLinkDto.fromJson(Map<String, dynamic> json) =>
      V1ClassJoinLinkDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        classroomId: json['classroomId'] as String,
        classroomName: json['classroomName'] as String,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String,
        maxUses: json['maxUses'] as int?,
        useCount: json['useCount'] as int,
        createdAt: json['createdAt'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String classroomId;
  final String classroomName;
  final String status;
  final String expiresAt;
  final int? maxUses;
  final int useCount;
  final String createdAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'classroomId': classroomId,
    'classroomName': classroomName,
    'status': status,
    'expiresAt': expiresAt,
    'maxUses': maxUses,
    'useCount': useCount,
    'createdAt': createdAt,
    'version': version,
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

class V1ClassroomListErrorDto {
  const V1ClassroomListErrorDto();

  factory V1ClassroomListErrorDto.fromJson(Map<String, dynamic> json) =>
      const V1ClassroomListErrorDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
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

class V1ClassroomStaffAssignmentDto {
  const V1ClassroomStaffAssignmentDto({
    required this.id,
    required this.classroomId,
    required this.userId,
    required this.role,
    required this.status,
  });

  factory V1ClassroomStaffAssignmentDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomStaffAssignmentDto(
        id: json['id'] as String,
        classroomId: json['classroomId'] as String,
        userId: json['userId'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
      );

  final String id;
  final String classroomId;
  final String userId;
  final String role;
  final String status;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'userId': userId,
    'role': role,
    'status': status,
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

class V1CloseLessonSessionRequestDto {
  const V1CloseLessonSessionRequestDto();

  factory V1CloseLessonSessionRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1CloseLessonSessionRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1CloseLessonSessionResponseDto {
  const V1CloseLessonSessionResponseDto({
    required this.id,
    required this.filedAt,
  });

  factory V1CloseLessonSessionResponseDto.fromJson(Map<String, dynamic> json) =>
      V1CloseLessonSessionResponseDto(
        id: json['id'] as String,
        filedAt: json['filedAt'] as String,
      );

  final String id;
  final String filedAt;

  Map<String, Object?> toJson() => {'id': id, 'filedAt': filedAt};
}

class V1CompleteUploadRequestDto {
  const V1CompleteUploadRequestDto();

  factory V1CompleteUploadRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1CompleteUploadRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1CompleteUploadResponseDto {
  const V1CompleteUploadResponseDto({
    required this.session,
    required this.file,
  });

  factory V1CompleteUploadResponseDto.fromJson(Map<String, dynamic> json) =>
      V1CompleteUploadResponseDto(
        session: V1UploadSessionDto.fromJson(
          json['session'] as Map<String, dynamic>,
        ),
        file: V1FileDto.fromJson(json['file'] as Map<String, dynamic>),
      );

  final V1UploadSessionDto session;
  final V1FileDto file;

  Map<String, Object?> toJson() => {
    'session': session.toJson(),
    'file': file.toJson(),
  };
}

class V1ContactDto {
  const V1ContactDto({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.relatedStudentNames,
    required this.relatedStudentIds,
  });

  factory V1ContactDto.fromJson(Map<String, dynamic> json) => V1ContactDto(
    userId: json['userId'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String,
    relatedStudentNames: (json['relatedStudentNames'] as List<dynamic>)
        .cast<String>(),
    relatedStudentIds: (json['relatedStudentIds'] as List<dynamic>)
        .cast<String>(),
  );

  final String userId;
  final String displayName;
  final String role;
  final List<String> relatedStudentNames;
  final List<String> relatedStudentIds;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'role': role,
    'relatedStudentNames': relatedStudentNames,
    'relatedStudentIds': relatedStudentIds,
  };
}

class V1ContactPageDto {
  const V1ContactPageDto({required this.items, required this.nextCursor});

  factory V1ContactPageDto.fromJson(Map<String, dynamic> json) =>
      V1ContactPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ContactDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ContactDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ContentControlsDto {
  const V1ContentControlsDto({
    required this.schoolId,
    required this.messagingEnabled,
    required this.contentFilterLevel,
    required this.classifierAssistEnabled,
    required this.supportContact,
    required this.slaHours,
    required this.version,
    required this.updatedAt,
  });

  factory V1ContentControlsDto.fromJson(Map<String, dynamic> json) =>
      V1ContentControlsDto(
        schoolId: json['schoolId'] as String,
        messagingEnabled: json['messagingEnabled'] as bool,
        contentFilterLevel: json['contentFilterLevel'] as String,
        classifierAssistEnabled: json['classifierAssistEnabled'] as bool,
        supportContact: json['supportContact'] as String?,
        slaHours: json['slaHours'] as Map<String, dynamic>,
        version: json['version'] as int,
        updatedAt: json['updatedAt'] as String?,
      );

  final String schoolId;
  final bool messagingEnabled;
  final String contentFilterLevel;
  final bool classifierAssistEnabled;
  final String? supportContact;
  final Map<String, dynamic> slaHours;
  final int version;
  final String? updatedAt;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'messagingEnabled': messagingEnabled,
    'contentFilterLevel': contentFilterLevel,
    'classifierAssistEnabled': classifierAssistEnabled,
    'supportContact': supportContact,
    'slaHours': slaHours,
    'version': version,
    'updatedAt': updatedAt,
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

class V1ConversationDto {
  const V1ConversationDto({
    required this.id,
    required this.schoolId,
    required this.subject,
    required this.state,
    required this.lastReadAt,
    required this.updatedAt,
    required this.participants,
  });

  factory V1ConversationDto.fromJson(Map<String, dynamic> json) =>
      V1ConversationDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        subject: json['subject'] as String?,
        state: json['state'] as String,
        lastReadAt: json['lastReadAt'] as String?,
        updatedAt: json['updatedAt'] as String,
        participants: [
          for (final item in json['participants'] as List<dynamic>)
            V1ConversationParticipantDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final String id;
  final String schoolId;
  final String? subject;
  final String state;
  final String? lastReadAt;
  final String updatedAt;
  final List<V1ConversationParticipantDto> participants;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'subject': subject,
    'state': state,
    'lastReadAt': lastReadAt,
    'updatedAt': updatedAt,
    'participants': [for (final item in participants) item.toJson()],
  };
}

class V1ConversationPageDto {
  const V1ConversationPageDto({required this.items, required this.nextCursor});

  factory V1ConversationPageDto.fromJson(Map<String, dynamic> json) =>
      V1ConversationPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ConversationDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ConversationDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ConversationParticipantDto {
  const V1ConversationParticipantDto({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  factory V1ConversationParticipantDto.fromJson(Map<String, dynamic> json) =>
      V1ConversationParticipantDto(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        role: json['role'] as String,
      );

  final String userId;
  final String displayName;
  final String role;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'role': role,
  };
}

class V1CorrectGradeRequestDto {
  const V1CorrectGradeRequestDto({
    required this.expectedVersion,
    required this.score,
    required this.feedback,
    required this.reason,
  });

  factory V1CorrectGradeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CorrectGradeRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        score: json['score'] as num,
        feedback: json['feedback'] as String?,
        reason: json['reason'] as String,
      );

  final int expectedVersion;
  final num score;
  final String? feedback;
  final String reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'score': score,
    'feedback': feedback,
    'reason': reason,
  };
}

class V1CreateAnnouncementRequestDto {
  const V1CreateAnnouncementRequestDto({
    required this.schoolId,
    this.classroomId,
    required this.title,
    required this.body,
    required this.audience,
    required this.important,
  });

  factory V1CreateAnnouncementRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateAnnouncementRequestDto(
        schoolId: json['schoolId'] as String,
        classroomId: json['classroomId'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        audience: json['audience'] as String,
        important: json['important'] as bool,
      );

  final String schoolId;
  final String? classroomId;
  final String title;
  final String body;
  final String audience;
  final bool important;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'classroomId': ?classroomId,
    'title': title,
    'body': body,
    'audience': audience,
    'important': important,
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

class V1CreateBlockRequestDto {
  const V1CreateBlockRequestDto({
    required this.schoolId,
    required this.blockedUserId,
    required this.scope,
    this.reason,
    this.durationHours,
  });

  factory V1CreateBlockRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateBlockRequestDto(
        schoolId: json['schoolId'] as String,
        blockedUserId: json['blockedUserId'] as String,
        scope: json['scope'] as String,
        reason: json['reason'] as String?,
        durationHours: json['durationHours'] as int?,
      );

  final String schoolId;
  final String blockedUserId;
  final String scope;
  final String? reason;
  final int? durationHours;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'blockedUserId': blockedUserId,
    'scope': scope,
    'reason': ?reason,
    'durationHours': ?durationHours,
  };
}

class V1CreateClassJoinLinkRequestDto {
  const V1CreateClassJoinLinkRequestDto({this.expiresAt, this.maxUses});

  factory V1CreateClassJoinLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateClassJoinLinkRequestDto(
        expiresAt: json['expiresAt'] as String?,
        maxUses: json['maxUses'] as int?,
      );

  final String? expiresAt;
  final int? maxUses;

  Map<String, Object?> toJson() => {
    'expiresAt': ?expiresAt,
    'maxUses': ?maxUses,
  };
}

class V1CreateClassJoinLinkResponseDto {
  const V1CreateClassJoinLinkResponseDto({
    required this.id,
    required this.schoolId,
    required this.classroomId,
    required this.classroomName,
    required this.status,
    required this.expiresAt,
    required this.maxUses,
    required this.useCount,
    required this.createdAt,
    required this.version,
    required this.token,
  });

  factory V1CreateClassJoinLinkResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1CreateClassJoinLinkResponseDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    classroomId: json['classroomId'] as String,
    classroomName: json['classroomName'] as String,
    status: json['status'] as String,
    expiresAt: json['expiresAt'] as String,
    maxUses: json['maxUses'] as int?,
    useCount: json['useCount'] as int,
    createdAt: json['createdAt'] as String,
    version: json['version'] as int,
    token: json['token'] as String,
  );

  final String id;
  final String schoolId;
  final String classroomId;
  final String classroomName;
  final String status;
  final String expiresAt;
  final int? maxUses;
  final int useCount;
  final String createdAt;
  final int version;
  final String token;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'classroomId': classroomId,
    'classroomName': classroomName,
    'status': status,
    'expiresAt': expiresAt,
    'maxUses': maxUses,
    'useCount': useCount,
    'createdAt': createdAt,
    'version': version,
    'token': token,
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

class V1CreateConversationRequestDto {
  const V1CreateConversationRequestDto({
    required this.schoolId,
    this.subject,
    required this.participantIds,
  });

  factory V1CreateConversationRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateConversationRequestDto(
        schoolId: json['schoolId'] as String,
        subject: json['subject'] as String?,
        participantIds: (json['participantIds'] as List<dynamic>)
            .cast<String>(),
      );

  final String schoolId;
  final String? subject;
  final List<String> participantIds;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'subject': ?subject,
    'participantIds': participantIds,
  };
}

class V1CreateReportRequestDto {
  const V1CreateReportRequestDto({
    required this.schoolId,
    required this.kind,
    required this.details,
    this.messageId,
    this.conversationId,
    this.subjectUserId,
    this.evidenceSnapshot,
    this.classifierConfidence,
    required this.contactConsent,
  });

  factory V1CreateReportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateReportRequestDto(
        schoolId: json['schoolId'] as String,
        kind: json['kind'] as String,
        details: json['details'] as String,
        messageId: json['messageId'] as String?,
        conversationId: json['conversationId'] as String?,
        subjectUserId: json['subjectUserId'] as String?,
        evidenceSnapshot: json['evidenceSnapshot'] as Map<String, dynamic>?,
        classifierConfidence: json['classifierConfidence'] as num?,
        contactConsent: json['contactConsent'] as bool,
      );

  final String schoolId;
  final String kind;
  final String details;
  final String? messageId;
  final String? conversationId;
  final String? subjectUserId;
  final Map<String, dynamic>? evidenceSnapshot;
  final num? classifierConfidence;
  final bool contactConsent;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'kind': kind,
    'details': details,
    'messageId': ?messageId,
    'conversationId': ?conversationId,
    'subjectUserId': ?subjectUserId,
    'evidenceSnapshot': ?evidenceSnapshot,
    'classifierConfidence': ?classifierConfidence,
    'contactConsent': contactConsent,
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
    this.lessonSessionId,
  });

  factory V1CreateResourceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateResourceRequestDto(
        schoolId: json['schoolId'] as String,
        classroomId: json['classroomId'] as String?,
        title: json['title'] as String,
        resourceType: json['resourceType'] as String,
        body: json['body'] as String?,
        audience: json['audience'] as String,
        lessonSessionId: json['lessonSessionId'] as String?,
      );

  final String schoolId;
  final String? classroomId;
  final String title;
  final String resourceType;
  final String? body;
  final String audience;
  final String? lessonSessionId;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'classroomId': classroomId,
    'title': title,
    'resourceType': resourceType,
    'body': body,
    'audience': audience,
    'lessonSessionId': ?lessonSessionId,
  };
}

class V1CreateStudentRequestDto {
  const V1CreateStudentRequestDto({required this.displayName, this.userId});

  factory V1CreateStudentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateStudentRequestDto(
        displayName: json['displayName'] as String,
        userId: json['userId'] as String?,
      );

  final String displayName;
  final String? userId;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'userId': ?userId,
  };
}

class V1CreateTermRequestDto {
  const V1CreateTermRequestDto({
    required this.name,
    required this.startsOn,
    required this.endsOn,
  });

  factory V1CreateTermRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateTermRequestDto(
        name: json['name'] as String,
        startsOn: json['startsOn'] as String,
        endsOn: json['endsOn'] as String,
      );

  final String name;
  final String startsOn;
  final String endsOn;

  Map<String, Object?> toJson() => {
    'name': name,
    'startsOn': startsOn,
    'endsOn': endsOn,
  };
}

class V1CreateUploadIntentRequestDto {
  const V1CreateUploadIntentRequestDto({
    required this.schoolId,
    required this.purpose,
    required this.displayName,
    required this.expectedSizeBytes,
    required this.declaredMediaType,
    required this.sha256,
    this.classroomId,
    this.assignmentId,
    this.studentId,
    this.gradeResultId,
  });

  factory V1CreateUploadIntentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1CreateUploadIntentRequestDto(
        schoolId: json['schoolId'] as String,
        purpose: json['purpose'] as String,
        displayName: json['displayName'] as String,
        expectedSizeBytes: json['expectedSizeBytes'] as int,
        declaredMediaType: json['declaredMediaType'] as String,
        sha256: json['sha256'] as String,
        classroomId: json['classroomId'] as String?,
        assignmentId: json['assignmentId'] as String?,
        studentId: json['studentId'] as String?,
        gradeResultId: json['gradeResultId'] as String?,
      );

  final String schoolId;
  final String purpose;
  final String displayName;
  final int expectedSizeBytes;
  final String declaredMediaType;
  final String sha256;
  final String? classroomId;
  final String? assignmentId;
  final String? studentId;
  final String? gradeResultId;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'purpose': purpose,
    'displayName': displayName,
    'expectedSizeBytes': expectedSizeBytes,
    'declaredMediaType': declaredMediaType,
    'sha256': sha256,
    'classroomId': ?classroomId,
    'assignmentId': ?assignmentId,
    'studentId': ?studentId,
    'gradeResultId': ?gradeResultId,
  };
}

class V1CreateUploadIntentResponseDto {
  const V1CreateUploadIntentResponseDto({
    required this.session,
    required this.uploadUrl,
    required this.method,
    required this.requiredHeaders,
    required this.expiresAt,
  });

  factory V1CreateUploadIntentResponseDto.fromJson(Map<String, dynamic> json) =>
      V1CreateUploadIntentResponseDto(
        session: V1UploadSessionDto.fromJson(
          json['session'] as Map<String, dynamic>,
        ),
        uploadUrl: json['uploadUrl'] as String,
        method: json['method'] as String,
        requiredHeaders: json['requiredHeaders'] as Map<String, dynamic>,
        expiresAt: json['expiresAt'] as String,
      );

  final V1UploadSessionDto session;
  final String uploadUrl;
  final String method;
  final Map<String, dynamic> requiredHeaders;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'session': session.toJson(),
    'uploadUrl': uploadUrl,
    'method': method,
    'requiredHeaders': requiredHeaders,
    'expiresAt': expiresAt,
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

class V1DataExportDocumentDto {
  const V1DataExportDocumentDto({
    required this.format,
    required this.generatedAt,
    required this.sections,
  });

  factory V1DataExportDocumentDto.fromJson(Map<String, dynamic> json) =>
      V1DataExportDocumentDto(
        format: json['format'] as String,
        generatedAt: json['generatedAt'] as String,
        sections: json['sections'] as Map<String, dynamic>,
      );

  final String format;
  final String generatedAt;
  final Map<String, dynamic> sections;

  Map<String, Object?> toJson() => {
    'format': format,
    'generatedAt': generatedAt,
    'sections': sections,
  };
}

class V1DataExportRequestDto {
  const V1DataExportRequestDto({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.readyAt,
    required this.expiresAt,
  });

  factory V1DataExportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1DataExportRequestDto(
        id: json['id'] as String,
        status: json['status'] as String,
        requestedAt: json['requestedAt'] as String,
        readyAt: json['readyAt'] as String?,
        expiresAt: json['expiresAt'] as String?,
      );

  final String id;
  final String status;
  final String requestedAt;
  final String? readyAt;
  final String? expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'requestedAt': requestedAt,
    'readyAt': readyAt,
    'expiresAt': expiresAt,
  };
}

class V1DecideGuardianLinkRequestDto {
  const V1DecideGuardianLinkRequestDto({required this.decision});

  factory V1DecideGuardianLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1DecideGuardianLinkRequestDto(decision: json['decision'] as String);

  final String decision;

  Map<String, Object?> toJson() => {'decision': decision};
}

class V1DecidePurchaseApprovalRequestDto {
  const V1DecidePurchaseApprovalRequestDto({required this.approve});

  factory V1DecidePurchaseApprovalRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1DecidePurchaseApprovalRequestDto(approve: json['approve'] as bool);

  final bool approve;

  Map<String, Object?> toJson() => {'approve': approve};
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

class V1DownloadIntentRequestDto {
  const V1DownloadIntentRequestDto();

  factory V1DownloadIntentRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1DownloadIntentRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1DownloadIntentResponseDto {
  const V1DownloadIntentResponseDto({
    required this.downloadUrl,
    required this.expiresAt,
    required this.displayName,
    required this.mediaType,
  });

  factory V1DownloadIntentResponseDto.fromJson(Map<String, dynamic> json) =>
      V1DownloadIntentResponseDto(
        downloadUrl: json['downloadUrl'] as String,
        expiresAt: json['expiresAt'] as String,
        displayName: json['displayName'] as String,
        mediaType: json['mediaType'] as String,
      );

  final String downloadUrl;
  final String expiresAt;
  final String displayName;
  final String mediaType;

  Map<String, Object?> toJson() => {
    'downloadUrl': downloadUrl,
    'expiresAt': expiresAt,
    'displayName': displayName,
    'mediaType': mediaType,
  };
}

class V1EnrollStudentRequestDto {
  const V1EnrollStudentRequestDto({required this.studentId});

  factory V1EnrollStudentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1EnrollStudentRequestDto(studentId: json['studentId'] as String);

  final String studentId;

  Map<String, Object?> toJson() => {'studentId': studentId};
}

class V1EnrollmentTransitionDto {
  const V1EnrollmentTransitionDto({
    required this.classroomId,
    required this.studentId,
    required this.status,
  });

  factory V1EnrollmentTransitionDto.fromJson(Map<String, dynamic> json) =>
      V1EnrollmentTransitionDto(
        classroomId: json['classroomId'] as String,
        studentId: json['studentId'] as String,
        status: json['status'] as String,
      );

  final String classroomId;
  final String studentId;
  final String status;

  Map<String, Object?> toJson() => {
    'classroomId': classroomId,
    'studentId': studentId,
    'status': status,
  };
}

class V1EntitlementDto {
  const V1EntitlementDto({
    required this.featureKey,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.beneficiaryStudentId,
  });

  factory V1EntitlementDto.fromJson(Map<String, dynamic> json) =>
      V1EntitlementDto(
        featureKey: json['featureKey'] as String,
        status: json['status'] as String,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String?,
        beneficiaryStudentId: json['beneficiaryStudentId'] as String?,
      );

  final String featureKey;
  final String status;
  final String startsAt;
  final String? endsAt;
  final String? beneficiaryStudentId;

  Map<String, Object?> toJson() => {
    'featureKey': featureKey,
    'status': status,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'beneficiaryStudentId': beneficiaryStudentId,
  };
}

class V1EntitlementsResponseDto {
  const V1EntitlementsResponseDto({required this.entitlements});

  factory V1EntitlementsResponseDto.fromJson(Map<String, dynamic> json) =>
      V1EntitlementsResponseDto(
        entitlements: [
          for (final item in json['entitlements'] as List<dynamic>)
            V1EntitlementDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1EntitlementDto> entitlements;

  Map<String, Object?> toJson() => {
    'entitlements': [for (final item in entitlements) item.toJson()],
  };
}

class V1EscalateReportRequestDto {
  const V1EscalateReportRequestDto({required this.expectedVersion, this.note});

  factory V1EscalateReportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1EscalateReportRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        note: json['note'] as String?,
      );

  final int expectedVersion;
  final String? note;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'note': ?note,
  };
}

class V1ExportStatusResponseDto {
  const V1ExportStatusResponseDto({required this.request});

  factory V1ExportStatusResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ExportStatusResponseDto(
        request: json['request'] == null
            ? null
            : V1DataExportRequestDto.fromJson(
                json['request'] as Map<String, dynamic>,
              ),
      );

  final V1DataExportRequestDto? request;

  Map<String, Object?> toJson() => {'request': request?.toJson()};
}

class V1FileDto {
  const V1FileDto({
    required this.id,
    required this.purpose,
    required this.displayName,
    required this.sizeBytes,
    required this.declaredMediaType,
    required this.detectedMediaType,
    required this.scanState,
    required this.createdAt,
    required this.scannedAt,
    required this.failureCode,
  });

  factory V1FileDto.fromJson(Map<String, dynamic> json) => V1FileDto(
    id: json['id'] as String,
    purpose: json['purpose'] as String,
    displayName: json['displayName'] as String,
    sizeBytes: json['sizeBytes'] as int,
    declaredMediaType: json['declaredMediaType'] as String,
    detectedMediaType: json['detectedMediaType'] as String?,
    scanState: json['scanState'] as String,
    createdAt: json['createdAt'] as String,
    scannedAt: json['scannedAt'] as String?,
    failureCode: json['failureCode'] as String?,
  );

  final String id;
  final String purpose;
  final String displayName;
  final int sizeBytes;
  final String declaredMediaType;
  final String? detectedMediaType;
  final String scanState;
  final String createdAt;
  final String? scannedAt;
  final String? failureCode;

  Map<String, Object?> toJson() => {
    'id': id,
    'purpose': purpose,
    'displayName': displayName,
    'sizeBytes': sizeBytes,
    'declaredMediaType': declaredMediaType,
    'detectedMediaType': detectedMediaType,
    'scanState': scanState,
    'createdAt': createdAt,
    'scannedAt': scannedAt,
    'failureCode': failureCode,
  };
}

class V1GradeResultDto {
  const V1GradeResultDto({
    required this.id,
    required this.assessmentId,
    required this.studentId,
    required this.assessmentTitle,
    required this.category,
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
        assessmentTitle: json['assessmentTitle'] as String,
        category: json['category'] as String,
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
  final String assessmentTitle;
  final String category;
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
    'assessmentTitle': assessmentTitle,
    'category': category,
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

class V1GrantMembershipRequestDto {
  const V1GrantMembershipRequestDto({
    required this.userId,
    required this.role,
    this.reason,
  });

  factory V1GrantMembershipRequestDto.fromJson(Map<String, dynamic> json) =>
      V1GrantMembershipRequestDto(
        userId: json['userId'] as String,
        role: json['role'] as String,
        reason: json['reason'] as String?,
      );

  final String userId;
  final String role;
  final String? reason;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'role': role,
    'reason': ?reason,
  };
}

class V1GuardianLinkDto {
  const V1GuardianLinkDto({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.guardianId,
    required this.relationship,
    required this.status,
    required this.expiresAt,
  });

  factory V1GuardianLinkDto.fromJson(Map<String, dynamic> json) =>
      V1GuardianLinkDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        studentId: json['studentId'] as String,
        guardianId: json['guardianId'] as String,
        relationship: json['relationship'] as String?,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String?,
      );

  final String id;
  final String schoolId;
  final String studentId;
  final String guardianId;
  final String? relationship;
  final String status;
  final String? expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'studentId': studentId,
    'guardianId': guardianId,
    'relationship': relationship,
    'status': status,
    'expiresAt': expiresAt,
  };
}

class V1HoldReportRequestDto {
  const V1HoldReportRequestDto({
    required this.schoolId,
    required this.expectedVersion,
    this.subjectUserId,
    required this.appliedTo,
    required this.reason,
    required this.ticketRef,
    this.accountDeletionRequestId,
    this.expiresAt,
  });

  factory V1HoldReportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1HoldReportRequestDto(
        schoolId: json['schoolId'] as String,
        expectedVersion: json['expectedVersion'] as int,
        subjectUserId: json['subjectUserId'] as String?,
        appliedTo: json['appliedTo'] as String,
        reason: json['reason'] as String,
        ticketRef: json['ticketRef'] as String,
        accountDeletionRequestId: json['accountDeletionRequestId'] as String?,
        expiresAt: json['expiresAt'] as String?,
      );

  final String schoolId;
  final int expectedVersion;
  final String? subjectUserId;
  final String appliedTo;
  final String reason;
  final String ticketRef;
  final String? accountDeletionRequestId;
  final String? expiresAt;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'expectedVersion': expectedVersion,
    'subjectUserId': ?subjectUserId,
    'appliedTo': appliedTo,
    'reason': reason,
    'ticketRef': ticketRef,
    'accountDeletionRequestId': ?accountDeletionRequestId,
    'expiresAt': ?expiresAt,
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

class V1InvitationDto {
  const V1InvitationDto({
    required this.id,
    required this.schoolId,
    required this.role,
    required this.email,
    required this.status,
    required this.expiresAt,
    required this.version,
  });

  factory V1InvitationDto.fromJson(Map<String, dynamic> json) =>
      V1InvitationDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        role: json['role'] as String,
        email: json['email'] as String,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String role;
  final String email;
  final String status;
  final String expiresAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'role': role,
    'email': email,
    'status': status,
    'expiresAt': expiresAt,
    'version': version,
  };
}

class V1InvitationPageDto {
  const V1InvitationPageDto({required this.items, required this.nextCursor});

  factory V1InvitationPageDto.fromJson(Map<String, dynamic> json) =>
      V1InvitationPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1InvitationDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1InvitationDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1IssueInvitationRequestDto {
  const V1IssueInvitationRequestDto({
    required this.email,
    required this.role,
    this.classroomId,
  });

  factory V1IssueInvitationRequestDto.fromJson(Map<String, dynamic> json) =>
      V1IssueInvitationRequestDto(
        email: json['email'] as String,
        role: json['role'] as String,
        classroomId: json['classroomId'] as String?,
      );

  final String email;
  final String role;
  final String? classroomId;

  Map<String, Object?> toJson() => {
    'email': email,
    'role': role,
    'classroomId': ?classroomId,
  };
}

class V1IssueInvitationResponseDto {
  const V1IssueInvitationResponseDto({
    required this.id,
    required this.schoolId,
    required this.role,
    required this.email,
    required this.status,
    required this.expiresAt,
    required this.version,
    required this.token,
  });

  factory V1IssueInvitationResponseDto.fromJson(Map<String, dynamic> json) =>
      V1IssueInvitationResponseDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        role: json['role'] as String,
        email: json['email'] as String,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String,
        version: json['version'] as int,
        token: json['token'] as String,
      );

  final String id;
  final String schoolId;
  final String role;
  final String email;
  final String status;
  final String expiresAt;
  final int version;
  final String token;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'role': role,
    'email': email,
    'status': status,
    'expiresAt': expiresAt,
    'version': version,
    'token': token,
  };
}

class V1LegalHoldDto {
  const V1LegalHoldDto({
    required this.id,
    required this.schoolId,
    required this.subjectUserId,
    required this.reportId,
    required this.accountDeletionRequestId,
    required this.appliedTo,
    required this.reason,
    required this.ticketRef,
    required this.status,
    required this.grantedBy,
    required this.releasedBy,
    required this.releasedReason,
    required this.expiresAt,
    required this.releasedAt,
    required this.createdAt,
    required this.version,
  });

  factory V1LegalHoldDto.fromJson(Map<String, dynamic> json) => V1LegalHoldDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    subjectUserId: json['subjectUserId'] as String?,
    reportId: json['reportId'] as String?,
    accountDeletionRequestId: json['accountDeletionRequestId'] as String?,
    appliedTo: json['appliedTo'] as String,
    reason: json['reason'] as String,
    ticketRef: json['ticketRef'] as String,
    status: json['status'] as String,
    grantedBy: json['grantedBy'] as String,
    releasedBy: json['releasedBy'] as String?,
    releasedReason: json['releasedReason'] as String?,
    expiresAt: json['expiresAt'] as String?,
    releasedAt: json['releasedAt'] as String?,
    createdAt: json['createdAt'] as String,
    version: json['version'] as int,
  );

  final String id;
  final String schoolId;
  final String? subjectUserId;
  final String? reportId;
  final String? accountDeletionRequestId;
  final String appliedTo;
  final String reason;
  final String ticketRef;
  final String status;
  final String grantedBy;
  final String? releasedBy;
  final String? releasedReason;
  final String? expiresAt;
  final String? releasedAt;
  final String createdAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'subjectUserId': subjectUserId,
    'reportId': reportId,
    'accountDeletionRequestId': accountDeletionRequestId,
    'appliedTo': appliedTo,
    'reason': reason,
    'ticketRef': ticketRef,
    'status': status,
    'grantedBy': grantedBy,
    'releasedBy': releasedBy,
    'releasedReason': releasedReason,
    'expiresAt': expiresAt,
    'releasedAt': releasedAt,
    'createdAt': createdAt,
    'version': version,
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
    required this.filedAt,
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
        filedAt: json['filedAt'] as String?,
        version: json['version'] as int,
      );

  final String id;
  final String classroomId;
  final String startsAt;
  final String endsAt;
  final String? title;
  final String status;
  final String? filedAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'title': title,
    'status': status,
    'filedAt': filedAt,
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

class V1LocateStudentRequestDto {
  const V1LocateStudentRequestDto({required this.studafyId, this.captchaToken});

  factory V1LocateStudentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1LocateStudentRequestDto(
        studafyId: json['studafyId'] as String,
        captchaToken: json['captchaToken'] as String?,
      );

  final String studafyId;
  final String? captchaToken;

  Map<String, Object?> toJson() => {
    'studafyId': studafyId,
    'captchaToken': ?captchaToken,
  };
}

class V1LocateStudentResponseDto {
  const V1LocateStudentResponseDto({
    required this.found,
    required this.studentId,
    required this.displayName,
  });

  factory V1LocateStudentResponseDto.fromJson(Map<String, dynamic> json) =>
      V1LocateStudentResponseDto(
        found: json['found'] as bool,
        studentId: json['studentId'] as String?,
        displayName: json['displayName'] as String?,
      );

  final bool found;
  final String? studentId;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'found': found,
    'studentId': studentId,
    'displayName': displayName,
  };
}

class V1MarkNotificationsReadRequestDto {
  const V1MarkNotificationsReadRequestDto({this.ids, this.all});

  factory V1MarkNotificationsReadRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1MarkNotificationsReadRequestDto(
    ids: json['ids'] == null
        ? null
        : (json['ids'] as List<dynamic>).cast<String>(),
    all: json['all'] as bool?,
  );

  final List<String>? ids;
  final bool? all;

  Map<String, Object?> toJson() => {'ids': ?ids, 'all': ?all};
}

class V1MarkNotificationsReadResponseDto {
  const V1MarkNotificationsReadResponseDto({required this.markedCount});

  factory V1MarkNotificationsReadResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1MarkNotificationsReadResponseDto(
    markedCount: json['markedCount'] as int,
  );

  final int markedCount;

  Map<String, Object?> toJson() => {'markedCount': markedCount};
}

class V1MeErrorDto {
  const V1MeErrorDto();

  factory V1MeErrorDto.fromJson(Map<String, dynamic> json) =>
      const V1MeErrorDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
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

class V1MeetingDto {
  const V1MeetingDto({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.state,
    required this.meetUrl,
    required this.version,
    required this.recipientCount,
  });

  factory V1MeetingDto.fromJson(Map<String, dynamic> json) => V1MeetingDto(
    id: json['id'] as String,
    classroomId: json['classroomId'] as String,
    title: json['title'] as String,
    startsAt: json['startsAt'] as String,
    endsAt: json['endsAt'] as String,
    audience: json['audience'] as String,
    state: json['state'] as String,
    meetUrl: json['meetUrl'] as String?,
    version: json['version'] as int,
    recipientCount: json['recipientCount'] as int,
  );

  final String id;
  final String classroomId;
  final String title;
  final String startsAt;
  final String endsAt;
  final String audience;
  final String state;
  final String? meetUrl;
  final int version;
  final int recipientCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'classroomId': classroomId,
    'title': title,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'audience': audience,
    'state': state,
    'meetUrl': meetUrl,
    'version': version,
    'recipientCount': recipientCount,
  };
}

class V1MeetingDeliveryDto {
  const V1MeetingDeliveryDto({
    required this.recipientId,
    required this.state,
    required this.deliveredAt,
  });

  factory V1MeetingDeliveryDto.fromJson(Map<String, dynamic> json) =>
      V1MeetingDeliveryDto(
        recipientId: json['recipientId'] as String,
        state: json['state'] as String,
        deliveredAt: json['deliveredAt'] as String?,
      );

  final String recipientId;
  final String state;
  final String? deliveredAt;

  Map<String, Object?> toJson() => {
    'recipientId': recipientId,
    'state': state,
    'deliveredAt': deliveredAt,
  };
}

class V1MeetingStatusResponseDto {
  const V1MeetingStatusResponseDto({
    required this.meeting,
    required this.deliveries,
  });

  factory V1MeetingStatusResponseDto.fromJson(Map<String, dynamic> json) =>
      V1MeetingStatusResponseDto(
        meeting: V1MeetingDto.fromJson(json['meeting'] as Map<String, dynamic>),
        deliveries: [
          for (final item in json['deliveries'] as List<dynamic>)
            V1MeetingDeliveryDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final V1MeetingDto meeting;
  final List<V1MeetingDeliveryDto> deliveries;

  Map<String, Object?> toJson() => {
    'meeting': meeting.toJson(),
    'deliveries': [for (final item in deliveries) item.toJson()],
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

class V1MembershipLifecycleRequestDto {
  const V1MembershipLifecycleRequestDto({
    required this.expectedVersion,
    this.reason,
  });

  factory V1MembershipLifecycleRequestDto.fromJson(Map<String, dynamic> json) =>
      V1MembershipLifecycleRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        reason: json['reason'] as String?,
      );

  final int expectedVersion;
  final String? reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': ?reason,
  };
}

class V1MembershipRecordDto {
  const V1MembershipRecordDto({
    required this.id,
    required this.schoolId,
    required this.userId,
    required this.role,
    required this.status,
    required this.version,
  });

  factory V1MembershipRecordDto.fromJson(Map<String, dynamic> json) =>
      V1MembershipRecordDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        userId: json['userId'] as String,
        role: json['role'] as String,
        status: json['status'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String userId;
  final String role;
  final String status;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'userId': userId,
    'role': role,
    'status': status,
    'version': version,
  };
}

class V1MessageDto {
  const V1MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.createdAt,
  });

  factory V1MessageDto.fromJson(Map<String, dynamic> json) => V1MessageDto(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    clientMessageId: json['clientMessageId'] as String,
    body: json['body'] as String,
    createdAt: json['createdAt'] as String,
  );

  final String id;
  final String conversationId;
  final String senderId;
  final String clientMessageId;
  final String body;
  final String createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'clientMessageId': clientMessageId,
    'body': body,
    'createdAt': createdAt,
  };
}

class V1MessagePageDto {
  const V1MessagePageDto({required this.items, required this.nextCursor});

  factory V1MessagePageDto.fromJson(Map<String, dynamic> json) =>
      V1MessagePageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1MessageDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1MessageDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ModerationAccessGrantDto {
  const V1ModerationAccessGrantDto({
    required this.id,
    required this.schoolId,
    required this.requestedBy,
    required this.approvedBy,
    required this.reason,
    required this.ticketRef,
    required this.resourceScope,
    required this.status,
    required this.requiresSecondApprover,
    required this.expiresAt,
    required this.startedAt,
    required this.endedAt,
    required this.version,
  });

  factory V1ModerationAccessGrantDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationAccessGrantDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        requestedBy: json['requestedBy'] as String,
        approvedBy: json['approvedBy'] as String?,
        reason: json['reason'] as String,
        ticketRef: json['ticketRef'] as String,
        resourceScope: json['resourceScope'] as Map<String, dynamic>,
        status: json['status'] as String,
        requiresSecondApprover: json['requiresSecondApprover'] as bool,
        expiresAt: json['expiresAt'] as String,
        startedAt: json['startedAt'] as String?,
        endedAt: json['endedAt'] as String?,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String requestedBy;
  final String? approvedBy;
  final String reason;
  final String ticketRef;
  final Map<String, dynamic> resourceScope;
  final String status;
  final bool requiresSecondApprover;
  final String expiresAt;
  final String? startedAt;
  final String? endedAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'requestedBy': requestedBy,
    'approvedBy': approvedBy,
    'reason': reason,
    'ticketRef': ticketRef,
    'resourceScope': resourceScope,
    'status': status,
    'requiresSecondApprover': requiresSecondApprover,
    'expiresAt': expiresAt,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'version': version,
  };
}

class V1ModerationAccessGrantPageDto {
  const V1ModerationAccessGrantPageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1ModerationAccessGrantPageDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationAccessGrantPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ModerationAccessGrantDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ModerationAccessGrantDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ModerationAccessLifecycleRequestDto {
  const V1ModerationAccessLifecycleRequestDto({required this.expectedVersion});

  factory V1ModerationAccessLifecycleRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1ModerationAccessLifecycleRequestDto(
    expectedVersion: json['expectedVersion'] as int,
  );

  final int expectedVersion;

  Map<String, Object?> toJson() => {'expectedVersion': expectedVersion};
}

class V1ModerationAccessQueryDto {
  const V1ModerationAccessQueryDto({
    required this.schoolId,
    this.cursor,
    required this.pageSize,
  });

  factory V1ModerationAccessQueryDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationAccessQueryDto(
        schoolId: json['schoolId'] as String,
        cursor: json['cursor'] as String?,
        pageSize: json['pageSize'] as int,
      );

  final String schoolId;
  final String? cursor;
  final int pageSize;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'cursor': ?cursor,
    'pageSize': pageSize,
  };
}

class V1ModerationOverviewDto {
  const V1ModerationOverviewDto({
    required this.schoolId,
    required this.submitted,
    required this.underReview,
    required this.onHold,
    required this.escalated,
    required this.resolved,
    required this.slaBreaches,
    required this.activeModeratorSessions,
  });

  factory V1ModerationOverviewDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationOverviewDto(
        schoolId: json['schoolId'] as String,
        submitted: json['submitted'] as int,
        underReview: json['underReview'] as int,
        onHold: json['onHold'] as int,
        escalated: json['escalated'] as int,
        resolved: json['resolved'] as int,
        slaBreaches: json['slaBreaches'] as int,
        activeModeratorSessions: json['activeModeratorSessions'] as int,
      );

  final String schoolId;
  final int submitted;
  final int underReview;
  final int onHold;
  final int escalated;
  final int resolved;
  final int slaBreaches;
  final int activeModeratorSessions;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'submitted': submitted,
    'underReview': underReview,
    'onHold': onHold,
    'escalated': escalated,
    'resolved': resolved,
    'slaBreaches': slaBreaches,
    'activeModeratorSessions': activeModeratorSessions,
  };
}

class V1ModerationQueuePageDto {
  const V1ModerationQueuePageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1ModerationQueuePageDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationQueuePageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ModerationReportDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ModerationReportDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1ModerationQueueQueryDto {
  const V1ModerationQueueQueryDto({
    required this.schoolId,
    this.status,
    this.priority,
    this.cursor,
    required this.pageSize,
  });

  factory V1ModerationQueueQueryDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationQueueQueryDto(
        schoolId: json['schoolId'] as String,
        status: json['status'] as String?,
        priority: json['priority'] as String?,
        cursor: json['cursor'] as String?,
        pageSize: json['pageSize'] as int,
      );

  final String schoolId;
  final String? status;
  final String? priority;
  final String? cursor;
  final int pageSize;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'status': ?status,
    'priority': ?priority,
    'cursor': ?cursor,
    'pageSize': pageSize,
  };
}

class V1ModerationReportDto {
  const V1ModerationReportDto({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.status,
    required this.resolution,
    required this.priority,
    required this.assignedTo,
    required this.details,
    required this.evidenceSnapshot,
    required this.classifierConfidence,
    required this.aupVersion,
    required this.contactConsent,
    required this.subjectUserId,
    required this.conversationId,
    required this.messageId,
    required this.reporterId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.events,
    required this.evidence,
  });

  factory V1ModerationReportDto.fromJson(Map<String, dynamic> json) =>
      V1ModerationReportDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        kind: json['kind'] as String,
        status: json['status'] as String,
        resolution: json['resolution'] as String?,
        priority: json['priority'] as String,
        assignedTo: json['assignedTo'] as String?,
        details: json['details'] as String,
        evidenceSnapshot: json['evidenceSnapshot'] as Map<String, dynamic>,
        classifierConfidence: json['classifierConfidence'] as num?,
        aupVersion: json['aupVersion'] as String?,
        contactConsent: json['contactConsent'] as bool,
        subjectUserId: json['subjectUserId'] as String?,
        conversationId: json['conversationId'] as String?,
        messageId: json['messageId'] as String?,
        reporterId: json['reporterId'] as String?,
        createdAt: json['createdAt'] as String,
        updatedAt: json['updatedAt'] as String,
        version: json['version'] as int,
        events: (json['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
        evidence: (json['evidence'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );

  final String id;
  final String schoolId;
  final String kind;
  final String status;
  final String? resolution;
  final String priority;
  final String? assignedTo;
  final String details;
  final Map<String, dynamic> evidenceSnapshot;
  final num? classifierConfidence;
  final String? aupVersion;
  final bool contactConsent;
  final String? subjectUserId;
  final String? conversationId;
  final String? messageId;
  final String? reporterId;
  final String createdAt;
  final String updatedAt;
  final int version;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> evidence;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'kind': kind,
    'status': status,
    'resolution': resolution,
    'priority': priority,
    'assignedTo': assignedTo,
    'details': details,
    'evidenceSnapshot': evidenceSnapshot,
    'classifierConfidence': classifierConfidence,
    'aupVersion': aupVersion,
    'contactConsent': contactConsent,
    'subjectUserId': subjectUserId,
    'conversationId': conversationId,
    'messageId': messageId,
    'reporterId': reporterId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'version': version,
    'events': events,
    'evidence': evidence,
  };
}

class V1MyGuardianLinkDto {
  const V1MyGuardianLinkDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.studentId,
    required this.studentName,
    required this.relationship,
    required this.status,
    required this.expiresAt,
  });

  factory V1MyGuardianLinkDto.fromJson(Map<String, dynamic> json) =>
      V1MyGuardianLinkDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        schoolName: json['schoolName'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        relationship: json['relationship'] as String?,
        status: json['status'] as String,
        expiresAt: json['expiresAt'] as String?,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String studentId;
  final String studentName;
  final String? relationship;
  final String status;
  final String? expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'schoolName': schoolName,
    'studentId': studentId,
    'studentName': studentName,
    'relationship': relationship,
    'status': status,
    'expiresAt': expiresAt,
  };
}

class V1MyGuardianLinksResponseDto {
  const V1MyGuardianLinksResponseDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1MyGuardianLinksResponseDto.fromJson(Map<String, dynamic> json) =>
      V1MyGuardianLinksResponseDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1MyGuardianLinkDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1MyGuardianLinkDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1NotificationDto {
  const V1NotificationDto({
    required this.id,
    required this.templateKey,
    required this.payload,
    required this.createdAt,
    required this.readAt,
  });

  factory V1NotificationDto.fromJson(Map<String, dynamic> json) =>
      V1NotificationDto(
        id: json['id'] as String,
        templateKey: json['templateKey'] as String,
        payload: json['payload'] as Map<String, dynamic>,
        createdAt: json['createdAt'] as String,
        readAt: json['readAt'] as String?,
      );

  final String id;
  final String templateKey;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String? readAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'templateKey': templateKey,
    'payload': payload,
    'createdAt': createdAt,
    'readAt': readAt,
  };
}

class V1NotificationPageDto {
  const V1NotificationPageDto({required this.items, required this.nextCursor});

  factory V1NotificationPageDto.fromJson(Map<String, dynamic> json) =>
      V1NotificationPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1NotificationDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1NotificationDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1NotificationPreferenceDto {
  const V1NotificationPreferenceDto({
    required this.schoolId,
    required this.channel,
    required this.category,
    required this.enabled,
  });

  factory V1NotificationPreferenceDto.fromJson(Map<String, dynamic> json) =>
      V1NotificationPreferenceDto(
        schoolId: json['schoolId'] as String?,
        channel: json['channel'] as String,
        category: json['category'] as String,
        enabled: json['enabled'] as bool,
      );

  final String? schoolId;
  final String channel;
  final String category;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'channel': channel,
    'category': category,
    'enabled': enabled,
  };
}

class V1NotificationPreferencesResponseDto {
  const V1NotificationPreferencesResponseDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1NotificationPreferencesResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1NotificationPreferencesResponseDto(
    items: [
      for (final item in json['items'] as List<dynamic>)
        V1NotificationPreferenceDto.fromJson(item as Map<String, dynamic>),
    ],
    nextCursor: json['nextCursor'] as String?,
  );

  final List<V1NotificationPreferenceDto> items;
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
    this.startsAt,
    this.cursor,
    required this.pageSize,
  });

  factory V1PageQueryDto.fromJson(Map<String, dynamic> json) => V1PageQueryDto(
    schoolId: json['schoolId'] as String?,
    classroomId: json['classroomId'] as String?,
    studentId: json['studentId'] as String?,
    date: json['date'] as String?,
    startsAt: json['startsAt'] as String?,
    cursor: json['cursor'] as String?,
    pageSize: json['pageSize'] as int,
  );

  final String? schoolId;
  final String? classroomId;
  final String? studentId;
  final String? date;
  final String? startsAt;
  final String? cursor;
  final int pageSize;

  Map<String, Object?> toJson() => {
    'schoolId': ?schoolId,
    'classroomId': ?classroomId,
    'studentId': ?studentId,
    'date': ?date,
    'startsAt': ?startsAt,
    'cursor': ?cursor,
    'pageSize': pageSize,
  };
}

class V1ProfileResponseDto {
  const V1ProfileResponseDto({
    required this.id,
    required this.displayName,
    required this.locale,
  });

  factory V1ProfileResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ProfileResponseDto(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        locale: json['locale'] as String,
      );

  final String id;
  final String displayName;
  final String locale;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'locale': locale,
  };
}

class V1ProvisionSchoolRequestDto {
  const V1ProvisionSchoolRequestDto({
    required this.name,
    required this.timezone,
    required this.locale,
    required this.initialAdminUserId,
  });

  factory V1ProvisionSchoolRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ProvisionSchoolRequestDto(
        name: json['name'] as String,
        timezone: json['timezone'] as String,
        locale: json['locale'] as String,
        initialAdminUserId: json['initialAdminUserId'] as String,
      );

  final String name;
  final String timezone;
  final String locale;
  final String initialAdminUserId;

  Map<String, Object?> toJson() => {
    'name': name,
    'timezone': timezone,
    'locale': locale,
    'initialAdminUserId': initialAdminUserId,
  };
}

class V1PublishFileRequestDto {
  const V1PublishFileRequestDto({required this.audience});

  factory V1PublishFileRequestDto.fromJson(Map<String, dynamic> json) =>
      V1PublishFileRequestDto(audience: json['audience'] as String);

  final String audience;

  Map<String, Object?> toJson() => {'audience': audience};
}

class V1PublishFileResponseDto {
  const V1PublishFileResponseDto({required this.file, required this.resource});

  factory V1PublishFileResponseDto.fromJson(Map<String, dynamic> json) =>
      V1PublishFileResponseDto(
        file: V1FileDto.fromJson(json['file'] as Map<String, dynamic>),
        resource: V1ResourceDto.fromJson(
          json['resource'] as Map<String, dynamic>,
        ),
      );

  final V1FileDto file;
  final V1ResourceDto resource;

  Map<String, Object?> toJson() => {
    'file': file.toJson(),
    'resource': resource.toJson(),
  };
}

class V1PurchaseApprovalDto {
  const V1PurchaseApprovalDto({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.featureKey,
    required this.status,
    required this.requestedAt,
    required this.decidedAt,
    required this.expiresAt,
  });

  factory V1PurchaseApprovalDto.fromJson(Map<String, dynamic> json) =>
      V1PurchaseApprovalDto(
        id: json['id'] as String,
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        featureKey: json['featureKey'] as String,
        status: json['status'] as String,
        requestedAt: json['requestedAt'] as String,
        decidedAt: json['decidedAt'] as String?,
        expiresAt: json['expiresAt'] as String,
      );

  final String id;
  final String studentId;
  final String studentName;
  final String featureKey;
  final String status;
  final String requestedAt;
  final String? decidedAt;
  final String expiresAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'featureKey': featureKey,
    'status': status,
    'requestedAt': requestedAt,
    'decidedAt': decidedAt,
    'expiresAt': expiresAt,
  };
}

class V1PurchaseApprovalsResponseDto {
  const V1PurchaseApprovalsResponseDto({required this.approvals});

  factory V1PurchaseApprovalsResponseDto.fromJson(Map<String, dynamic> json) =>
      V1PurchaseApprovalsResponseDto(
        approvals: [
          for (final item in json['approvals'] as List<dynamic>)
            V1PurchaseApprovalDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1PurchaseApprovalDto> approvals;

  Map<String, Object?> toJson() => {
    'approvals': [for (final item in approvals) item.toJson()],
  };
}

class V1PushDeviceResponseDto {
  const V1PushDeviceResponseDto({required this.registered});

  factory V1PushDeviceResponseDto.fromJson(Map<String, dynamic> json) =>
      V1PushDeviceResponseDto(registered: json['registered'] as bool);

  final bool registered;

  Map<String, Object?> toJson() => {'registered': registered};
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

class V1RedeemClassJoinLinkRequestDto {
  const V1RedeemClassJoinLinkRequestDto({required this.token});

  factory V1RedeemClassJoinLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RedeemClassJoinLinkRequestDto(token: json['token'] as String);

  final String token;

  Map<String, Object?> toJson() => {'token': token};
}

class V1RedeemClassJoinLinkResponseDto {
  const V1RedeemClassJoinLinkResponseDto({
    required this.schoolId,
    required this.classroomId,
    required this.classroomName,
  });

  factory V1RedeemClassJoinLinkResponseDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RedeemClassJoinLinkResponseDto(
    schoolId: json['schoolId'] as String,
    classroomId: json['classroomId'] as String,
    classroomName: json['classroomName'] as String,
  );

  final String schoolId;
  final String classroomId;
  final String classroomName;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'classroomId': classroomId,
    'classroomName': classroomName,
  };
}

class V1RegisterPushDeviceRequestDto {
  const V1RegisterPushDeviceRequestDto({
    required this.platform,
    required this.token,
  });

  factory V1RegisterPushDeviceRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RegisterPushDeviceRequestDto(
        platform: json['platform'] as String,
        token: json['token'] as String,
      );

  final String platform;
  final String token;

  Map<String, Object?> toJson() => {'platform': platform, 'token': token};
}

class V1ReleaseLegalHoldRequestDto {
  const V1ReleaseLegalHoldRequestDto({
    required this.expectedVersion,
    required this.reason,
  });

  factory V1ReleaseLegalHoldRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReleaseLegalHoldRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        reason: json['reason'] as String,
      );

  final int expectedVersion;
  final String reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': reason,
  };
}

class V1RemoveClassroomStaffRequestDto {
  const V1RemoveClassroomStaffRequestDto({required this.staffAssignmentId});

  factory V1RemoveClassroomStaffRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RemoveClassroomStaffRequestDto(
    staffAssignmentId: json['staffAssignmentId'] as String,
  );

  final String staffAssignmentId;

  Map<String, Object?> toJson() => {'staffAssignmentId': staffAssignmentId};
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

class V1ReportDto {
  const V1ReportDto({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.status,
    required this.resolution,
    required this.details,
    required this.priority,
    required this.contactConsent,
    required this.subjectUserId,
    required this.conversationId,
    required this.messageId,
    required this.aupVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.events,
  });

  factory V1ReportDto.fromJson(Map<String, dynamic> json) => V1ReportDto(
    id: json['id'] as String,
    schoolId: json['schoolId'] as String,
    kind: json['kind'] as String,
    status: json['status'] as String,
    resolution: json['resolution'] as String?,
    details: json['details'] as String,
    priority: json['priority'] as String,
    contactConsent: json['contactConsent'] as bool,
    subjectUserId: json['subjectUserId'] as String?,
    conversationId: json['conversationId'] as String?,
    messageId: json['messageId'] as String?,
    aupVersion: json['aupVersion'] as String?,
    createdAt: json['createdAt'] as String,
    updatedAt: json['updatedAt'] as String,
    version: json['version'] as int,
    events: (json['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
  );

  final String id;
  final String schoolId;
  final String kind;
  final String status;
  final String? resolution;
  final String details;
  final String priority;
  final bool contactConsent;
  final String? subjectUserId;
  final String? conversationId;
  final String? messageId;
  final String? aupVersion;
  final String createdAt;
  final String updatedAt;
  final int version;
  final List<Map<String, dynamic>> events;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'kind': kind,
    'status': status,
    'resolution': resolution,
    'details': details,
    'priority': priority,
    'contactConsent': contactConsent,
    'subjectUserId': subjectUserId,
    'conversationId': conversationId,
    'messageId': messageId,
    'aupVersion': aupVersion,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'version': version,
    'events': events,
  };
}

class V1ReportLifecycleRequestDto {
  const V1ReportLifecycleRequestDto({
    required this.expectedVersion,
    this.note,
    this.assignedTo,
    this.priority,
  });

  factory V1ReportLifecycleRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReportLifecycleRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        note: json['note'] as String?,
        assignedTo: json['assignedTo'] as String?,
        priority: json['priority'] as String?,
      );

  final int expectedVersion;
  final String? note;
  final String? assignedTo;
  final String? priority;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'note': ?note,
    'assignedTo': ?assignedTo,
    'priority': ?priority,
  };
}

class V1ReportPageDto {
  const V1ReportPageDto({required this.items, required this.nextCursor});

  factory V1ReportPageDto.fromJson(Map<String, dynamic> json) =>
      V1ReportPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1ReportDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1ReportDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1RequestDataExportRequestDto {
  const V1RequestDataExportRequestDto();

  factory V1RequestDataExportRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1RequestDataExportRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1RequestGuardianLinkRequestDto {
  const V1RequestGuardianLinkRequestDto({
    required this.studentId,
    this.relationship,
  });

  factory V1RequestGuardianLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RequestGuardianLinkRequestDto(
        studentId: json['studentId'] as String,
        relationship: json['relationship'] as String?,
      );

  final String studentId;
  final String? relationship;

  Map<String, Object?> toJson() => {
    'studentId': studentId,
    'relationship': ?relationship,
  };
}

class V1RequestMeetingRequestDto {
  const V1RequestMeetingRequestDto({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
  });

  factory V1RequestMeetingRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RequestMeetingRequestDto(
        title: json['title'] as String,
        startsAt: json['startsAt'] as String,
        endsAt: json['endsAt'] as String,
        audience: json['audience'] as String,
      );

  final String title;
  final String startsAt;
  final String endsAt;
  final String audience;

  Map<String, Object?> toJson() => {
    'title': title,
    'startsAt': startsAt,
    'endsAt': endsAt,
    'audience': audience,
  };
}

class V1RequestModerationAccessRequestDto {
  const V1RequestModerationAccessRequestDto({
    required this.schoolId,
    required this.reason,
    required this.ticketRef,
    this.resourceScope,
    required this.requiresSecondApprover,
    required this.durationMinutes,
  });

  factory V1RequestModerationAccessRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RequestModerationAccessRequestDto(
    schoolId: json['schoolId'] as String,
    reason: json['reason'] as String,
    ticketRef: json['ticketRef'] as String,
    resourceScope: json['resourceScope'] as Map<String, dynamic>?,
    requiresSecondApprover: json['requiresSecondApprover'] as bool,
    durationMinutes: json['durationMinutes'] as int,
  );

  final String schoolId;
  final String reason;
  final String ticketRef;
  final Map<String, dynamic>? resourceScope;
  final bool requiresSecondApprover;
  final int durationMinutes;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'reason': reason,
    'ticketRef': ticketRef,
    'resourceScope': ?resourceScope,
    'requiresSecondApprover': requiresSecondApprover,
    'durationMinutes': durationMinutes,
  };
}

class V1RequestPurchaseApprovalRequestDto {
  const V1RequestPurchaseApprovalRequestDto({required this.featureKey});

  factory V1RequestPurchaseApprovalRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RequestPurchaseApprovalRequestDto(
    featureKey: json['featureKey'] as String,
  );

  final String featureKey;

  Map<String, Object?> toJson() => {'featureKey': featureKey};
}

class V1RequestSupportAccessRequestDto {
  const V1RequestSupportAccessRequestDto({
    required this.schoolId,
    required this.reason,
    required this.ticketRef,
    this.resourceScope,
    required this.requiresSecondApprover,
    required this.durationMinutes,
  });

  factory V1RequestSupportAccessRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RequestSupportAccessRequestDto(
    schoolId: json['schoolId'] as String,
    reason: json['reason'] as String,
    ticketRef: json['ticketRef'] as String,
    resourceScope: json['resourceScope'] as Map<String, dynamic>?,
    requiresSecondApprover: json['requiresSecondApprover'] as bool,
    durationMinutes: json['durationMinutes'] as int,
  );

  final String schoolId;
  final String reason;
  final String ticketRef;
  final Map<String, dynamic>? resourceScope;
  final bool requiresSecondApprover;
  final int durationMinutes;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'reason': reason,
    'ticketRef': ticketRef,
    'resourceScope': ?resourceScope,
    'requiresSecondApprover': requiresSecondApprover,
    'durationMinutes': durationMinutes,
  };
}

class V1ResolveReportRequestDto {
  const V1ResolveReportRequestDto({
    required this.expectedVersion,
    required this.resolution,
    this.note,
  });

  factory V1ResolveReportRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ResolveReportRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        resolution: json['resolution'] as String,
        note: json['note'] as String?,
      );

  final int expectedVersion;
  final String resolution;
  final String? note;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'resolution': resolution,
    'note': ?note,
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

class V1RestorePurchaseRequestDto {
  const V1RestorePurchaseRequestDto({
    required this.platform,
    required this.environment,
    required this.productFeatureKey,
    required this.storeProductId,
    required this.verificationPayload,
    this.beneficiaryStudentId,
  });

  factory V1RestorePurchaseRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RestorePurchaseRequestDto(
        platform: json['platform'] as String,
        environment: json['environment'] as String,
        productFeatureKey: json['productFeatureKey'] as String,
        storeProductId: json['storeProductId'] as String,
        verificationPayload: json['verificationPayload'] as String,
        beneficiaryStudentId: json['beneficiaryStudentId'] as String?,
      );

  final String platform;
  final String environment;
  final String productFeatureKey;
  final String storeProductId;
  final String verificationPayload;
  final String? beneficiaryStudentId;

  Map<String, Object?> toJson() => {
    'platform': platform,
    'environment': environment,
    'productFeatureKey': productFeatureKey,
    'storeProductId': storeProductId,
    'verificationPayload': verificationPayload,
    'beneficiaryStudentId': ?beneficiaryStudentId,
  };
}

class V1RestorePurchaseResponseDto {
  const V1RestorePurchaseResponseDto({
    required this.restored,
    this.featureKey,
    this.derivation,
  });

  factory V1RestorePurchaseResponseDto.fromJson(Map<String, dynamic> json) =>
      V1RestorePurchaseResponseDto(
        restored: json['restored'] as bool,
        featureKey: json['featureKey'] as String?,
        derivation: json['derivation'] as String?,
      );

  final bool restored;
  final String? featureKey;
  final String? derivation;

  Map<String, Object?> toJson() => {
    'restored': restored,
    'featureKey': ?featureKey,
    'derivation': ?derivation,
  };
}

class V1ReviewGradeRequestDto {
  const V1ReviewGradeRequestDto({
    required this.expectedVersion,
    required this.score,
    required this.feedback,
  });

  factory V1ReviewGradeRequestDto.fromJson(Map<String, dynamic> json) =>
      V1ReviewGradeRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        score: json['score'] as num,
        feedback: json['feedback'] as String?,
      );

  final int expectedVersion;
  final num score;
  final String? feedback;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'score': score,
    'feedback': feedback,
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

class V1RevokeClassJoinLinkRequestDto {
  const V1RevokeClassJoinLinkRequestDto();

  factory V1RevokeClassJoinLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1RevokeClassJoinLinkRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1RevokeGuardianLinkRequestDto {
  const V1RevokeGuardianLinkRequestDto();

  factory V1RevokeGuardianLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1RevokeGuardianLinkRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1RevokeInvitationRequestDto {
  const V1RevokeInvitationRequestDto();

  factory V1RevokeInvitationRequestDto.fromJson(Map<String, dynamic> json) =>
      const V1RevokeInvitationRequestDto();

  Map<String, Object?> toJson() => const <String, Object?>{};
}

class V1RevokeModerationAccessRequestDto {
  const V1RevokeModerationAccessRequestDto({
    required this.expectedVersion,
    this.reason,
  });

  factory V1RevokeModerationAccessRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1RevokeModerationAccessRequestDto(
    expectedVersion: json['expectedVersion'] as int,
    reason: json['reason'] as String?,
  );

  final int expectedVersion;
  final String? reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': ?reason,
  };
}

class V1RevokeSupportAccessRequestDto {
  const V1RevokeSupportAccessRequestDto({
    required this.expectedVersion,
    this.reason,
  });

  factory V1RevokeSupportAccessRequestDto.fromJson(Map<String, dynamic> json) =>
      V1RevokeSupportAccessRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        reason: json['reason'] as String?,
      );

  final int expectedVersion;
  final String? reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': ?reason,
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

class V1SchoolAdminDto {
  const V1SchoolAdminDto({
    required this.id,
    required this.name,
    required this.timezone,
    required this.locale,
    required this.status,
    required this.version,
  });

  factory V1SchoolAdminDto.fromJson(Map<String, dynamic> json) =>
      V1SchoolAdminDto(
        id: json['id'] as String,
        name: json['name'] as String,
        timezone: json['timezone'] as String,
        locale: json['locale'] as String,
        status: json['status'] as String,
        version: json['version'] as int,
      );

  final String id;
  final String name;
  final String timezone;
  final String locale;
  final String status;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'timezone': timezone,
    'locale': locale,
    'status': status,
    'version': version,
  };
}

class V1SchoolIdQueryDto {
  const V1SchoolIdQueryDto({required this.schoolId});

  factory V1SchoolIdQueryDto.fromJson(Map<String, dynamic> json) =>
      V1SchoolIdQueryDto(schoolId: json['schoolId'] as String);

  final String schoolId;

  Map<String, Object?> toJson() => {'schoolId': schoolId};
}

class V1SchoolLifecycleRequestDto {
  const V1SchoolLifecycleRequestDto({
    required this.expectedVersion,
    this.reason,
  });

  factory V1SchoolLifecycleRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SchoolLifecycleRequestDto(
        expectedVersion: json['expectedVersion'] as int,
        reason: json['reason'] as String?,
      );

  final int expectedVersion;
  final String? reason;

  Map<String, Object?> toJson() => {
    'expectedVersion': expectedVersion,
    'reason': ?reason,
  };
}

class V1SchoolScopeQueryDto {
  const V1SchoolScopeQueryDto({
    this.schoolId,
    this.cursor,
    required this.pageSize,
  });

  factory V1SchoolScopeQueryDto.fromJson(Map<String, dynamic> json) =>
      V1SchoolScopeQueryDto(
        schoolId: json['schoolId'] as String?,
        cursor: json['cursor'] as String?,
        pageSize: json['pageSize'] as int,
      );

  final String? schoolId;
  final String? cursor;
  final int pageSize;

  Map<String, Object?> toJson() => {
    'schoolId': ?schoolId,
    'cursor': ?cursor,
    'pageSize': pageSize,
  };
}

class V1SchoolStudentDto {
  const V1SchoolStudentDto({
    required this.id,
    required this.schoolId,
    required this.userId,
    required this.studafyId,
    required this.displayName,
    required this.provisional,
  });

  factory V1SchoolStudentDto.fromJson(Map<String, dynamic> json) =>
      V1SchoolStudentDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        userId: json['userId'] as String?,
        studafyId: json['studafyId'] as String,
        displayName: json['displayName'] as String,
        provisional: json['provisional'] as bool,
      );

  final String id;
  final String schoolId;
  final String? userId;
  final String studafyId;
  final String displayName;
  final bool provisional;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'userId': userId,
    'studafyId': studafyId,
    'displayName': displayName,
    'provisional': provisional,
  };
}

class V1SendMessageRequestDto {
  const V1SendMessageRequestDto({
    required this.clientMessageId,
    required this.body,
  });

  factory V1SendMessageRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SendMessageRequestDto(
        clientMessageId: json['clientMessageId'] as String,
        body: json['body'] as String,
      );

  final String clientMessageId;
  final String body;

  Map<String, Object?> toJson() => {
    'clientMessageId': clientMessageId,
    'body': body,
  };
}

class V1SetSelfPurchaseRequestDto {
  const V1SetSelfPurchaseRequestDto({
    required this.schoolId,
    required this.enabled,
  });

  factory V1SetSelfPurchaseRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SetSelfPurchaseRequestDto(
        schoolId: json['schoolId'] as String,
        enabled: json['enabled'] as bool,
      );

  final String schoolId;
  final bool enabled;

  Map<String, Object?> toJson() => {'schoolId': schoolId, 'enabled': enabled};
}

class V1SetSelfPurchaseResponseDto {
  const V1SetSelfPurchaseResponseDto({
    required this.schoolId,
    required this.selfPurchaseEnabled,
  });

  factory V1SetSelfPurchaseResponseDto.fromJson(Map<String, dynamic> json) =>
      V1SetSelfPurchaseResponseDto(
        schoolId: json['schoolId'] as String,
        selfPurchaseEnabled: json['selfPurchaseEnabled'] as bool,
      );

  final String schoolId;
  final bool selfPurchaseEnabled;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'selfPurchaseEnabled': selfPurchaseEnabled,
  };
}

class V1StudentFamilyDto {
  const V1StudentFamilyDto({required this.studentIds, required this.requests});

  factory V1StudentFamilyDto.fromJson(Map<String, dynamic> json) =>
      V1StudentFamilyDto(
        studentIds: (json['studentIds'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
        requests: (json['requests'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );

  final List<Map<String, dynamic>> studentIds;
  final List<Map<String, dynamic>> requests;

  Map<String, Object?> toJson() => {
    'studentIds': studentIds,
    'requests': requests,
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

class V1SubmitPurchaseRequestDto {
  const V1SubmitPurchaseRequestDto({
    required this.platform,
    required this.environment,
    required this.productFeatureKey,
    required this.storeProductId,
    required this.verificationPayload,
    this.beneficiaryStudentId,
  });

  factory V1SubmitPurchaseRequestDto.fromJson(Map<String, dynamic> json) =>
      V1SubmitPurchaseRequestDto(
        platform: json['platform'] as String,
        environment: json['environment'] as String,
        productFeatureKey: json['productFeatureKey'] as String,
        storeProductId: json['storeProductId'] as String,
        verificationPayload: json['verificationPayload'] as String,
        beneficiaryStudentId: json['beneficiaryStudentId'] as String?,
      );

  final String platform;
  final String environment;
  final String productFeatureKey;
  final String storeProductId;
  final String verificationPayload;
  final String? beneficiaryStudentId;

  Map<String, Object?> toJson() => {
    'platform': platform,
    'environment': environment,
    'productFeatureKey': productFeatureKey,
    'storeProductId': storeProductId,
    'verificationPayload': verificationPayload,
    'beneficiaryStudentId': ?beneficiaryStudentId,
  };
}

class V1SubmitPurchaseResponseDto {
  const V1SubmitPurchaseResponseDto({
    required this.featureKey,
    required this.derivation,
  });

  factory V1SubmitPurchaseResponseDto.fromJson(Map<String, dynamic> json) =>
      V1SubmitPurchaseResponseDto(
        featureKey: json['featureKey'] as String,
        derivation: json['derivation'] as String,
      );

  final String featureKey;
  final String derivation;

  Map<String, Object?> toJson() => {
    'featureKey': featureKey,
    'derivation': derivation,
  };
}

class V1SupportAccessGrantDto {
  const V1SupportAccessGrantDto({
    required this.id,
    required this.schoolId,
    required this.requestedBy,
    required this.approvedBy,
    required this.reason,
    required this.ticketRef,
    required this.resourceScope,
    required this.status,
    required this.requiresSecondApprover,
    required this.expiresAt,
    required this.startedAt,
    required this.endedAt,
    required this.version,
  });

  factory V1SupportAccessGrantDto.fromJson(Map<String, dynamic> json) =>
      V1SupportAccessGrantDto(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String,
        requestedBy: json['requestedBy'] as String,
        approvedBy: json['approvedBy'] as String?,
        reason: json['reason'] as String,
        ticketRef: json['ticketRef'] as String,
        resourceScope: json['resourceScope'] as Map<String, dynamic>,
        status: json['status'] as String,
        requiresSecondApprover: json['requiresSecondApprover'] as bool,
        expiresAt: json['expiresAt'] as String,
        startedAt: json['startedAt'] as String?,
        endedAt: json['endedAt'] as String?,
        version: json['version'] as int,
      );

  final String id;
  final String schoolId;
  final String requestedBy;
  final String? approvedBy;
  final String reason;
  final String ticketRef;
  final Map<String, dynamic> resourceScope;
  final String status;
  final bool requiresSecondApprover;
  final String expiresAt;
  final String? startedAt;
  final String? endedAt;
  final int version;

  Map<String, Object?> toJson() => {
    'id': id,
    'schoolId': schoolId,
    'requestedBy': requestedBy,
    'approvedBy': approvedBy,
    'reason': reason,
    'ticketRef': ticketRef,
    'resourceScope': resourceScope,
    'status': status,
    'requiresSecondApprover': requiresSecondApprover,
    'expiresAt': expiresAt,
    'startedAt': startedAt,
    'endedAt': endedAt,
    'version': version,
  };
}

class V1SupportAccessGrantPageDto {
  const V1SupportAccessGrantPageDto({
    required this.items,
    required this.nextCursor,
  });

  factory V1SupportAccessGrantPageDto.fromJson(Map<String, dynamic> json) =>
      V1SupportAccessGrantPageDto(
        items: [
          for (final item in json['items'] as List<dynamic>)
            V1SupportAccessGrantDto.fromJson(item as Map<String, dynamic>),
        ],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<V1SupportAccessGrantDto> items;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
    'nextCursor': nextCursor,
  };
}

class V1SupportAccessLifecycleRequestDto {
  const V1SupportAccessLifecycleRequestDto({required this.expectedVersion});

  factory V1SupportAccessLifecycleRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1SupportAccessLifecycleRequestDto(
    expectedVersion: json['expectedVersion'] as int,
  );

  final int expectedVersion;

  Map<String, Object?> toJson() => {'expectedVersion': expectedVersion};
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

class V1TransferEnrollmentRequestDto {
  const V1TransferEnrollmentRequestDto({
    required this.studentId,
    required this.targetClassroomId,
  });

  factory V1TransferEnrollmentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1TransferEnrollmentRequestDto(
        studentId: json['studentId'] as String,
        targetClassroomId: json['targetClassroomId'] as String,
      );

  final String studentId;
  final String targetClassroomId;

  Map<String, Object?> toJson() => {
    'studentId': studentId,
    'targetClassroomId': targetClassroomId,
  };
}

class V1UnblockUserRequestDto {
  const V1UnblockUserRequestDto({this.reason});

  factory V1UnblockUserRequestDto.fromJson(Map<String, dynamic> json) =>
      V1UnblockUserRequestDto(reason: json['reason'] as String?);

  final String? reason;

  Map<String, Object?> toJson() => {'reason': ?reason};
}

class V1UnreadCountResponseDto {
  const V1UnreadCountResponseDto({required this.unreadCount});

  factory V1UnreadCountResponseDto.fromJson(Map<String, dynamic> json) =>
      V1UnreadCountResponseDto(unreadCount: json['unreadCount'] as int);

  final int unreadCount;

  Map<String, Object?> toJson() => {'unreadCount': unreadCount};
}

class V1UnregisterPushDeviceRequestDto {
  const V1UnregisterPushDeviceRequestDto({required this.token});

  factory V1UnregisterPushDeviceRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1UnregisterPushDeviceRequestDto(token: json['token'] as String);

  final String token;

  Map<String, Object?> toJson() => {'token': token};
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

class V1UpdateContentControlsRequestDto {
  const V1UpdateContentControlsRequestDto({
    required this.schoolId,
    required this.expectedVersion,
    this.messagingEnabled,
    this.contentFilterLevel,
    this.classifierAssistEnabled,
    this.supportContact,
    this.slaHours,
  });

  factory V1UpdateContentControlsRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1UpdateContentControlsRequestDto(
    schoolId: json['schoolId'] as String,
    expectedVersion: json['expectedVersion'] as int,
    messagingEnabled: json['messagingEnabled'] as bool?,
    contentFilterLevel: json['contentFilterLevel'] as String?,
    classifierAssistEnabled: json['classifierAssistEnabled'] as bool?,
    supportContact: json['supportContact'] as String?,
    slaHours: json['slaHours'] as Map<String, dynamic>?,
  );

  final String schoolId;
  final int expectedVersion;
  final bool? messagingEnabled;
  final String? contentFilterLevel;
  final bool? classifierAssistEnabled;
  final String? supportContact;
  final Map<String, dynamic>? slaHours;

  Map<String, Object?> toJson() => {
    'schoolId': schoolId,
    'expectedVersion': expectedVersion,
    'messagingEnabled': ?messagingEnabled,
    'contentFilterLevel': ?contentFilterLevel,
    'classifierAssistEnabled': ?classifierAssistEnabled,
    'supportContact': ?supportContact,
    'slaHours': ?slaHours,
  };
}

class V1UpdateNotificationPreferenceRequestDto {
  const V1UpdateNotificationPreferenceRequestDto({
    this.schoolId,
    required this.channel,
    required this.category,
    required this.enabled,
  });

  factory V1UpdateNotificationPreferenceRequestDto.fromJson(
    Map<String, dynamic> json,
  ) => V1UpdateNotificationPreferenceRequestDto(
    schoolId: json['schoolId'] as String?,
    channel: json['channel'] as String,
    category: json['category'] as String,
    enabled: json['enabled'] as bool,
  );

  final String? schoolId;
  final String channel;
  final String category;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'schoolId': ?schoolId,
    'channel': channel,
    'category': category,
    'enabled': enabled,
  };
}

class V1UpdateProfileRequestDto {
  const V1UpdateProfileRequestDto({this.displayName, this.locale});

  factory V1UpdateProfileRequestDto.fromJson(Map<String, dynamic> json) =>
      V1UpdateProfileRequestDto(
        displayName: json['displayName'] as String?,
        locale: json['locale'] as String?,
      );

  final String? displayName;
  final String? locale;

  Map<String, Object?> toJson() => {
    'displayName': ?displayName,
    'locale': ?locale,
  };
}

class V1UploadSessionDto {
  const V1UploadSessionDto({
    required this.id,
    required this.purpose,
    required this.displayName,
    required this.declaredMediaType,
    required this.expectedSizeBytes,
    required this.state,
    required this.expiresAt,
    required this.createdAt,
    required this.completedAt,
    required this.fileId,
    required this.failureCode,
  });

  factory V1UploadSessionDto.fromJson(Map<String, dynamic> json) =>
      V1UploadSessionDto(
        id: json['id'] as String,
        purpose: json['purpose'] as String,
        displayName: json['displayName'] as String,
        declaredMediaType: json['declaredMediaType'] as String,
        expectedSizeBytes: json['expectedSizeBytes'] as int,
        state: json['state'] as String,
        expiresAt: json['expiresAt'] as String,
        createdAt: json['createdAt'] as String,
        completedAt: json['completedAt'] as String?,
        fileId: json['fileId'] as String?,
        failureCode: json['failureCode'] as String?,
      );

  final String id;
  final String purpose;
  final String displayName;
  final String declaredMediaType;
  final int expectedSizeBytes;
  final String state;
  final String expiresAt;
  final String createdAt;
  final String? completedAt;
  final String? fileId;
  final String? failureCode;

  Map<String, Object?> toJson() => {
    'id': id,
    'purpose': purpose,
    'displayName': displayName,
    'declaredMediaType': declaredMediaType,
    'expectedSizeBytes': expectedSizeBytes,
    'state': state,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
    'completedAt': completedAt,
    'fileId': fileId,
    'failureCode': failureCode,
  };
}

class V1VerifyGuardianLinkRequestDto {
  const V1VerifyGuardianLinkRequestDto({this.expiresInDays});

  factory V1VerifyGuardianLinkRequestDto.fromJson(Map<String, dynamic> json) =>
      V1VerifyGuardianLinkRequestDto(
        expiresInDays: json['expiresInDays'] as int?,
      );

  final int? expiresInDays;

  Map<String, Object?> toJson() => {'expiresInDays': ?expiresInDays};
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

class V1WithdrawStudentRequestDto {
  const V1WithdrawStudentRequestDto({required this.studentId});

  factory V1WithdrawStudentRequestDto.fromJson(Map<String, dynamic> json) =>
      V1WithdrawStudentRequestDto(studentId: json['studentId'] as String);

  final String studentId;

  Map<String, Object?> toJson() => {'studentId': studentId};
}
