import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/parent/data/unavailable_parent_repository.dart';
import 'package:studafy/features/parent/domain/parent_repository.dart';
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
}
