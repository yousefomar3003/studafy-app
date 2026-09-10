import '../../../data/backend.dart';
import '../domain/study_coach_repository.dart';

final class SupabaseStudyCoachRepository implements StudyCoachRepository {
  const SupabaseStudyCoachRepository();

  @override
  Future<String> ask({required String question}) async {
    final data = await _invoke({'action': 'ask', 'question': question});
    return data['answer'] as String;
  }

  @override
  Future<List<StudyQuizQuestion>> quiz({
    required String classroomId,
    required String topic,
  }) async {
    final data = await _invoke({
      'action': 'quiz',
      'classroom_id': classroomId,
      'topic': topic,
    });
    return (data['questions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => StudyQuizQuestion(
            prompt: row['prompt'] as String,
            options: (row['options'] as List<dynamic>).cast<String>(),
            correctIndex: row['correct_index'] as int,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<StudyFlashcard>> flashcards({
    required String classroomId,
    required String topic,
  }) async {
    final data = await _invoke({
      'action': 'flashcards',
      'classroom_id': classroomId,
      'topic': topic,
    });
    return (data['cards'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => StudyFlashcard(
            front: row['front'] as String,
            back: row['back'] as String,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    if (!StudafyBackend.isRemote) {
      throw StateError('Study Coach requires a connected remote backend.');
    }
    final response = await StudafyBackend.client.functions.invoke(
      'study-coach',
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Study Coach is temporarily unavailable.');
    }
    if (response.data is! Map) {
      throw StateError('Study Coach returned an invalid response.');
    }
    return (response.data as Map).cast<String, dynamic>();
  }
}
