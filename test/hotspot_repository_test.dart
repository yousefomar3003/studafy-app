import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/parent/data/unavailable_parent_repository.dart';
import 'package:studafy/features/parent/domain/parent_repository.dart';
import 'package:studafy/features/study_coach/application/study_coach_interactor.dart';
import 'package:studafy/features/study_coach/domain/study_coach_repository.dart';
import 'package:studafy/features/teacher_dashboard/data/unavailable_teacher_dashboard_repository.dart';
import 'package:studafy/features/teacher_dashboard/domain/teacher_dashboard_repository.dart';

void main() {
  test(
    'remote parent placeholder fails closed without falling back to SQLite',
    () {
      const repository = UnavailableParentRepository();
      expect(
        repository.linkedChildren(),
        throwsA(isA<ParentFeatureUnavailable>()),
      );
    },
  );

  test('remote teacher placeholder fails closed without preview records', () {
    const repository = UnavailableTeacherDashboardRepository();
    expect(
      repository.attendanceRoster('Biology · Grade 10 B'),
      throwsA(isA<TeacherDashboardUnavailable>()),
    );
  });

  test('Study Coach attachment policy stops before the data adapter', () async {
    final repository = _RecordingStudyCoachRepository();
    final interactor = StudyCoachInteractor(repository: repository);

    await expectLater(
      interactor.ask(
        question: 'Inspect this file',
        attachmentPath: 'coach/another-user/private.pdf',
      ),
      throwsA(isA<StateError>()),
    );
    expect(repository.invocations, 0);
  });
}

final class _RecordingStudyCoachRepository implements StudyCoachRepository {
  int invocations = 0;

  @override
  Future<String> ask({required String question}) async {
    invocations++;
    return 'unused';
  }

  @override
  Future<List<StudyFlashcard>> flashcards({
    required String classroomId,
    required String topic,
  }) async {
    invocations++;
    return const [];
  }

  @override
  Future<List<StudyQuizQuestion>> quiz({
    required String classroomId,
    required String topic,
  }) async {
    invocations++;
    return const [];
  }
}
