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

abstract interface class StudyCoachRepository {
  Future<String> ask({required String question});

  Future<List<StudyQuizQuestion>> quiz({
    required String classroomId,
    required String topic,
  });

  Future<List<StudyFlashcard>> flashcards({
    required String classroomId,
    required String topic,
  });
}
