import 'backend.dart';

class StudyQuizQuestion {
  const StudyQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
  final String prompt;
  final List<String> options;
  final int correctIndex;
}

class StudyFlashcard {
  const StudyFlashcard({required this.front, required this.back});
  final String front;
  final String back;
}

class StudyCoachRepository {
  Future<String> ask({required String question, String? attachmentPath}) async {
    if (attachmentPath != null) {
      throw StateError('File attachments are temporarily unavailable.');
    }
    final data = await _invoke({'action': 'ask', 'question': question});
    return data['answer'] as String;
  }

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
      throw StateError('Study Coach requires a connected production backend.');
    }
    final response = await StudafyBackend.client.functions.invoke(
      'study-coach',
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      final message = response.data is Map
          ? (response.data as Map)['error']
          : null;
      throw StateError(
        message?.toString() ?? 'Study Coach is temporarily unavailable.',
      );
    }
    return (response.data as Map).cast<String, dynamic>();
  }
}
