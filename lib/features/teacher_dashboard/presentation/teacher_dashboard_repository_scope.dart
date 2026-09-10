import 'package:flutter/widgets.dart';

import '../domain/teacher_dashboard_repository.dart';

class TeacherDashboardRepositoryScope extends InheritedWidget {
  const TeacherDashboardRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final TeacherDashboardRepository repository;

  static TeacherDashboardRepository read(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<TeacherDashboardRepositoryScope>();
    if (scope == null) {
      throw StateError('TeacherDashboardRepositoryScope is missing.');
    }
    return scope.repository;
  }

  @override
  bool updateShouldNotify(TeacherDashboardRepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
