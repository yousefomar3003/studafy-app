import '../../../core/idempotency.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/marking.dart';
import '../domain/online_assessment.dart';

/// Studafy AI Marking over `/v1` (ADR-0046): the teacher's references and
/// suggested marks, the plan, and a student's opt-out.
///
/// Nothing here writes a mark. Suggestions only fill the teacher's own
/// fields; the existing marking routes stay the only writers.
class ApiMarkingRepository
    implements MarkingRepository, MarkingPreferenceRepository {
  ApiMarkingRepository(this._client);

  final V1ApiClient _client;
  final _keys = PendingIdempotencyKeys();

  /// A refusal the screen can act on; anything else keeps its meaning.
  static Future<T> _refusing<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on V1ApiException catch (error) {
      final problem = switch (error.code) {
        'AI_FEATURE_DISABLED' => MarkingProblem.unavailable,
        'PLAN_REQUIRED' => MarkingProblem.planRequired,
        'FORBIDDEN' || 'NOT_FOUND' => MarkingProblem.notAllowed,
        'INVALID_STATE' => MarkingProblem.nothingToRead,
        'INVALID_REQUEST' => MarkingProblem.invalid,
        _ => null,
      };
      if (problem == null) rethrow;
      throw MarkingRefusal(problem);
    }
  }

  Future<T> _run<T>(String fingerprint, Future<T> Function(String key) call) =>
      _refusing(() => _keys.run('marking', fingerprint, call));

  @override
  Future<MarkingPlan> plan() => _refusing(() async {
    final dto = await _client.getMyMarkingPlan();
    final allowance = dto.allowance;
    return MarkingPlan(
      active: dto.active,
      teacher: dto.teacher,
      available: dto.available,
      used: (allowance['used'] as num?)?.toInt() ?? 0,
      total: (allowance['total'] as num?)?.toInt() ?? 0,
      resetsAt:
          DateTime.tryParse(allowance['resetsAt'] as String? ?? '') ??
          DateTime.now(),
    );
  });

  @override
  Future<MarkingReferences> references(String assessmentId) =>
      _refusing(() async {
        final dto = await _client.getMarkingReferences(
          assessmentId: assessmentId,
        );
        return _references(dto.delivery, dto.settings, dto.references);
      });

  @override
  Future<MarkingReferencesSaved> saveReferences(
    String assessmentId, {
    MarkingStrictness? strictness,
    List<MarkingReferenceUpdate> updates = const [],
  }) {
    final request = V1UpdateMarkingReferencesRequestDto(
      strictness: strictness?.wire,
      references: updates.isEmpty
          ? null
          : [
              for (final update in updates)
                V1MarkingReferenceUpdateDto(
                  questionId: update.questionId,
                  preferredAnswer: update.preferredAnswer,
                  markingGuidance: update.markingGuidance,
                  keyPoints: update.keyPoints == null
                      ? null
                      : [
                          for (final point in update.keyPoints!)
                            V1MarkingKeyPointDto(
                              text: point.text,
                              marks: point.marks,
                            ),
                        ],
                  acceptedMethods: update.acceptedMethods,
                  partialCredit: update.partialCredit,
                ),
            ],
    );
    return _run('references:$assessmentId:${request.toJson()}', (key) async {
      final dto = await _client.updateMarkingReferences(
        request,
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
      // The delivery does not change with a save; the read said it.
      final online = dto.references.any((r) => r.questionId != null);
      return MarkingReferencesSaved(
        references: _references(
          online ? 'online' : 'paper',
          dto.settings,
          dto.references,
        ),
        changed: dto.changed,
        staleSuggestions: dto.staleSuggestions,
      );
    });
  }

  @override
  Future<MarkingSuggestions> suggestions(String assessmentId) =>
      _refusing(() async {
        final dto = await _client.listMarkingSuggestions(
          assessmentId: assessmentId,
        );
        return MarkingSuggestions(
          strictness: MarkingStrictness.fromWire(dto.settings.strictness),
          referenceVersion: dto.settings.referenceVersion,
          items: [for (final item in dto.items) _suggestion(item)],
        );
      });

  @override
  Future<MarkingRun> requestSuggestions(
    String assessmentId, {
    bool all = false,
    List<String>? studentIds,
  }) {
    final request = V1RequestMarkingSuggestionsRequestDto(
      scope: all ? 'all' : 'unmarked',
      studentIds: studentIds == null || studentIds.isEmpty ? null : studentIds,
    );
    return _run('request:$assessmentId:${request.toJson()}', (key) async {
      final dto = await _client.requestMarkingSuggestions(
        request,
        assessmentId: assessmentId,
        idempotencyKey: key,
      );
      return MarkingRun(
        queued: dto.queued,
        optedOut: dto.optedOut,
        replaced: dto.replaced,
      );
    });
  }

  @override
  Future<void> dismiss(String suggestionId) => _run(
    'dismiss:$suggestionId',
    (key) => _client.dismissMarkingSuggestion(
      const V1DismissMarkingSuggestionRequestDto(),
      suggestionId: suggestionId,
      idempotencyKey: key,
    ),
  );

  @override
  Future<bool> optedOut() async =>
      (await _client.getMyMarkingPreference()).optedOut;

  @override
  Future<bool> setOptedOut(bool optedOut) => _run(
    'preference:$optedOut',
    (key) async => (await _client.updateMyMarkingPreference(
      V1UpdateMarkingPreferenceRequestDto(optedOut: optedOut),
      idempotencyKey: key,
    )).optedOut,
  );

  static MarkingReferences _references(
    String delivery,
    V1MarkingSettingsDto settings,
    List<V1MarkingReferenceDto> references,
  ) => MarkingReferences(
    delivery: delivery,
    strictness: MarkingStrictness.fromWire(settings.strictness),
    referenceVersion: settings.referenceVersion,
    references: [
      for (final r in references)
        MarkingReference(
          questionId: r.questionId,
          position: r.position,
          kind: r.kind == null || r.kind == 'hand_in'
              ? null
              : QuestionKind.fromWire(r.kind),
          prompt: r.prompt,
          maximumScore: r.maximumScore.toDouble(),
          options: [
            for (final o in r.options) QuestionOption(id: o.id, text: o.text),
          ],
          correctOptionIds: r.correctOptionIds,
          correctChoice: r.correctChoice,
          acceptedAnswers: r.acceptedAnswers,
          preferredAnswer: r.preferredAnswer,
          markingGuidance: r.markingGuidance,
          keyPoints: [
            for (final point in r.keyPoints)
              MarkingKeyPoint(text: point.text, marks: point.marks?.toDouble()),
          ],
          acceptedMethods: r.acceptedMethods,
          partialCredit: r.partialCredit,
        ),
    ],
  );

  static MarkingSuggestion _suggestion(V1MarkingSuggestionDto s) =>
      MarkingSuggestion(
        id: s.id,
        studentId: s.studentId,
        attemptId: s.attemptId,
        questionId: s.questionId,
        submissionAttemptId: s.submissionAttemptId,
        status: MarkingSuggestionStatus.fromWire(s.status),
        maximumScore: s.maximumScore.toDouble(),
        suggestedScore: s.suggestedScore?.toDouble(),
        met: s.met,
        missed: s.missed,
        rationale: s.rationale,
        feedback: s.feedback,
        conflict: s.conflict,
        reviewReason: MarkingReviewReason.fromWire(s.reviewReason),
        reason: s.reason,
        referenceVersion: s.referenceVersion,
        strictness: MarkingStrictness.fromWire(s.strictness),
        stale: s.stale,
      );
}
