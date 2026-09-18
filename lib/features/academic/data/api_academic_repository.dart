import '../../../core/failures.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../domain/academic_repository.dart';

class ApiAcademicRepository implements AcademicRepository {
  ApiAcademicRepository(this._client, {ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance;

  final V1ApiClient _client;
  final ActiveContextController _context;
  final Map<String, String> _pendingKeys = {};

  String get _schoolId {
    final value = _context.membership;
    if (value == null || !value.active) throw Failure.unauthorized;
    return value.schoolId;
  }

  String _key(String fingerprint) => _pendingKeys.putIfAbsent(
    fingerprint,
    () =>
        'academic-${DateTime.now().microsecondsSinceEpoch}-${fingerprint.hashCode.abs()}',
  );

  Future<void> _done(
    String fingerprint,
    Future<void> Function(String key) command,
  ) async {
    await command(_key(fingerprint));
    _pendingKeys.remove(fingerprint);
  }

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    switch (feed) {
      case AcademicFeed.content:
        final page = await _client.listResources(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.title,
              detail: x.body ?? '',
              state: x.state,
              version: x.version,
            ),
        ];
      case AcademicFeed.assignments:
        final page = await _client.listAssignments(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.title,
              detail: x.instructions ?? '',
              state: x.state,
              version: x.version,
            ),
        ];
      case AcademicFeed.assessments:
        final page = await _client.listAssessments(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.title,
              detail: '${x.maximumScore} points',
              state: x.state,
              version: x.version,
            ),
        ];
      case AcademicFeed.grades:
        final page = await _client.listGradeResults(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: 'Grade',
              detail: x.score == null
                  ? 'Awaiting review'
                  : '${x.score}/${x.maximumScore}',
              state: x.state,
              version: x.version,
            ),
        ];
      case AcademicFeed.attendance:
        final page = await _client.listAttendance(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.state,
              detail: x.reason ?? '',
              state: x.state,
              version: 1,
            ),
        ];
      case AcademicFeed.wellbeing:
        final page = await _client.listWellbeing(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.title,
              detail: x.context ?? '',
              state: x.kind,
              version: 1,
            ),
        ];
    }
  }

  @override
  Future<void> createResource(TextResourceDraft draft) => _done(
    'resource:${draft.classroomId}:${draft.title}:${draft.body}',
    (key) async {
      await _client.createResource(
        V1CreateResourceRequestDto(
          schoolId: _schoolId,
          classroomId: draft.classroomId,
          title: draft.title,
          resourceType: 'lesson_note',
          body: draft.body,
          audience: 'both',
        ),
        idempotencyKey: key,
      );
    },
  );

  @override
  Future<void> reviseResource(
    String resourceId,
    int expectedVersion,
    String title,
    String body,
  ) => _done('resource-revise:$resourceId:$expectedVersion:$title:$body', (
    key,
  ) async {
    await _client.reviseResource(
      V1ReviseResourceRequestDto(
        expectedVersion: expectedVersion,
        title: title,
        body: body,
      ),
      resourceId: resourceId,
      idempotencyKey: key,
    );
  });

  @override
  Future<void> publishResource(String resourceId, int expectedVersion) =>
      _versionCommand(
        'resource-publish',
        resourceId,
        expectedVersion,
        (request, key) => _client.publishResource(
          request,
          resourceId: resourceId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> withdrawResource(String resourceId, int expectedVersion) =>
      _versionCommand(
        'resource-withdraw',
        resourceId,
        expectedVersion,
        (request, key) => _client.withdrawResource(
          request,
          resourceId: resourceId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> createAssignment(AssignmentDraft draft) => _done(
    'assignment:${draft.classroomId}:${draft.title}:${draft.dueAt.toUtc().toIso8601String()}',
    (key) async {
      await _client.createAssignment(
        V1CreateAssignmentRequestDto(
          classroomId: draft.classroomId,
          title: draft.title,
          instructions: draft.instructions,
          dueAt: draft.dueAt.toUtc().toIso8601String(),
          closesAt: draft.closesAt?.toUtc().toIso8601String(),
        ),
        idempotencyKey: key,
      );
    },
  );

  @override
  Future<void> publishAssignment(String assignmentId, int expectedVersion) =>
      _versionCommand(
        'assignment-publish',
        assignmentId,
        expectedVersion,
        (request, key) => _client.publishAssignment(
          request,
          assignmentId: assignmentId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> withdrawAssignment(String assignmentId, int expectedVersion) =>
      _versionCommand(
        'assignment-withdraw',
        assignmentId,
        expectedVersion,
        (request, key) => _client.withdrawAssignment(
          request,
          assignmentId: assignmentId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> createAssessment(AssessmentDraft draft) =>
      _done('assessment:${draft.classroomId}:${draft.title}', (key) async {
        await _client.createAssessment(
          V1CreateAssessmentRequestDto(
            classroomId: draft.classroomId,
            title: draft.title,
            category: 'assessment',
            maximumScore: draft.maximumScore,
            scheduledAt: null,
            delivery: 'online',
            questions: [
              for (var i = 0; i < draft.questions.length; i++)
                V1AssessmentQuestionDraftDto(
                  position: i + 1,
                  prompt: draft.questions[i].prompt,
                  preferredAnswer: draft.questions[i].preferredAnswer,
                  maximumScore: draft.questions[i].maximumScore,
                ),
            ],
          ),
          idempotencyKey: key,
        );
      });

  @override
  Future<void> publishAssessment(String assessmentId, int expectedVersion) =>
      _versionCommand(
        'assessment-publish',
        assessmentId,
        expectedVersion,
        (request, key) => _client.publishAssessment(
          request,
          assessmentId: assessmentId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> withdrawAssessment(String assessmentId, int expectedVersion) =>
      _versionCommand(
        'assessment-withdraw',
        assessmentId,
        expectedVersion,
        (request, key) => _client.withdrawAssessment(
          request,
          assessmentId: assessmentId,
          idempotencyKey: key,
        ),
      );

  @override
  Future<void> submitAssignment(String assignmentId, String answer) =>
      _done('assignment-submit:$assignmentId:$answer', (key) async {
        await _client.submitAssignment(
          V1SubmitAssignmentRequestDto(answerText: answer),
          assignmentId: assignmentId,
          idempotencyKey: key,
        );
      });

  @override
  Future<void> submitAssessment(
    String assessmentId,
    Map<String, String> answers,
  ) => _done(
    'assessment-submit:$assessmentId:${answers.entries.map((e) => '${e.key}:${e.value}').join('|')}',
    (key) async {
      await _client.submitAssessment(
        V1SubmitAssessmentRequestDto(
          answers: [
            for (final entry in answers.entries)
              V1AssessmentAnswerDto(
                questionId: entry.key,
                answerText: entry.value,
              ),
          ],
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
    },
  );

  @override
  Future<void> recordAttendance(
    String classroomId,
    DateTime startsAt,
    DateTime endsAt,
    int expectedVersion,
    List<AttendanceDraft> entries,
  ) => _done(
    'attendance:$classroomId:${startsAt.toUtc().toIso8601String()}:$expectedVersion',
    (key) async {
      await _client.recordAttendance(
        V1RecordAttendanceRequestDto(
          classroomId: classroomId,
          startsAt: startsAt.toUtc().toIso8601String(),
          endsAt: endsAt.toUtc().toIso8601String(),
          expectedVersion: expectedVersion,
          entries: [
            for (final x in entries)
              V1AttendanceEntryDto(
                studentId: x.studentId,
                state: x.state,
                reason: x.reason,
              ),
          ],
        ),
        idempotencyKey: key,
      );
    },
  );

  @override
  Future<void> reviewGrade(
    String gradeId,
    int expectedVersion,
    double score, {
    String? feedback,
  }) => _done('grade-review:$gradeId:$expectedVersion:$score', (key) async {
    await _client.reviewGradeResult(
      V1ReviewGradeRequestDto(
        expectedVersion: expectedVersion,
        score: score,
        feedback: feedback,
      ),
      gradeResultId: gradeId,
      idempotencyKey: key,
    );
  });

  @override
  Future<void> publishGrade(String gradeId, int expectedVersion) =>
      _done('grade-publish:$gradeId:$expectedVersion', (key) async {
        await _client.publishGradeResult(
          V1VersionCommandRequestDto(expectedVersion: expectedVersion),
          gradeResultId: gradeId,
          idempotencyKey: key,
        );
      });

  @override
  Future<void> correctGrade(
    String gradeId,
    int expectedVersion,
    double score,
    String reason, {
    String? feedback,
  }) => _done('grade-correct:$gradeId:$expectedVersion:$score:$reason', (
    key,
  ) async {
    await _client.correctGradeResult(
      V1CorrectGradeRequestDto(
        expectedVersion: expectedVersion,
        score: score,
        feedback: feedback,
        reason: reason,
      ),
      gradeResultId: gradeId,
      idempotencyKey: key,
    );
  });

  @override
  Future<void> withdrawGrade(String gradeId, int expectedVersion) =>
      _done('grade-withdraw:$gradeId:$expectedVersion', (key) async {
        await _client.withdrawGradeResult(
          V1VersionCommandRequestDto(expectedVersion: expectedVersion),
          gradeResultId: gradeId,
          idempotencyKey: key,
        );
      });

  @override
  Future<void> createWellbeing(WellbeingDraft draft) => _done(
    'wellbeing:${draft.classroomId}:${draft.studentId}:${draft.kind}:${draft.title}',
    (key) async {
      await _client.createWellbeing(
        V1CreateWellbeingRequestDto(
          studentId: draft.studentId,
          classroomId: draft.classroomId,
          kind: draft.kind,
          title: draft.title,
          context: draft.context,
          followUp: null,
          visibility: 'class_staff',
          severity: 'low',
        ),
        idempotencyKey: key,
      );
    },
  );

  Future<void> _versionCommand(
    String operation,
    String resourceId,
    int expectedVersion,
    Future<Object> Function(V1VersionCommandRequestDto request, String key)
    command,
  ) => _done('$operation:$resourceId:$expectedVersion', (key) async {
    await command(
      V1VersionCommandRequestDto(expectedVersion: expectedVersion),
      key,
    );
  });
}
