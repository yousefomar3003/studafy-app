import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/study_assistant_repository.dart';

class ApiStudyAssistantRepository implements StudyAssistantRepository {
  ApiStudyAssistantRepository(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final V1ApiClient _client;
  final DateTime Function() _now;

  /// The most any one turn may carry, as the server's schema allows.
  static const _turnChars = 4000;

  /// Sent when the plan cannot be read: the server trims to the real budget
  /// anyway, this only keeps the request small.
  static const _fallbackMemoryChars = 8000;

  int? _memoryChars;
  DateTime? _memoryReadAt;

  /// How much of a chat the plan remembers. Re-read every few minutes, so a
  /// plan bought or ended mid-session takes effect.
  Future<int> _memory() async {
    final readAt = _memoryReadAt;
    if (_memoryChars != null &&
        readAt != null &&
        _now().difference(readAt) < const Duration(minutes: 5)) {
      return _memoryChars!;
    }
    try {
      final plan = await _client.getStudyPlan();
      _memoryChars = plan.chatMemoryChars ?? _fallbackMemoryChars;
    } on Object {
      _memoryChars ??= _fallbackMemoryChars;
    }
    _memoryReadAt = _now();
    return _memoryChars!;
  }

  /// The newest whole turns that fit [budgetChars], oldest first.
  static List<ChatTurn> _fit(List<ChatTurn> history, int budgetChars) {
    var used = 0;
    var start = history.length;
    while (start > 0) {
      final next = history[start - 1].text.length.clamp(0, _turnChars);
      if (used + next > budgetChars) break;
      used += next;
      start--;
    }
    return history.sublist(start);
  }

  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async {
    final recent = history.isEmpty
        ? const <ChatTurn>[]
        : _fit(history, await _memory());
    try {
      final response = await _client.askStudyAssistant(
        V1StudyAssistantAskRequestDto(
          question: question,
          history: recent.isEmpty
              ? null
              : [
                  for (final turn in recent)
                    {
                      'role': turn.role.name,
                      'text': turn.text.length > _turnChars
                          ? turn.text.substring(0, _turnChars)
                          : turn.text,
                    },
                ],
          references: references.isEmpty
              ? null
              : [
                  for (final reference in references)
                    {'kind': reference.kind.name, 'id': reference.id},
                ],
          attachmentFileIds: photoFileIds.isEmpty ? null : photoFileIds,
        ),
      );
      return StudyAnswer(
        answer: response.answer,
        remainingToday: response.remainingToday,
      );
    } on V1ApiException catch (error) {
      throw _failure(error) ?? error;
    }
  }

  static Failure? _failure(V1ApiException error) {
    if (error.code == StudyAssistantFailure.photoNotReady) {
      return const Failure(
        StudyAssistantFailure.photoNotReady,
        'The photo is still being checked.',
      );
    }
    if (error.code == StudyAssistantFailure.planRequired) {
      return const Failure(
        StudyAssistantFailure.planRequired,
        'Photos need Studafy Plus.',
      );
    }
    if (error.code == 'AI_FEATURE_DISABLED') {
      return const Failure(
        StudyAssistantFailure.unavailable,
        'The study helper is not available.',
      );
    }
    if (error.code == StudyAssistantFailure.dailyLimit) {
      return const Failure(
        StudyAssistantFailure.dailyLimit,
        "Today's questions are used.",
      );
    }
    // A server with no AI provider does not mount the route at all, so the
    // question comes back 404 - not a missing record.
    if (error.status == 404 || error.status == 503) {
      return const Failure(
        StudyAssistantFailure.unavailable,
        'The study helper is not available.',
      );
    }
    return null;
  }
}
