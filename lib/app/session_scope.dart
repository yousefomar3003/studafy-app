import 'package:flutter/material.dart';

import '../features/session/application/session_interactor.dart';
import 'account_scope.dart';

/// Provides the session interactor to shared account screens. Composed at
/// the app root, above the Navigator, beside [AccountScope].
class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});

  final SessionInteractor session;

  static SessionInteractor? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()?.session;

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      session != oldWidget.session;
}
