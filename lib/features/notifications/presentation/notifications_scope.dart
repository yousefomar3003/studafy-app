import 'package:flutter/widgets.dart';

import '../application/notifications_interactor.dart';

/// Injects the notifications interactor above the app Navigator, including
/// pushed routes — the badge lives in a header widget reused across many
/// screens, and the list page is pushed ad hoc, so neither can receive it as
/// a constructor argument the way a single shell root could.
class NotificationsScope extends InheritedWidget {
  const NotificationsScope({
    super.key,
    required this.interactor,
    required super.child,
  });

  final NotificationsInteractor interactor;

  static NotificationsInteractor of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<NotificationsScope>();
    if (scope == null) {
      throw StateError('NotificationsScope is missing.');
    }
    return scope.interactor;
  }

  @override
  bool updateShouldNotify(NotificationsScope oldWidget) =>
      interactor != oldWidget.interactor;
}
