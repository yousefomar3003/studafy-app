import '../../../data/contracts/v1_client.generated.dart';
import '../domain/study_assistant_repository.dart';

class ApiStudyAssistantRepository implements StudyAssistantRepository {
  ApiStudyAssistantRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<StudyAnswer> ask(String question) async {
    final response = await _client.askStudyAssistant(
      V1StudyAssistantAskRequestDto(question: question),
    );
    return StudyAnswer(
      answer: response.answer,
      remainingToday: response.remainingToday,
    );
  }
}
