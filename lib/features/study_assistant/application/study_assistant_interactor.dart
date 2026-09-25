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

  Future<Result<StudyAnswer>> ask(String question) async {
    final result = await runCatching(() => repository.ask(question));
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
