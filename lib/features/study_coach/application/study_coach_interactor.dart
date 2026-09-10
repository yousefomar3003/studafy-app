import '../domain/study_coach_repository.dart';

/// Application policy stays independent of Supabase and fails closed for
/// attachments before an adapter can perform network or storage work.
class StudyCoachInteractor {
  const StudyCoachInteractor({required this.repository});

  final StudyCoachRepository repository;

  Future<String> ask({required String question, String? attachmentPath}) async {
    if (attachmentPath != null) {
      throw StateError('File attachments are temporarily unavailable.');
    }
    return repository.ask(question: question);
  }

  Future<List<StudyQuizQuestion>> quiz({
    required String classroomId,
    required String topic,
  }) => repository.quiz(classroomId: classroomId, topic: topic);

  Future<List<StudyFlashcard>> flashcards({
    required String classroomId,
    required String topic,
  }) => repository.flashcards(classroomId: classroomId, topic: topic);
}
