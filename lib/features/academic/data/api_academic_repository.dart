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
              // The work's own name. Every row read "Grade" before, so a
              // student with several exams could not tell them apart.
              id: x.id,
              title: x.assessmentTitle,
              detail: x.score == null
                  ? 'Not marked yet'
                  : '${_trimmed(x.score!)} / ${_trimmed(x.maximumScore)}',
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
          lessonSessionId: draft.lessonSessionId,
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
            category: draft.category,
            maximumScore: draft.maximumScore,
            scheduledAt: draft.scheduledAt?.toUtc().toIso8601String(),
            delivery: draft.delivery,
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
  Future<List<ClassSessionSlot>> classroomSchedule(String classroomId) async {
    final detail = await _client.getClassroom(classroomId: classroomId);
    return [
      for (final slot in detail.schedule)
        ClassSessionSlot(
          weekday: slot.weekday,
          startsAt: slot.startsAt,
          endsAt: slot.endsAt,
        ),
    ];
  }

  @override
  Future<List<SubmittedWork>> submissionsFor(String assignmentId) async {
    final items = <SubmittedWork>[];
    String? cursor;
    do {
      final page = await _client.listAssignmentSubmissions(
        assignmentId: assignmentId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final item in page.items) {
        items.add(
          SubmittedWork(
            id: item.id,
            assignmentId: item.assignmentId,
            studentId: item.studentId,
            status: item.status,
            answerText: item.answerText,
            submittedAt: item.submittedAt == null
                ? null
                : DateTime.tryParse(item.submittedAt!)?.toLocal(),
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return items;
  }

  @override
  Future<void> replaceSchedule(
    String classroomId,
    int expectedVersion,
    List<ClassSessionSlot> slots,
  ) => _done('schedule:$classroomId:$expectedVersion', (key) async {
    final today = DateTime.now();
    final effectiveFrom =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    await _client.replaceClassroomSchedule(
      V1ReplaceScheduleRequestDto(
        expectedVersion: expectedVersion,
        schedule: [
          for (final slot in slots)
            V1ScheduleSlotInputDto(
              weekday: slot.weekday,
              startsAt: slot.startsAt,
              endsAt: slot.endsAt,
              effectiveFrom: effectiveFrom,
              effectiveUntil: null,
            ),
        ],
      ),
      classroomId: classroomId,
      idempotencyKey: key,
    );
  });

  @override
  Future<List<LessonSession>> lessonSessions(String classroomId) async {
    final sessions = <LessonSession>[];
    String? cursor;
    do {
      final page = await _client.listLessonSessions(
        classroomId: classroomId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final item in page.items) {
        final startsAt = DateTime.tryParse(item.startsAt)?.toLocal();
        final endsAt = DateTime.tryParse(item.endsAt)?.toLocal();
        if (startsAt == null || endsAt == null) continue;
        sessions.add(
          LessonSession(
            id: item.id,
            startsAt: startsAt,
            endsAt: endsAt,
            filed: item.filedAt != null,
            title: item.title,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    sessions.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return sessions;
  }

  @override
  Future<void> closeLessonSession(String lessonSessionId) =>
      _done('close-session:$lessonSessionId', (key) async {
        await _client.closeLessonSession(
          const V1CloseLessonSessionRequestDto(),
          lessonSessionId: lessonSessionId,
          idempotencyKey: key,
        );
      });

  @override
  Future<List<GradeEntry>> gradeEntries(String classroomId) async {
    final entries = <GradeEntry>[];
    String? cursor;
    do {
      final page = await _client.listGradeResults(
        schoolId: _schoolId,
        classroomId: classroomId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final item in page.items) {
        entries.add(
          GradeEntry(
            id: item.id,
            assessmentId: item.assessmentId,
            studentId: item.studentId,
            maximumScore: item.maximumScore.toDouble(),
            state: item.state,
            version: item.version,
            score: item.score?.toDouble(),
            feedback: item.feedback,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return entries;
  }

  @override
  Future<List<ClassStudent>> classStudents(String classroomId) async {
    final students = <ClassStudent>[];
    String? cursor;
    do {
      final page = await _client.listClassroomStudents(
        classroomId: classroomId,
        cursor: cursor,
        pageSize: 100,
      );
      for (final item in page.items) {
        students.add(
          ClassStudent(
            id: item.id,
            displayName: item.displayName,
            studafyId: item.studafyId,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);

    // Contacts are school-wide, so they are fetched once and indexed by the
    // children each guardian is linked to. Matching on id, never on display
    // name: a class can hold two children called the same thing.
    final byStudent = <String, List<StudentGuardian>>{};
    String? contactCursor;
    do {
      final page = await _client.listContacts(
        cursor: contactCursor,
        pageSize: 100,
      );
      for (final contact in page.items) {
        for (final studentId in contact.relatedStudentIds) {
          byStudent
              .putIfAbsent(studentId, () => <StudentGuardian>[])
              .add(
                StudentGuardian(
                  userId: contact.userId,
                  displayName: contact.displayName,
                ),
              );
        }
      }
      contactCursor = page.nextCursor;
    } while (contactCursor != null);

    return [
      for (final student in students)
        ClassStudent(
          id: student.id,
          displayName: student.displayName,
          studafyId: student.studafyId,
          guardians: byStudent[student.id] ?? const [],
        ),
    ];
  }

  @override
  Future<AttendanceRegister> attendanceRoster(
    String classroomId,
    DateTime date, {
    DateTime? startsAt,
  }) async {
    final entries = <AttendanceRosterEntry>[];
    String? cursor;
    int version = 0;
    do {
      final page = await _client.listAttendanceRoster(
        classroomId: classroomId,
        date: _isoDate(date),
        startsAt: startsAt?.toUtc().toIso8601String(),
        cursor: cursor,
        pageSize: 100,
      );
      // Absent until this lesson has been recorded once; zero is then the
      // value recordAttendance requires for creating the session.
      version = page.session?.version ?? 0;
      for (final item in page.items) {
        entries.add(
          AttendanceRosterEntry(
            studentId: item.student.id,
            displayName: item.student.displayName,
            state: _stateFrom(item.record?.state),
            reason: item.record?.reason,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return AttendanceRegister(entries: entries, version: version);
  }

  /// Scores are numeric; 18 should read as 18 rather than 18.0.
  static String _trimmed(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static AttendanceState? _stateFrom(String? value) => switch (value) {
    'present' => AttendanceState.present,
    'absent' => AttendanceState.absent,
    'late' => AttendanceState.late,
    'excused' => AttendanceState.excused,
    _ => null,
  };

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
