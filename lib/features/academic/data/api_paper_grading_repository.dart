import '../../../core/studafy_domain.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/studafy_repository.dart';

/// API-041 parity replacement for the former grade-review Edge invocations.
/// AI proposal/upload remains disabled until AI-072 and FILE-050/051.
class ApiPaperGradingRepository implements PaperGradingRepository {
  ApiPaperGradingRepository(this._client);

  final V1ApiClient _client;
  final Map<String, String> _pendingKeys = {};

  @override
  Future<AiGradingDraft> proposeGrade({
    required String submissionId,
    required Uri privateScan,
    required GradingStrictness strictness,
  }) async {
    throw StateError('AI grading is temporarily unavailable.');
  }

  @override
  Future<void> reviewDraft({
    required String gradeResultId,
    required int expectedVersion,
    required String draftId,
    required List<QuestionSuggestion> finalScores,
  }) async {
    final key = _key('review:$gradeResultId:$expectedVersion');
    await _client.reviewGradeResult(
      V1ReviewGradeRequestDto(
        expectedVersion: expectedVersion,
        score: finalScores.fold(0, (sum, value) => sum + value.proposedScore),
        feedback: null,
        draftId: draftId,
        questionScores: [
          for (final score in finalScores)
            V1QuestionScoreReviewDto(
              questionId: score.questionId,
              score: score.proposedScore,
              reason: score.rationale.trim().isEmpty ? null : score.rationale,
            ),
        ],
      ),
      gradeResultId: gradeResultId,
      idempotencyKey: key,
    );
    _pendingKeys.remove('review:$gradeResultId:$expectedVersion');
  }

  @override
  Future<void> publishGradeResult({
    required String gradeResultId,
    required int expectedVersion,
  }) async {
    final fingerprint = 'publish:$gradeResultId:$expectedVersion';
    await _client.publishGradeResult(
      V1VersionCommandRequestDto(expectedVersion: expectedVersion),
      gradeResultId: gradeResultId,
      idempotencyKey: _key(fingerprint),
    );
    _pendingKeys.remove(fingerprint);
  }

  String _key(String fingerprint) => _pendingKeys.putIfAbsent(
    fingerprint,
    () =>
        'grade-${DateTime.now().microsecondsSinceEpoch}-${fingerprint.hashCode.abs()}',
  );
}
