import 'package:flutter/widgets.dart';

import '../application/study_coach_interactor.dart';

class StudyCoachScope extends InheritedWidget {
  const StudyCoachScope({
    super.key,
    required this.interactor,
    required super.child,
  });

  final StudyCoachInteractor interactor;

  static StudyCoachInteractor read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StudyCoachScope>();
    if (scope == null) throw StateError('StudyCoachScope is missing.');
    return scope.interactor;
  }

  @override
  bool updateShouldNotify(StudyCoachScope oldWidget) =>
      interactor != oldWidget.interactor;
}
