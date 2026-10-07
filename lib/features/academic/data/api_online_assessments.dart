import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../domain/online_assessment.dart';

/// Turns a refusal into something a screen can act on; supplied by the
/// academic repository so both speak the same language.
typedef Refusing = Future<T> Function<T>(Future<T> Function() call);

/// Online assessments and coursework attachments over `/v1` (ADR-0036).
/// [ApiAcademicRepository] delegates to this, so its own file stays about
/// the older surfaces.
class ApiOnlineAssessments implements OnlineAssessmentRepository {
  ApiOnlineAssessments(this._client, this._keys, this._refusing);

  final V1ApiClient _client;
  final PendingIdempotencyKeys _keys;
  final Refusing _refusing;

  Future<T> _run<T>(String fingerprint, Future<T> Function(String key) call) =>
      _refusing(() => _keys.run('assessments', fingerprint, call));

  @override
  Future<OnlineAssessment> createOnlineAssessment(
    OnlineAssessmentDraft draft,
  ) => _run(
    'create:${draft.classroomId}:${draft.title}:${draft.questions.length}:'
    '${draft.attachmentFileIds.join(',')}:'
    '${draft.questions.map(_fingerprint).join('|')}',
    (key) async => onlineAssessmentFrom(
      await _client.createAssessment(
        V1CreateAssessmentRequestDto(
          classroomId: draft.classroomId,
          title: draft.title,
          category: draft.category,
          maximumScore: draft.maximumScore,
          scheduledAt: draft.settings.opensAt?.toUtc().toIso8601String(),
          delivery: 'online',
          questions: [
            for (var i = 0; i < draft.questions.length; i++)
              questionDraftDto(draft.questions[i], i + 1),
          ],
          attachmentFileIds: draft.attachmentFileIds.isEmpty
              ? null
              : draft.attachmentFileIds,
          links: draft.links.isEmpty ? null : linkDtos(draft.links),
          opensAt: draft.settings.opensAt?.toUtc().toIso8601String(),
          closesAt: draft.settings.closesAt?.toUtc().toIso8601String(),
          maxAttempts: draft.settings.maxAttempts,
          attemptPolicy: draft.settings.attemptPolicy.wire,
          answerRelease: draft.settings.answerRelease.wire,
        ),
        idempotencyKey: key,
      ),
    ),
  );

  @override
  Future<List<AssessmentQuestion>> authoringQuestions(
    String assessmentId,
  ) async {
    final page = await _client.listAssessmentAuthoringQuestions(
      assessmentId: assessmentId,
    );
    return [for (final dto in page.items) authoringQuestionFrom(dto)];
  }

  @override
  Future<List<AssessmentQuestion>> questions(String assessmentId) async {
    final page = await _client.listAssessmentQuestions(
      assessmentId: assessmentId,
    );
    return [
      for (final dto in page.items)
        AssessmentQuestion(
          id: dto.id,
          position: dto.position,
          prompt: dto.prompt,
          maximumScore: dto.maximumScore.toDouble(),
          kind: QuestionKind.fromWire(dto.kind),
          required: dto.required ?? true,
          options: optionsFrom(dto.options),
          attachments: storedAttachmentsFrom(dto.attachments),
          links: contentLinksFrom(dto.links),
        ),
    ];
  }

  @override
  Future<OnlineAssessment> updateAssessmentDesign(
    String assessmentId,
    int expectedVersion, {
    String? title,
    List<QuestionDraft>? questions,
    AssessmentSettings? settings,
    bool releaseAnswersNow = false,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) => _run(
    'design:$assessmentId:$expectedVersion:$title:$releaseAnswersNow:'
    '${questions?.map(_fingerprint).join('|')}:'
    '${settings?.opensAt}:${settings?.closesAt}:${settings?.maxAttempts}:'
    '${settings?.attemptPolicy}:${settings?.answerRelease}:'
    '${_changes(attachments)}',
    (key) async => onlineAssessmentFrom(
      await _client.updateAssessmentDesign(
        V1UpdateAssessmentDesignRequestDto(
          expectedVersion: expectedVersion,
          title: title,
          questions: questions == null
              ? null
              : [
                  for (var i = 0; i < questions.length; i++)
                    questionDraftDto(questions[i], i + 1),
                ],
          opensAt: settings?.opensAt?.toUtc().toIso8601String(),
          closesAt: settings?.closesAt?.toUtc().toIso8601String(),
          maxAttempts: settings?.maxAttempts,
          attemptPolicy: settings?.attemptPolicy.wire,
          answerRelease: releaseAnswersNow
              ? AnswerRelease.manual.wire
              : settings?.answerRelease.wire,
          releaseAnswersNow: releaseAnswersNow ? true : null,
          attachmentFileIds: _orNull(attachments.attachFileIds),
          detachFileIds: _orNull(attachments.detachFileIds),
          links: attachments.addLinks.isEmpty
              ? null
              : linkDtos(attachments.addLinks),
          removeLinkIds: _orNull(attachments.removeLinkIds),
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      ),
    ),
  );

  @override
  Future<AttemptConfirmation> submitAnswers(
    String assessmentId,
    List<StudentAnswer> answers,
  ) => _run(
    'submit:$assessmentId:${answers.map((a) => '${a.questionId}=${a.text}/'
        '${a.selectedOptionIds.join('+')}/${a.choice}').join('|')}',
    (key) async {
      final attempt = await _client.submitAssessment(
        V1SubmitAssessmentRequestDto(
          answers: [
            for (final answer in answers)
              if (!answer.isEmpty)
                V1AssessmentAnswerDto(
                  questionId: answer.questionId,
                  answerText: answer.text,
                  selectedOptionIds: answer.selectedOptionIds.isEmpty
                      ? null
                      : answer.selectedOptionIds,
                  choice: answer.choice,
                ),
          ],
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
      return AttemptConfirmation(
        id: attempt.id,
        submittedAt: _when(attempt.submittedAt) ?? DateTime.now(),
        attemptNumber: attempt.attemptNumber,
        attemptsRemaining: attempt.attemptsRemaining,
      );
    },
  );

  @override
  Future<AssessmentResults> results(
    String assessmentId, {
    String? studentId,
  }) async {
    final dto = await _client.getAssessmentResults(
      assessmentId: assessmentId,
      studentId: studentId,
    );
    final grade = dto.grade;
    return AssessmentResults(
      assessment: onlineAssessmentFrom(dto.assessment),
      studentId: dto.studentId,
      opensAt: _when(dto.opensAt),
      closesAt: _when(dto.closesAt),
      attemptsAllowed: dto.attemptsAllowed,
      attemptsUsed: dto.attemptsUsed,
      canAttempt: dto.canAttempt,
      answersReleased: dto.answersReleased,
      attempts: [for (final a in dto.attempts) attemptFrom(a)],
      grade: grade == null
          ? null
          : ReleasedGrade(
              score: grade.score?.toDouble(),
              maximumScore: grade.maximumScore.toDouble(),
              mark: grade.mark,
              feedback: grade.feedback,
              publishedAt: _when(grade.publishedAt),
              attachments: storedAttachmentsFrom(grade.attachments),
              links: contentLinksFrom(grade.links),
              sharedAttachments: storedAttachmentsFrom(grade.sharedAttachments),
              sharedLinks: contentLinksFrom(grade.sharedLinks),
            ),
    );
  }

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) async {
    final page = await _client.listAssessmentAttempts(
      assessmentId: assessmentId,
    );
    return [
      for (final a in page.items)
        AttemptDetail(
          id: a.id,
          studentId: a.studentId,
          studentName: a.studentName,
          submittedAt: _when(a.submittedAt) ?? DateTime.now(),
          attemptNumber: a.attemptNumber,
          needsMarking: a.needsMarking,
          awardedScore: a.awardedScore?.toDouble(),
          gradeState: a.gradeState,
          pendingAnswers: a.pendingAnswers,
          manualAnswers: a.manualAnswers,
        ),
    ];
  }

  @override
  Future<AttemptDetail> attempt(String attemptId) async =>
      attemptFrom(await _client.getAssessmentAttempt(attemptId: attemptId));

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
    String? correctionReason,
  }) => _run(
    'mark:$attemptId:${marks.map((m) => '${m.questionId}=${m.score}/'
        '${m.feedback}').join('|')}:$feedback:$correctionReason',
    (key) async => attemptFrom(
      await _client.markAssessmentAttempt(
        V1MarkAssessmentAttemptRequestDto(
          marks: [
            for (final mark in marks)
              V1AnswerMarkDto(
                questionId: mark.questionId,
                score: mark.score,
                feedback: mark.feedback,
              ),
          ],
          // Null leaves the comment as it was; an empty one clears it.
          feedback: feedback,
          correctionReason: correctionReason,
        ),
        attemptId: attemptId,
        idempotencyKey: key,
      ),
    ),
  );

  @override
  Future<void> grantAccess(
    String assessmentId,
    String studentId, {
    DateTime? closesAt,
    int extraAttempts = 0,
    String? reason,
  }) => _run(
    'access:$assessmentId:$studentId:$closesAt:$extraAttempts',
    (key) => _client.grantAssessmentAccess(
      V1GrantAssessmentAccessRequestDto(
        studentId: studentId,
        closesAt: closesAt?.toUtc().toIso8601String(),
        extraAttempts: extraAttempts,
        reason: reason,
      ),
      assessmentId: assessmentId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<GradeAttachments> updateGradeAttachments(
    String assessmentId,
    AttachmentChanges changes, {
    String? studentId,
  }) => _run(
    'grade-attachments:$assessmentId:$studentId:${_changes(changes)}',
    (key) async {
      final dto = await _client.updateGradeAttachments(
        V1UpdateGradeAttachmentsRequestDto(
          studentId: studentId,
          attachmentFileIds: _orNull(changes.attachFileIds),
          detachFileIds: _orNull(changes.detachFileIds),
          links: changes.addLinks.isEmpty ? null : linkDtos(changes.addLinks),
          removeLinkIds: _orNull(changes.removeLinkIds),
        ),
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
      return GradeAttachments(
        attachments: storedAttachmentsFrom(dto.attachments),
        links: contentLinksFrom(dto.links),
      );
    },
  );

  static List<String>? _orNull(List<String> ids) => ids.isEmpty ? null : ids;

  static String _changes(AttachmentChanges c) =>
      '${c.attachFileIds.join(',')}/${c.detachFileIds.join(',')}/'
      '${c.addLinks.map((l) => '${l.title}@${l.url}').join(',')}/'
      '${c.removeLinkIds.join(',')}';

  static String _fingerprint(QuestionDraft q) =>
      '${q.id}:${q.kind.wire}:${q.prompt}:${q.maximumScore}:${q.required}:'
      '${q.options.map((o) => '${o.id}=${o.text}').join(',')}:'
      '${q.correctOptionIds.join(',')}:${q.correctChoice}:'
      '${q.acceptedAnswers.join(',')}:${q.preferredAnswer}:'
      '${q.markingGuidance}:${_changes(q.attachments)}';

  static DateTime? _when(String? at) =>
      at == null ? null : DateTime.tryParse(at)?.toLocal();
}

// ---------------------------------------------------------------------------
// Mapping, shared with the academic repository.
// ---------------------------------------------------------------------------

List<StoredAttachment> storedAttachmentsFrom(
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

List<ContentLink> contentLinksFrom(List<V1ContentLinkDto>? items) => [
  for (final dto in items ?? const <V1ContentLinkDto>[])
    ContentLink(id: dto.id, title: dto.title, url: dto.url),
];

List<V1ContentLinkDraftDto> linkDtos(List<LinkDraft> links) => [
  for (final link in links)
    V1ContentLinkDraftDto(title: link.title.trim(), url: link.url.trim()),
];

List<QuestionOption> optionsFrom(List<V1QuestionOptionDto>? items) => [
  for (final dto in items ?? const <V1QuestionOptionDto>[])
    QuestionOption(id: dto.id, text: dto.text),
];

V1AssessmentQuestionDraftDto questionDraftDto(QuestionDraft q, int position) =>
    V1AssessmentQuestionDraftDto(
      id: q.id,
      position: position,
      prompt: q.prompt.trim(),
      preferredAnswer: (q.preferredAnswer ?? '').trim().isEmpty
          ? null
          : q.preferredAnswer!.trim(),
      maximumScore: q.maximumScore,
      kind: q.kind.wire,
      required: q.required,
      options: q.kind.hasOptions
          ? [
              for (final option in q.options)
                V1QuestionOptionDto(id: option.id, text: option.text.trim()),
            ]
          : null,
      correctOptionIds: q.kind.hasOptions ? q.correctOptionIds : null,
      correctChoice: q.kind == QuestionKind.trueFalse ? q.correctChoice : null,
      acceptedAnswers:
          q.kind == QuestionKind.shortAnswer && q.acceptedAnswers.isNotEmpty
          ? [for (final a in q.acceptedAnswers) a.trim()]
          : null,
      markingGuidance: (q.markingGuidance ?? '').trim().isEmpty
          ? null
          : q.markingGuidance!.trim(),
      attachmentFileIds: q.attachments.attachFileIds.isEmpty
          ? null
          : q.attachments.attachFileIds,
      detachFileIds: q.attachments.detachFileIds.isEmpty
          ? null
          : q.attachments.detachFileIds,
      links: q.attachments.addLinks.isEmpty
          ? null
          : linkDtos(q.attachments.addLinks),
      removeLinkIds: q.attachments.removeLinkIds.isEmpty
          ? null
          : q.attachments.removeLinkIds,
    );

AssessmentQuestion authoringQuestionFrom(
  V1AssessmentAuthoringQuestionDto dto,
) => AssessmentQuestion(
  id: dto.id,
  position: dto.position,
  prompt: dto.prompt,
  maximumScore: dto.maximumScore.toDouble(),
  kind: QuestionKind.fromWire(dto.kind),
  required: dto.required ?? true,
  options: optionsFrom(dto.options),
  attachments: storedAttachmentsFrom(dto.attachments),
  links: contentLinksFrom(dto.links),
  correctOptionIds: dto.correctOptionIds,
  correctChoice: dto.correctChoice,
  acceptedAnswers: dto.acceptedAnswers,
  preferredAnswer: dto.preferredAnswer,
  markingGuidance: dto.markingGuidance,
);

AttemptDetail attemptFrom(V1AssessmentAttemptDetailDto dto) => AttemptDetail(
  id: dto.id,
  studentId: dto.studentId,
  submittedAt: DateTime.tryParse(dto.submittedAt)?.toLocal() ?? DateTime.now(),
  attemptNumber: dto.attemptNumber,
  needsMarking: dto.needsMarking,
  awardedScore: dto.awardedScore?.toDouble(),
  feedback: dto.feedback,
  studentName: dto.studentName,
  gradeState: dto.gradeState,
  gradeMark: dto.gradeMark,
  answers: [
    for (final a in dto.answers ?? const <V1AttemptAnswerDto>[])
      AttemptAnswer(
        question: authoringQuestionFrom(a.question),
        answerText: a.answerText,
        selectedOptionIds: a.selectedOptionIds,
        choice: a.choice,
        autoScore: a.autoScore?.toDouble(),
        awardedScore: a.awardedScore?.toDouble(),
        feedback: a.feedback,
      ),
  ],
);

OnlineAssessment onlineAssessmentFrom(V1AssessmentDto dto) => OnlineAssessment(
  id: dto.id,
  classroomId: dto.classroomId,
  title: dto.title,
  category: dto.category,
  maximumScore: dto.maximumScore.toDouble(),
  state: dto.state,
  version: dto.version,
  delivery: dto.delivery,
  settings: AssessmentSettings(
    opensAt: dto.opensAt == null
        ? null
        : DateTime.tryParse(dto.opensAt!)?.toLocal(),
    closesAt: dto.closesAt == null
        ? null
        : DateTime.tryParse(dto.closesAt!)?.toLocal(),
    maxAttempts: dto.maxAttempts ?? 1,
    attemptPolicy: AttemptPolicy.fromWire(dto.attemptPolicy),
    answerRelease: AnswerRelease.fromWire(dto.answerRelease),
  ),
  answersReleasedAt: dto.answersReleasedAt == null
      ? null
      : DateTime.tryParse(dto.answersReleasedAt!)?.toLocal(),
  questionCount: dto.questionCount ?? 0,
  attachments: storedAttachmentsFrom(dto.attachments),
  links: contentLinksFrom(dto.links),
);
