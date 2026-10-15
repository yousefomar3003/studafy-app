import '../../../core/failures.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/academic_repository.dart';
import 'api_online_assessments.dart';

class ApiAcademicRepository implements AcademicRepository {
  /// [context] is the signed-in person's active school and child; it is
  /// passed in so the repository never reaches for a global.
  ApiAcademicRepository(this._client, {required this._context});

  final V1ApiClient _client;
  final ActiveContextController _context;
  final _keys = PendingIdempotencyKeys();

  /// Online assessments and coursework attachments (ADR-0036).
  late final _online = ApiOnlineAssessments(_client, _keys, _refusing);

  String get _schoolId {
    final value = _context.membership;
    if (value != null && value.active) return value.schoolId;
    // A guardian holds no membership; their school is the child's they are
    // looking at. The server authorizes each read on the guardian link.
    final child = _context.selectedStudent?.schoolId;
    if (value == null && child != null) return child;
    throw Failure.unauthorized;
  }

  /// Runs a command under one key until it succeeds, so a retry replays it.
  Future<void> _done(
    String fingerprint,
    Future<void> Function(String key) command,
  ) => _keys.run('academic', fingerprint, command);

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
              date: _when(x.publishedAt),
              classroomId: x.classroomId,
              // The lesson's files, which students and families download
              // from the lesson itself, and its links.
              attachments: _attachments(x.attachments),
              links: contentLinksFrom(x.links),
              resourceType: x.resourceType,
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
              classroomId: x.classroomId,
              attachments: _attachments(x.attachments),
              maximumScore: x.maximumScore?.toDouble(),
              date: _when(x.publishedAt),
              deadline: _deadline(x),
              timeZone: x.timeZone,
              links: contentLinksFrom(x.links),
              dueAt: _when(x.dueAt),
              closesAt: _when(x.closesAt),
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
          // Every assessment, including the marks for graded assignments:
          // the gradebook enters marks on those. The Assessments screen
          // leaves them out, since they are listed with their assignment.
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.title,
              detail: '${x.maximumScore} points',
              state: x.state,
              version: x.version,
              classroomId: x.classroomId,
              attachments: _attachments(x.attachments),
              markedAssignmentId: x.assignmentId,
              delivery: x.delivery,
              date: _when(x.publishedAt),
              links: contentLinksFrom(x.links),
              online: x.delivery == 'paper' ? null : onlineAssessmentFrom(x),
              scheduledAt: _when(x.scheduledAt),
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
              // The screen words the mark: "Absent" and "not marked yet"
              // are the reader's language, not this layer's.
              detail: '',
              state: x.state,
              version: x.version,
              delivery: x.delivery,
              mark:
                  GradeMark.fromWire(x.mark) ??
                  (x.score == null ? null : GradeMark.scored),
              score: x.score?.toDouble(),
              outOf: x.maximumScore.toDouble(),
              date: _when(x.publishedAt),
              assessmentId: x.assessmentId,
              feedback: x.feedback,
              attachments: _attachments(x.attachments),
              links: contentLinksFrom(x.links),
              sharedAttachments: _attachments(x.sharedAttachments),
              sharedLinks: contentLinksFrom(x.sharedLinks),
            ),
        ];
      case AcademicFeed.attendance:
        final page = await _client.listAttendance(
          schoolId: _schoolId,
          classroomId: classroomId,
          studentId: studentId,
          pageSize: 100,
        );
        // Newest lesson first: a mark is read by the day it was for.
        return [
          for (final x in page.items)
            AcademicRecord(
              id: x.id,
              title: x.state,
              detail: x.reason ?? '',
              state: x.state,
              version: 1,
              classroomId: x.classroomId,
              date: _when(x.startsAt),
            ),
        ]..sort(_newestFirst);
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
              classroomId: x.classroomId,
              date: _when(x.createdAt),
            ),
        ];
    }
  }

  /// A wire timestamp as local time; null when absent or unreadable.
  static DateTime? _when(String? at) =>
      at == null ? null : DateTime.tryParse(at)?.toLocal();

  /// Dated records before undated ones, the most recent first.
  static int _newestFirst(AcademicRecord a, AcademicRecord b) {
    final first = a.date;
    final second = b.date;
    if (first == null || second == null) {
      return first == null ? (second == null ? 0 : 1) : -1;
    }
    return second.compareTo(first);
  }

  @override
  Future<void> createResource(TextResourceDraft draft) => _refusing(
    () => _done('resource:${draft.classroomId}:${draft.title}:${draft.body}:'
        '${draft.audience}:${draft.attachmentFileIds.join(',')}:'
        '${draft.links.map((l) => l.url).join(',')}:'
        '${draft.lessonSessionId}', (key) async {
      final created = await _client.createResource(
        V1CreateResourceRequestDto(
          schoolId: _schoolId,
          classroomId: draft.classroomId,
          title: draft.title,
          resourceType: 'lesson_note',
          body: draft.body,
          audience: draft.audience,
          lessonSessionId: draft.lessonSessionId,
          attachmentFileIds: draft.attachmentFileIds.isEmpty
              ? null
              : draft.attachmentFileIds,
          links: draft.links.isEmpty ? null : linkDtos(draft.links),
        ),
        idempotencyKey: key,
      );
      // A lesson is created as a draft, which students and parents never
      // see. Inside the same retry scope, so a retry replays the create
      // and publishes that rather than filing a second copy.
      if (draft.publish && created.state == 'draft') {
        await publishResource(created.id, created.version);
      }
    }),
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
  Future<void> editResource(
    String resourceId,
    int expectedVersion, {
    String? title,
    String? body,
    String? replaceFileId,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) => _refusing(
    () => _done(
      'resource-edit:$resourceId:$expectedVersion:$title:$body:$replaceFileId:'
      '${attachments.attachFileIds.join(',')}:${attachments.detachFileIds.join(',')}:'
      '${attachments.addLinks.map((l) => l.url).join(',')}:'
      '${attachments.removeLinkIds.join(',')}',
      (key) async {
        await _client.editResource(
          V1EditResourceRequestDto(
            expectedVersion: expectedVersion,
            title: title,
            body: body,
            replaceFileId: replaceFileId,
            attachmentFileIds: attachments.attachFileIds.isEmpty
                ? null
                : attachments.attachFileIds,
            detachFileIds: attachments.detachFileIds.isEmpty
                ? null
                : attachments.detachFileIds,
            links: attachments.addLinks.isEmpty
                ? null
                : linkDtos(attachments.addLinks),
            removeLinkIds: attachments.removeLinkIds.isEmpty
                ? null
                : attachments.removeLinkIds,
          ),
          resourceId: resourceId,
          idempotencyKey: key,
        );
      },
    ),
  );

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
  Future<void> createAssignment(AssignmentDraft draft) => _refusing(
    () => _done(
      // The files are part of the work: retrying with a different set is a
      // different request, not a replay of the first.
      'assignment:${draft.classroomId}:${draft.title}:'
      '${draft.dueAt.toUtc().toIso8601String()}:'
      '${draft.attachmentFileIds.join(',')}:'
      '${draft.links.map((l) => l.url).join(',')}',
      (key) async {
        final created = await _client.createAssignment(
          V1CreateAssignmentRequestDto(
            classroomId: draft.classroomId,
            title: draft.title,
            instructions: draft.instructions,
            dueAt: draft.dueAt.toUtc().toIso8601String(),
            closesAt: draft.closesAt?.toUtc().toIso8601String(),
            // The time the teacher picked, as a wall-clock time: the server
            // reads it on the school's clock, whatever this device's zone.
            dueLocal: _wallClock(draft.dueAt),
            closesLocal: draft.closesAt == null
                ? null
                : _wallClock(draft.closesAt!),
            attachmentFileIds: draft.attachmentFileIds.isEmpty
                ? null
                : draft.attachmentFileIds,
            links: draft.links.isEmpty ? null : linkDtos(draft.links),
          ),
          idempotencyKey: key,
        );
        // Inside the same retry scope: if publishing fails, a retry replays
        // the create (same key, same response) and publishes that, rather
        // than creating a second copy.
        if (draft.publish && created.state == 'draft') {
          await publishAssignment(created.id, created.version);
        }
        // Graded: the mark lives on an assessment linked to this assignment,
        // which is what the gradebook reads. The student still hands in the
        // assignment itself.
        final score = draft.maximumScore;
        if (score != null) {
          await createAssessment(
            AssessmentDraft(
              classroomId: draft.classroomId,
              title: draft.title,
              maximumScore: score,
              questions: const [],
              category: 'assignment',
              delivery: 'paper',
              scheduledAt: draft.dueAt,
              publish: draft.publish,
              assignmentId: created.id,
            ),
          );
        }
      },
    ),
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
      _done('assessment:${draft.classroomId}:${draft.title}:'
          '${draft.attachmentFileIds.join(',')}', (key) async {
        final created = await _client.createAssessment(
          V1CreateAssessmentRequestDto(
            classroomId: draft.classroomId,
            title: draft.title,
            category: draft.category,
            maximumScore: draft.maximumScore,
            scheduledAt: draft.scheduledAt?.toUtc().toIso8601String(),
            delivery: draft.delivery,
            weight: draft.weight,
            assignmentId: draft.assignmentId,
            attachmentFileIds: draft.attachmentFileIds.isEmpty
                ? null
                : draft.attachmentFileIds,
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
        if (draft.publish && created.state == 'draft') {
          await publishAssessment(created.id, created.version);
        }
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
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) =>
      // The attachments are part of the fingerprint: handing the same text in
      // again with a different file is a different submission, and replaying
      // the first key would silently drop the new one.
      _refusing(
        () => _done('assignment-submit:$assignmentId:$studentId:$answer'
            ':${attachmentFileIds.join(",")}', (key) async {
          await _client.submitAssignment(
            V1SubmitAssignmentRequestDto(
              answerText: answer,
              attachmentFileIds: attachmentFileIds.isEmpty
                  ? null
                  : attachmentFileIds,
              // Present only for a guardian handing work in for a child. A
              // student omits it and the server files it against them.
              studentId: studentId,
            ),
            assignmentId: assignmentId,
            idempotencyKey: key,
          );
        }),
      );

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
          effectiveFrom: DateTime.tryParse(slot.effectiveFrom),
          effectiveUntil: switch (slot.effectiveUntil) {
            final until? => DateTime.tryParse(until),
            null => null,
          },
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
            submittedByGuardianId: item.submittedByGuardianId,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return items;
  }

  @override
  Future<List<SubmissionAttempt>> submissionHistory(
    String assignmentId, {
    String? studentId,
  }) async {
    final page = await _client.listSubmissionHistory(
      assignmentId: assignmentId,
      studentId: studentId,
    );
    return [
      for (final item in page.items)
        SubmissionAttempt(
          id: item.id,
          submittedAt: DateTime.parse(item.submittedAt).toLocal(),
          current: item.current,
          answerText: item.answerText,
          submittedByGuardianId: item.submittedByGuardianId,
          submittedByGuardianName: item.submittedByGuardianName,
          attachments: _attachments(item.attachments),
        ),
    ];
  }

  @override
  Future<List<AssignmentExtension>> assignmentExtensions(
    String assignmentId,
  ) async {
    final page = await _client.listAssignmentExtensions(
      assignmentId: assignmentId,
    );
    return [
      for (final item in page.items)
        AssignmentExtension(
          studentId: item.studentId,
          untilLocal: item.extendedUntilLocal,
          reason: item.reason,
        ),
    ];
  }

  @override
  Future<void> grantExtension(
    String assignmentId,
    String studentId,
    String untilLocal,
    String reason,
  ) => _refusing(
    () => _done('extend:$assignmentId:$studentId:$untilLocal:$reason', (
      key,
    ) async {
      await _client.grantAssignmentExtension(
        V1GrantExtensionRequestDto(
          studentId: studentId,
          extendedUntilLocal: untilLocal,
          reason: reason,
        ),
        assignmentId: assignmentId,
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<void> revokeExtension(String assignmentId, String studentId) =>
      _refusing(
        () => _done('extend-revoke:$assignmentId:$studentId', (key) async {
          await _client.revokeAssignmentExtension(
            V1RevokeExtensionRequestDto(studentId: studentId),
            assignmentId: assignmentId,
            idempotencyKey: key,
          );
        }),
      );

  @override
  Future<void> updateAssignmentMaterials(
    String assignmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  }) => _refusing(
    () => _done('materials:$assignmentId:$expectedVersion:'
        '${detachFileIds.join(',')}:${attachmentFileIds.join(',')}:'
        '${addLinks.map((l) => l.url).join(',')}:${removeLinkIds.join(',')}', (
      key,
    ) async {
      await _client.updateAssignmentMaterials(
        V1UpdateWorkMaterialsRequestDto(
          expectedVersion: expectedVersion,
          detachFileIds: detachFileIds,
          attachmentFileIds: attachmentFileIds.isEmpty
              ? null
              : attachmentFileIds,
          links: addLinks.isEmpty ? null : linkDtos(addLinks),
          removeLinkIds: removeLinkIds.isEmpty ? null : removeLinkIds,
        ),
        assignmentId: assignmentId,
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<void> updateAssessmentMaterials(
    String assessmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  }) => _refusing(
    () => _done('exam-materials:$assessmentId:$expectedVersion:'
        '${detachFileIds.join(',')}:${attachmentFileIds.join(',')}:'
        '${addLinks.map((l) => l.url).join(',')}:${removeLinkIds.join(',')}', (
      key,
    ) async {
      await _client.updateAssessmentMaterials(
        V1UpdateWorkMaterialsRequestDto(
          expectedVersion: expectedVersion,
          detachFileIds: detachFileIds,
          attachmentFileIds: attachmentFileIds.isEmpty
              ? null
              : attachmentFileIds,
          links: addLinks.isEmpty ? null : linkDtos(addLinks),
          removeLinkIds: removeLinkIds.isEmpty ? null : removeLinkIds,
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<void> reopenAssignment(
    String assignmentId,
    int expectedVersion,
    String closesAtLocal,
    String reason,
  ) => _refusing(
    () => _done('reopen:$assignmentId:$expectedVersion:$closesAtLocal', (
      key,
    ) async {
      await _client.reopenAssignment(
        V1ReopenAssignmentRequestDto(
          expectedVersion: expectedVersion,
          closesAtLocal: closesAtLocal,
          reason: reason,
        ),
        assignmentId: assignmentId,
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<void> archiveClassroom(String classroomId, int expectedVersion) =>
      _done('archive:$classroomId:$expectedVersion', (key) async {
        await _client.archiveClassroom(
          V1ArchiveClassroomRequestDto(expectedVersion: expectedVersion),
          classroomId: classroomId,
          idempotencyKey: key,
        );
      });

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
            content: SectionContent.parse(item.contentState),
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
    try {
      await _guardiansByStudent(byStudent);
    } on Object {
      // Guardians are extra detail on a roster, not the roster. A school
      // where messaging is restricted, or a contact read that fails, must
      // still let a teacher see their class and what it handed in.
      byStudent.clear();
    }

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

  Future<void> _guardiansByStudent(
    Map<String, List<StudentGuardian>> byStudent,
  ) async {
    String? contactCursor;
    do {
      final page = await _client.listContacts(
        // Contacts are per school; the server refuses a read that does not
        // say which.
        schoolId: _schoolId,
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
    String? sessionId;
    var rule = AttendanceEditRule.open;
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
      sessionId = page.session?.id;
      rule = AttendanceEditRule.fromWire(page.editRule);
      for (final item in page.items) {
        entries.add(
          AttendanceRosterEntry(
            studentId: item.student.id,
            displayName: item.student.displayName,
            state: _stateFrom(item.record?.state),
            reason: item.record?.reason,
            enrolled: item.enrolled ?? true,
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return AttendanceRegister(
      entries: entries,
      version: version,
      sessionId: sessionId,
      editRule: rule,
    );
  }

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
    List<AttendanceDraft> entries, {
    String? correctionReason,
    bool override = false,
  }) => _refusing(
    () => _done('attendance:$classroomId:${startsAt.toUtc().toIso8601String()}:'
        '$expectedVersion:$correctionReason:$override', (key) async {
      await _client.recordAttendance(
        V1RecordAttendanceRequestDto(
          classroomId: classroomId,
          startsAt: startsAt.toUtc().toIso8601String(),
          endsAt: endsAt.toUtc().toIso8601String(),
          expectedVersion: expectedVersion,
          entries: _attendanceEntries(entries),
          correctionReason: correctionReason,
          override: override ? true : null,
        ),
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<void> correctAttendance(
    String sessionId,
    int expectedVersion,
    List<AttendanceDraft> entries, {
    String? reason,
    bool override = false,
  }) => _refusing(
    () => _done('attendance-correct:$sessionId:$expectedVersion:$reason:'
        '$override', (key) async {
      await _client.correctAttendance(
        V1CorrectAttendanceRequestDto(
          expectedVersion: expectedVersion,
          reason: reason,
          override: override ? true : null,
          entries: _attendanceEntries(entries),
        ),
        lessonSessionId: sessionId,
        idempotencyKey: key,
      );
    }),
  );

  @override
  Future<List<AttendanceChange>> attendanceHistory(String sessionId) async {
    final page = await _client.listAttendanceHistory(
      lessonSessionId: sessionId,
      pageSize: 100,
    );
    return [
      for (final item in page.items)
        if ((_stateFrom(item.previousState), _stateFrom(item.nextState)) case (
          final previous?,
          final next?,
        ))
          AttendanceChange(
            studentName: item.studentName,
            previous: previous,
            next: next,
            at: DateTime.parse(item.createdAt).toLocal(),
            reason: item.reason,
            override: item.override,
            actorName: item.actor?.displayName,
          ),
    ];
  }

  static List<V1AttendanceEntryDto> _attendanceEntries(
    List<AttendanceDraft> entries,
  ) => [
    for (final x in entries)
      V1AttendanceEntryDto(
        studentId: x.studentId,
        state: x.state,
        reason: x.reason,
      ),
  ];

  @override
  Future<String> createPaperGradebookItem(
    String classroomId, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  }) => _refusing(
    () => _keys.run(
      'academic',
      'paper-item:$classroomId:$title:$category:'
          '$maximumScore:$weight',
      (key) async {
        final created = await _client.createAssessment(
          V1CreateAssessmentRequestDto(
            classroomId: classroomId,
            title: title,
            category: category,
            maximumScore: maximumScore,
            scheduledAt: scheduledAt?.toUtc().toIso8601String(),
            delivery: 'paper',
            weight: weight,
            questions: const [],
          ),
          idempotencyKey: key,
        );
        return created.id;
      },
    ),
  );

  /// `2026-10-01T23:59`: the wall-clock time [value] shows, without a zone.
  static String _wallClock(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}T'
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Future<PaperGradebook> paperGradebook(String assessmentId) async {
    final rows = <PaperGradebookRow>[];
    PaperGradebookItem? item;
    String? cursor;
    // One page holds a class of up to 100; bigger classes take one more.
    do {
      final page = await _client.listGradebook(
        assessmentId: assessmentId,
        cursor: cursor,
        pageSize: 100,
      );
      final x = page.item;
      item ??= PaperGradebookItem(
        id: x.id,
        title: x.title,
        category: x.category,
        maximumScore: x.maximumScore.toDouble(),
        state: x.state,
        version: x.version,
        gradebookVersion: x.gradebookVersion,
        unmarked: (x.counts['unmarked'] as num?)?.toInt() ?? 0,
        ready: (x.counts['ready'] as num?)?.toInt() ?? 0,
        published: (x.counts['published'] as num?)?.toInt() ?? 0,
        weight: x.weight?.toDouble(),
        scheduledAt: x.scheduledAt == null
            ? null
            : DateTime.tryParse(x.scheduledAt!)?.toLocal(),
        sharedAttachments: _attachments(x.sharedAttachments),
        sharedLinks: contentLinksFrom(x.sharedLinks),
      );
      for (final row in page.items) {
        final grade = row.grade;
        rows.add(
          PaperGradebookRow(
            studentId: row.student.id,
            displayName: row.student.displayName,
            enrolled: row.enrolled,
            grade: grade == null
                ? null
                : PaperGrade(
                    id: grade.id,
                    state: switch (grade.state) {
                      'reviewed' => PaperGradeState.ready,
                      'published' => PaperGradeState.published,
                      'withdrawn' => PaperGradeState.withdrawn,
                      _ => PaperGradeState.unmarked,
                    },
                    version: grade.version,
                    mark: GradeMark.fromWire(grade.mark),
                    score: grade.score?.toDouble(),
                    feedback: grade.feedback,
                    corrections: grade.corrections,
                    attachments: _attachments(grade.attachments),
                    links: contentLinksFrom(grade.links),
                  ),
          ),
        );
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return PaperGradebook(item: item, rows: rows);
  }

  @override
  Future<int> saveGradeDrafts(
    String assessmentId,
    int gradebookVersion,
    List<GradeDraft> entries,
  ) => _refusing(
    () => _keys.run(
      'academic',
      'grades-save:$assessmentId:$gradebookVersion:${_draftPrint(entries)}',
      (key) async {
        final saved = await _client.saveGradeDrafts(
          V1SaveGradeDraftsRequestDto(
            expectedGradebookVersion: gradebookVersion,
            entries: [
              for (final entry in entries)
                V1GradeDraftEntryDto(
                  studentId: entry.studentId,
                  expectedVersion: entry.expectedVersion,
                  mark: entry.mark?.wire,
                  score: entry.score,
                  feedback: entry.feedback,
                ),
            ],
          ),
          assessmentId: assessmentId,
          idempotencyKey: key,
        );
        return saved.gradebookVersion;
      },
    ),
  );

  static String _draftPrint(List<GradeDraft> entries) => [
    for (final e in entries)
      '${e.studentId}/${e.expectedVersion}/${e.mark?.wire}/${e.score}/'
          '${e.feedback}',
  ].join('|');

  @override
  Future<PublishedGrades> publishGrades(
    String assessmentId,
    int gradebookVersion,
  ) => _refusing(
    () => _keys.run(
      'academic',
      'grades-publish:$assessmentId:$gradebookVersion',
      (key) async {
        final result = await _client.publishGrades(
          V1PublishGradesRequestDto(expectedGradebookVersion: gradebookVersion),
          assessmentId: assessmentId,
          idempotencyKey: key,
        );
        return PublishedGrades(
          published: result.published,
          unmarked: result.unmarked,
        );
      },
    ),
  );

  @override
  Future<void> correctGrades(
    String assessmentId,
    String? reason,
    List<GradeCorrection> entries,
  ) => _refusing(
    () => _done(
      'grades-correct:$assessmentId:$reason:'
      '${[for (final e in entries) '${e.gradeId}/${e.expectedVersion}/${e.mark.wire}/${e.score}/${e.feedback}'].join('|')}',
      (key) async {
        await _client.correctGrades(
          V1CorrectGradesRequestDto(
            reason: reason,
            entries: [
              for (final entry in entries)
                V1GradeCorrectionEntryDto(
                  gradeResultId: entry.gradeId,
                  expectedVersion: entry.expectedVersion,
                  mark: entry.mark.wire,
                  score: entry.score,
                  feedback: entry.feedback,
                ),
            ],
          ),
          assessmentId: assessmentId,
          idempotencyKey: key,
        );
      },
    ),
  );

  @override
  Future<List<GradeChange>> gradeHistory(String gradeId) async {
    final page = await _client.listGradeHistory(
      gradeResultId: gradeId,
      pageSize: 100,
    );
    return [
      for (final item in page.items)
        GradeChange(
          change: item.change,
          at: DateTime.parse(item.createdAt).toLocal(),
          previousMark: GradeMark.fromWire(item.previousMark),
          previousScore: item.previousScore?.toDouble(),
          nextMark: GradeMark.fromWire(item.nextMark),
          nextScore: item.nextScore?.toDouble(),
          reason: item.reason,
          actorName: item.actor?.displayName,
        ),
    ];
  }

  @override
  Future<void> updateGradebookItem(
    String assessmentId,
    int expectedVersion, {
    required String title,
    required String category,
    required double maximumScore,
    double? weight,
    DateTime? scheduledAt,
  }) => _refusing(
    () => _done('gradebook-item:$assessmentId:$expectedVersion:$title:'
        '$category:$maximumScore:$weight', (key) async {
      await _client.updateGradebookItem(
        V1UpdateGradebookItemRequestDto(
          expectedVersion: expectedVersion,
          title: title,
          category: category,
          maximumScore: maximumScore,
          weight: weight,
          scheduledAt: scheduledAt?.toUtc().toIso8601String(),
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
    }),
  );

  /// A refusal the screen can act on, instead of a generic failure. Anything
  /// else - offline, signed out - keeps its ordinary meaning.
  static Future<T> _refusing<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on V1ApiException catch (error) {
      final problem = switch (error.code) {
        'VERSION_CONFLICT' => CourseworkProblem.versionConflict,
        'INVALID_STATE' => CourseworkProblem.invalidState,
        'GRADE_ENTRIES_INVALID' => CourseworkProblem.entriesInvalid,
        'REASON_REQUIRED' => CourseworkProblem.reasonRequired,
        'ATTENDANCE_LOCKED' => CourseworkProblem.attendanceLocked,
        'SUBMISSION_LOCKED' => CourseworkProblem.submissionLocked,
        'WINDOW_CLOSED' => CourseworkProblem.windowClosed,
        'ATTACHMENT_REFUSED' => CourseworkProblem.attachmentRefused,
        'FORBIDDEN' || 'NOT_FOUND' => CourseworkProblem.notAllowed,
        _ => null,
      };
      if (problem == null) rethrow;
      throw CourseworkRefusal(
        problem,
        rows: {
          for (final entry in error.fieldErrors.entries)
            entry.key.split('/').last: entry.value,
        },
      );
    }
  }

  static SubmissionDeadline? _deadline(V1AssignmentDto x) {
    final local = x.deadlineLocal;
    final zone = x.timeZone;
    if (local == null || zone == null) return null;
    return SubmissionDeadline(
      state: switch (x.submissionState) {
        'closed' => SubmissionWindow.closed,
        'graded_locked' => SubmissionWindow.gradedLocked,
        _ => SubmissionWindow.open,
      },
      deadlineLocal: local,
      timeZone: zone,
      extendedUntilLocal: x.extension?.extendedUntilLocal,
    );
  }

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
          followUp: draft.followUp,
          visibility: draft.visibility,
          severity: draft.severity,
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

  // -------------------------------------------------------------------------
  // Online assessments (ADR-0036), delegated.
  // -------------------------------------------------------------------------

  @override
  Future<OnlineAssessment> createOnlineAssessment(
    OnlineAssessmentDraft draft,
  ) => _online.createOnlineAssessment(draft);

  @override
  Future<List<AssessmentQuestion>> authoringQuestions(String assessmentId) =>
      _online.authoringQuestions(assessmentId);

  @override
  Future<List<AssessmentQuestion>> questions(String assessmentId) =>
      _online.questions(assessmentId);

  @override
  Future<OnlineAssessment> updateAssessmentDesign(
    String assessmentId,
    int expectedVersion, {
    String? title,
    List<QuestionDraft>? questions,
    AssessmentSettings? settings,
    bool releaseAnswersNow = false,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) => _online.updateAssessmentDesign(
    assessmentId,
    expectedVersion,
    title: title,
    questions: questions,
    settings: settings,
    releaseAnswersNow: releaseAnswersNow,
    attachments: attachments,
  );

  @override
  Future<AttemptConfirmation> submitAnswers(
    String assessmentId,
    List<StudentAnswer> answers,
  ) => _online.submitAnswers(assessmentId, answers);

  @override
  Future<AssessmentResults> results(String assessmentId, {String? studentId}) =>
      _online.results(assessmentId, studentId: studentId);

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) =>
      _online.attempts(assessmentId);

  @override
  Future<AttemptDetail> attempt(String attemptId) => _online.attempt(attemptId);

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  }) => _online.markAttempt(
    attemptId,
    marks,
    feedback: feedback,
    correctionReason: correctionReason,
  );

  @override
  Future<void> grantAccess(
    String assessmentId,
    String studentId, {
    DateTime? closesAt,
    int extraAttempts = 0,
    String? reason,
  }) => _online.grantAccess(
    assessmentId,
    studentId,
    closesAt: closesAt,
    extraAttempts: extraAttempts,
    reason: reason,
  );

  @override
  Future<GradeAttachments> updateGradeAttachments(
    String assessmentId,
    AttachmentChanges changes, {
    String? studentId,
  }) => _online.updateGradeAttachments(
    assessmentId,
    changes,
    studentId: studentId,
  );

  static List<StoredAttachment> _attachments(
    List<V1FileAttachmentDto>? items,
  ) => [
    for (final dto in items ?? const <V1FileAttachmentDto>[])
      StoredAttachment(
        id: dto.id,
        displayName: dto.displayName,
        sizeBytes: dto.sizeBytes,
        scanState: dto.scanState,
        mediaType: dto.mediaType,
      ),
  ];

  static List<LessonReadingSource> _reading(V1LessonMaterialDto dto) => [
    for (final source in dto.sources)
      LessonReadingSource(
        id: source.id,
        isLink: source.kind == 'link',
        name: source.name,
        state: ReadingState.parse(source.state),
        reason: source.reason,
        pages: source.pages,
        skippedPages: source.skippedPages,
      ),
  ];

  @override
  Future<List<LessonReadingSource>> lessonReading(String resourceId) async =>
      _reading(await _client.listLessonReading(resourceId: resourceId));

  @override
  Future<List<LessonReadingSource>> retryLessonReading(
    String resourceId,
    String sourceId,
  ) async => _reading(
    await _client.retryLessonReading(
      const V1RetryLessonMaterialRequestDto(),
      resourceId: resourceId,
      sourceId: sourceId,
      idempotencyKey: newIdempotencyKey('reading-retry'),
    ),
  );
}
