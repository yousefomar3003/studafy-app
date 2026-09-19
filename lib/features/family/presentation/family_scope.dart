import 'package:flutter/widgets.dart';

import '../application/family_interactor.dart';

/// Injects the family interactor above the Navigator.
class FamilyScope extends InheritedWidget {
  const FamilyScope({
    super.key,
    required this.interactor,
    required super.child,
  });

  final FamilyInteractor interactor;

  static FamilyInteractor of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FamilyScope>();
    if (scope == null) throw StateError('FamilyScope is missing.');
    return scope.interactor;
  }

  @override
  bool updateShouldNotify(FamilyScope oldWidget) =>
      interactor != oldWidget.interactor;
}
