import '../domain/academic_repository.dart';

/// Synthetic-only online assessments, kept in process (ADR-0036). Enough to
/// build a quiz, sit it, see it marked and see answers once it closes - the
/// real rules are the server's.
class PreviewOnlineAssessments implements OnlineAssessmentRepository {
  PreviewOnlineAssessments({required this.onCreated});

  /// Lists a new assessment in the preview's assessments feed.
  final void Function(AcademicRecord record) onCreated;

  final Map<String, OnlineAssessment> _assessments = {};
  final Map<String, List<AssessmentQuestion>> _questions = {};
  final Map<String, List<AttemptDetail>> _attempts = {};
  int _sequence = 0;

  String _id(String kind) => 'preview-$kind-${++_sequence}';

  @override
  Future<OnlineAssessment> createOnlineAssessment(
    OnlineAssessmentDraft draft,
  ) async {
    final id = _id('online');
    final assessment = OnlineAssessment(
      id: id,
      classroomId: draft.classroomId,
      title: draft.title,
      category: draft.category,
      maximumScore: draft.maximumScore,
      state: 'draft',
      version: 1,
      delivery: 'online',
      settings: draft.settings,
      questionCount: draft.questions.length,
    );
    _assessments[id] = assessment;
    _questions[id] = _written(draft.questions);
    onCreated(
      AcademicRecord(
        id: id,
        title: draft.title,
        detail: '${draft.maximumScore} points',
        state: 'draft',
        version: 1,
        classroomId: draft.classroomId,
        delivery: 'online',
      ),
    );
    return assessment;
  }

  List<AssessmentQuestion> _written(List<QuestionDraft> drafts) => [
    for (var i = 0; i < drafts.length; i++)
      AssessmentQuestion(
        id: drafts[i].id ?? _id('question'),
        position: i + 1,
        prompt: drafts[i].prompt,
        maximumScore: drafts[i].maximumScore,
        kind: drafts[i].kind,
        required: drafts[i].required,
        options: drafts[i].options,
        correctOptionIds: drafts[i].correctOptionIds,
        correctChoice: drafts[i].correctChoice,
        acceptedAnswers: drafts[i].acceptedAnswers,
        preferredAnswer: drafts[i].preferredAnswer,
        markingGuidance: drafts[i].markingGuidance,
      ),
  ];

  @override
  Future<List<AssessmentQuestion>> authoringQuestions(
    String assessmentId,
  ) async => _questions[assessmentId] ?? const [];

  @override
  Future<List<AssessmentQuestion>> questions(String assessmentId) async => [
    for (final q in _questions[assessmentId] ?? const <AssessmentQuestion>[])
      AssessmentQuestion(
        id: q.id,
        position: q.position,
        prompt: q.prompt,
        maximumScore: q.maximumScore,
        kind: q.kind,
        required: q.required,
        options: q.options,
      ),
  ];

  @override
  Future<OnlineAssessment> updateAssessmentDesign(
    String assessmentId,
    int expectedVersion, {
    String? title,
    List<QuestionDraft>? questions,
    AssessmentSettings? settings,
    bool releaseAnswersNow = false,
    AttachmentChanges attachments = const AttachmentChanges(),
  }) async {
    final current = _assessments[assessmentId]!;
    if (questions != null) _questions[assessmentId] = _written(questions);
    final updated = OnlineAssessment(
      id: current.id,
      classroomId: current.classroomId,
      title: title ?? current.title,
      category: current.category,
      maximumScore: (_questions[assessmentId] ?? const <AssessmentQuestion>[])
          .fold(0, (sum, q) => sum + q.maximumScore),
      state: current.state,
      version: current.version + 1,
      delivery: current.delivery,
      settings: settings ?? current.settings,
      answersReleasedAt: releaseAnswersNow ? DateTime.now() : null,
      questionCount: _questions[assessmentId]?.length ?? 0,
    );
    _assessments[assessmentId] = updated;
    return updated;
  }

  @override
  Future<AttemptConfirmation> submitAnswers(
    String assessmentId,
    List<StudentAnswer> answers,
  ) async {
    final list = _attempts.putIfAbsent(assessmentId, () => []);
    final marked = <AttemptAnswer>[];
    for (final q in _questions[assessmentId] ?? const <AssessmentQuestion>[]) {
      final answer = answers.where((a) => a.questionId == q.id).firstOrNull;
      double? score;
      switch (q.kind) {
        case QuestionKind.singleChoice || QuestionKind.multipleChoice:
          final chosen = {...?answer?.selectedOptionIds};
          score =
              chosen.length == (q.correctOptionIds?.length ?? -1) &&
                  chosen.containsAll(q.correctOptionIds ?? const [])
              ? q.maximumScore
              : 0;
        case QuestionKind.trueFalse:
          score = answer?.choice == q.correctChoice ? q.maximumScore : 0;
        case QuestionKind.shortAnswer:
          final accepted = q.acceptedAnswers ?? const [];
          score = accepted.isEmpty
              ? null
              : accepted.any(
                  (a) =>
                      a.trim().toLowerCase() ==
                      (answer?.text ?? '').trim().toLowerCase(),
                )
              ? q.maximumScore
              : 0;
        case QuestionKind.essay:
          score = null;
      }
      marked.add(
        AttemptAnswer(
          question: q,
          answerText: answer?.text,
          selectedOptionIds: answer?.selectedOptionIds,
          choice: answer?.choice,
          autoScore: score,
          awardedScore: score,
        ),
      );
    }
    final pending = marked.any((a) => a.awardedScore == null);
    final attempt = AttemptDetail(
      id: _id('attempt'),
      studentId: 'preview-student',
      studentName: 'Preview student',
      submittedAt: DateTime.now(),
      attemptNumber: list.length + 1,
      needsMarking: pending,
      awardedScore: pending
          ? null
          : marked.fold<double>(0, (sum, a) => sum + (a.awardedScore ?? 0)),
      answers: marked,
    );
    list.add(attempt);
    final allowed = _assessments[assessmentId]?.settings.maxAttempts ?? 1;
    return AttemptConfirmation(
      id: attempt.id,
      submittedAt: attempt.submittedAt,
      attemptNumber: attempt.attemptNumber,
      attemptsRemaining: (allowed - list.length).clamp(0, 20),
    );
  }

  bool _released(OnlineAssessment a) {
    final closes = a.settings.closesAt;
    return a.answersReleasedAt != null ||
        (a.settings.answerRelease == AnswerRelease.afterClose &&
            closes != null &&
            closes.isBefore(DateTime.now()));
  }

  @override
  Future<AssessmentResults> results(
    String assessmentId, {
    String? studentId,
  }) async {
    final a = _assessments[assessmentId]!;
    final attempts = _attempts[assessmentId] ?? const <AttemptDetail>[];
    final released = _released(a);
    final closes = a.settings.closesAt;
    return AssessmentResults(
      assessment: a,
      studentId: studentId ?? 'preview-student',
      opensAt: a.settings.opensAt,
      closesAt: closes,
      attemptsAllowed: a.settings.maxAttempts,
      attemptsUsed: attempts.length,
      canAttempt:
          studentId == null &&
          attempts.length < a.settings.maxAttempts &&
          (closes == null || closes.isAfter(DateTime.now())),
      answersReleased: released,
      attempts: [
        for (final t in attempts)
          released
              ? t
              : AttemptDetail(
                  id: t.id,
                  studentId: t.studentId,
                  submittedAt: t.submittedAt,
                  attemptNumber: t.attemptNumber,
                ),
      ],
    );
  }

  @override
  Future<List<AttemptDetail>> attempts(String assessmentId) async =>
      _attempts[assessmentId] ?? const [];

  @override
  Future<AttemptDetail> attempt(String attemptId) async => _attempts.values
      .expand((list) => list)
      .firstWhere((t) => t.id == attemptId);

  @override
  Future<AttemptDetail> markAttempt(
    String attemptId,
    List<AnswerMark> marks, {
    String? feedback,
  }) async {
    for (final entry in _attempts.entries) {
      final index = entry.value.indexWhere((t) => t.id == attemptId);
      if (index < 0) continue;
      final t = entry.value[index];
      final answers = [
        for (final a in t.answers)
          () {
            final mark = marks
                .where((m) => m.questionId == a.question.id)
                .firstOrNull;
            return mark == null
                ? a
                : AttemptAnswer(
                    question: a.question,
                    answerText: a.answerText,
                    selectedOptionIds: a.selectedOptionIds,
                    choice: a.choice,
                    autoScore: a.autoScore,
                    awardedScore: mark.score,
                    feedback: mark.feedback,
                  );
          }(),
      ];
      final pending = answers.any((a) => a.awardedScore == null);
      final updated = AttemptDetail(
        id: t.id,
        studentId: t.studentId,
        studentName: t.studentName,
        submittedAt: t.submittedAt,
        attemptNumber: t.attemptNumber,
        needsMarking: pending,
        awardedScore: pending
            ? null
            : answers.fold<double>(0, (sum, a) => sum + (a.awardedScore ?? 0)),
        feedback: feedback ?? t.feedback,
        answers: answers,
      );
      entry.value[index] = updated;
      return updated;
    }
    throw StateError('No such attempt');
  }

  @override
  Future<void> grantAccess(
    String assessmentId,
    String studentId, {
    DateTime? closesAt,
    int extraAttempts = 0,
    String? reason,
  }) async {}

  @override
  Future<GradeAttachments> updateGradeAttachments(
    String assessmentId,
    AttachmentChanges changes, {
    String? studentId,
  }) async => const GradeAttachments();
}
