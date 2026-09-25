/// One exchange with the study assistant.
class StudyAnswer {
  const StudyAnswer({required this.answer, required this.remainingToday});

  final String answer;

  /// Questions left in today's allowance, so the app can warn before the
  /// student hits the limit rather than after.
  final int remainingToday;
}

/// Asks the study assistant a question.
///
/// The question is the entire request. Nothing about the student, their
/// class, their marks or their school is sent, and nothing is read from the
/// device to build it - the server holds the provider credential and adds the
/// instructions.
abstract class StudyAssistantRepository {
  Future<StudyAnswer> ask(String question);
}
