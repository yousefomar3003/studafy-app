import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/study_assistant_repository.dart';

class StudyAssistantInteractor {
  const StudyAssistantInteractor({
    required this.repository,
    required this.telemetry,
  });

  final StudyAssistantRepository repository;
  final Telemetry telemetry;

  /// [history] is the chat so far, oldest first; the repository sends only
  /// its last few turns.
  Future<Result<StudyAnswer>> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
    String? requestId,
    String? language,
  }) async {
    final result = await runCatching(
      () => repository.ask(
        question,
        history: history,
        references: references,
        photoFileIds: photoFileIds,
        requestId: requestId,
        language: language,
      ),
    );
    // The question and the answer are both deliberately absent: one is a
    // child's words, the other is what a third party said back.
    result.fold(
      onSuccess: (_) => telemetry.event('study_assistant_answered', const {}),
      onFailure: (failure) =>
          telemetry.event('study_assistant_failed', {'code': failure.code}),
    );
    return result;
  }
}
