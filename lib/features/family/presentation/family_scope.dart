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

  /// Null when no scope is installed, for screens that show a family
  /// detail as an extra rather than depending on one.
  static FamilyInteractor? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FamilyScope>()?.interactor;

  static FamilyInteractor of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FamilyScope>();
    if (scope == null) throw StateError('FamilyScope is missing.');
    return scope.interactor;
  }

  @override
  bool updateShouldNotify(FamilyScope oldWidget) =>
      interactor != oldWidget.interactor;
}
