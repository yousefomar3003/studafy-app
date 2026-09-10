import '../domain/study_coach_repository.dart';

final class UnavailableStudyCoachRepository implements StudyCoachRepository {
  const UnavailableStudyCoachRepository();

  Never get _unavailable =>
      throw StateError('Study Coach requires a connected remote backend.');

  @override
  Future<String> ask({required String question}) async => _unavailable;

  @override
  Future<List<StudyQuizQuestion>> quiz({
    required String classroomId,
    required String topic,
  }) async => _unavailable;

  @override
  Future<List<StudyFlashcard>> flashcards({
    required String classroomId,
    required String topic,
  }) async => _unavailable;
}
