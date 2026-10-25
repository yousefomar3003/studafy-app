import '../domain/academic_repository.dart';
import '../domain/marking.dart';

/// Studafy AI Marking in a synthetic build: references are kept in memory,
/// and suggestions are never made - there is no AI behind a preview, so
/// the plan says suggestions are not available and nothing offers them.
///
/// Tests seed [plan], references and suggestions to drive the screens.
class PreviewMarkingRepository
    implements MarkingRepository, MarkingPreferenceRepository {
  PreviewMarkingRepository({
    this.academic,
    MarkingPlan? plan,
    Map<String, MarkingReferences>? references,
    Map<String, List<MarkingSuggestion>>? suggestions,
    bool optedOut = false,
  }) : currentPlan =
           plan ??
           MarkingPlan(
             active: false,
             teacher: true,
             available: false,
             used: 0,
             total: 4000000,
             resetsAt: DateTime.utc(2100),
           ),
       _references = {...?references},
       _suggestions = {
         for (final entry in (suggestions ?? const {}).entries)
           entry.key: [...entry.value],
       },
       // ignore: prefer_initializing_formals
       _optedOut = optedOut;

  /// Where the questions come from when no reference was seeded.
  final AcademicRepository? academic;
  MarkingPlan currentPlan;
  final Map<String, MarkingReferences> _references;
  final Map<String, List<MarkingSuggestion>> _suggestions;
  bool _optedOut;

  @override
  Future<MarkingPlan> plan() async => currentPlan;

  @override
  Future<MarkingReferences> references(String assessmentId) async =>
      _references[assessmentId] ??= await _derive(assessmentId);

  /// A reference for each question, or one for a hand-in, with nothing
  /// written yet beyond what the questions already hold.
  Future<MarkingReferences> _derive(String assessmentId) async {
    final source = academic;
    var questions = const <AssessmentQuestion>[];
    try {
      questions = await source?.authoringQuestions(assessmentId) ?? const [];
    } on Object {
      questions = const [];
    }
    if (questions.isNotEmpty) {
      return MarkingReferences(
        delivery: 'online',
        strictness: MarkingStrictness.balanced,
        referenceVersion: 1,
        references: [
          for (final q in questions)
            MarkingReference(
              questionId: q.id,
              position: q.position,
              kind: q.kind,
              prompt: q.prompt,
              maximumScore: q.maximumScore,
              options: q.options,
              correctOptionIds: q.correctOptionIds,
              correctChoice: q.correctChoice,
              acceptedAnswers: q.acceptedAnswers,
              preferredAnswer: q.preferredAnswer,
              markingGuidance: q.markingGuidance,
            ),
        ],
      );
    }
    var maximum = 100.0;
    String? title;
    try {
      final sheet = await source?.paperGradebook(assessmentId);
      maximum = sheet?.item.maximumScore ?? maximum;
      title = sheet?.item.title;
    } on Object {
      // A preview with no sheet for it still has a reference to write.
    }
    return MarkingReferences(
      delivery: 'paper',
      strictness: MarkingStrictness.balanced,
      referenceVersion: 1,
      references: [
        MarkingReference(position: 1, maximumScore: maximum, prompt: title),
      ],
    );
  }

  @override
  Future<MarkingReferencesSaved> saveReferences(
    String assessmentId, {
    MarkingStrictness? strictness,
    List<MarkingReferenceUpdate> updates = const [],
  }) async {
    final current = await references(assessmentId);
    var changed = strictness != null && strictness != current.strictness;
    final next = [
      for (final reference in current.references)
        _apply(
          reference,
          updates
              .where((u) => u.questionId == reference.questionId)
              .firstOrNull,
          () => changed = true,
        ),
    ];
    for (final reference in next) {
      if (keyPointMarks(reference.keyPoints) > reference.maximumScore ||
          reference.keyPoints.length > maxMarkingKeyPoints) {
        throw const MarkingRefusal(MarkingProblem.invalid);
      }
    }
    final version = current.referenceVersion + (changed ? 1 : 0);
    final saved = MarkingReferences(
      delivery: current.delivery,
      strictness: strictness ?? current.strictness,
      referenceVersion: version,
      references: next,
    );
    _references[assessmentId] = saved;
    return MarkingReferencesSaved(
      references: saved,
      changed: changed,
      staleSuggestions: (_suggestions[assessmentId] ?? const [])
          .where(
            (s) =>
                s.status == MarkingSuggestionStatus.ready &&
                s.referenceVersion < version,
          )
          .length,
    );
  }

  static MarkingReference _apply(
    MarkingReference r,
    MarkingReferenceUpdate? u,
    void Function() changed,
  ) {
    if (u == null || u.isEmpty) return r;
    String? text(String? value, String? old) {
      if (value == null) return old;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final next = MarkingReference(
      questionId: r.questionId,
      position: r.position,
      kind: r.kind,
      prompt: r.prompt,
      maximumScore: r.maximumScore,
      options: r.options,
      correctOptionIds: r.correctOptionIds,
      correctChoice: r.correctChoice,
      acceptedAnswers: r.acceptedAnswers,
      preferredAnswer: text(u.preferredAnswer, r.preferredAnswer),
      markingGuidance: text(u.markingGuidance, r.markingGuidance),
      keyPoints: u.keyPoints ?? r.keyPoints,
      acceptedMethods: text(u.acceptedMethods, r.acceptedMethods),
      partialCredit: text(u.partialCredit, r.partialCredit),
    );
    if (next.preferredAnswer != r.preferredAnswer ||
        next.markingGuidance != r.markingGuidance ||
        next.acceptedMethods != r.acceptedMethods ||
        next.partialCredit != r.partialCredit ||
        !_samePoints(next.keyPoints, r.keyPoints)) {
      changed();
    }
    return next;
  }

  static bool _samePoints(List<MarkingKeyPoint> a, List<MarkingKeyPoint> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  @override
  Future<MarkingSuggestions> suggestions(String assessmentId) async {
    final current = await references(assessmentId);
    return MarkingSuggestions(
      strictness: current.strictness,
      referenceVersion: current.referenceVersion,
      items: [
        for (final s
            in _suggestions[assessmentId] ?? const <MarkingSuggestion>[])
          MarkingSuggestion(
            id: s.id,
            studentId: s.studentId,
            attemptId: s.attemptId,
            questionId: s.questionId,
            submissionAttemptId: s.submissionAttemptId,
            status: s.status,
            maximumScore: s.maximumScore,
            suggestedScore: s.suggestedScore,
            met: s.met,
            missed: s.missed,
            rationale: s.rationale,
            feedback: s.feedback,
            conflict: s.conflict,
            reviewReason: s.reviewReason,
            reason: s.reason,
            referenceVersion: s.referenceVersion,
            strictness: s.strictness,
            stale: s.stale || s.referenceVersion < current.referenceVersion,
          ),
      ],
    );
  }

  @override
  Future<MarkingRun> requestSuggestions(
    String assessmentId, {
    bool all = false,
    List<String>? studentIds,
  }) async {
    if (!currentPlan.available) {
      throw const MarkingRefusal(MarkingProblem.unavailable);
    }
    if (!currentPlan.active) {
      throw const MarkingRefusal(MarkingProblem.planRequired);
    }
    return const MarkingRun(queued: 0, optedOut: 0, replaced: 0);
  }

  @override
  Future<void> dismiss(String suggestionId) async {
    for (final list in _suggestions.values) {
      list.removeWhere((s) => s.id == suggestionId);
    }
  }

  @override
  Future<bool> optedOut() async => _optedOut;

  @override
  Future<bool> setOptedOut(bool optedOut) async => _optedOut = optedOut;
}
