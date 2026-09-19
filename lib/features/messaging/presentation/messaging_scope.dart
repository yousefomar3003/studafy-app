import 'package:flutter/widgets.dart';

import '../../../core/studafy_domain.dart';
import '../application/messaging_interactor.dart';

/// Injects the messaging interactor above the Navigator so every pushed
/// messaging route can reach it.
class MessagingScope extends InheritedWidget {
  const MessagingScope({
    super.key,
    required this.interactor,
    required super.child,
  });

  final MessagingInteractor interactor;

  static MessagingInteractor of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MessagingScope>();
    if (scope == null) throw StateError('MessagingScope is missing.');
    return scope.interactor;
  }

  /// True when a scope exists, so shared shells can hide the entry point in
  /// builds that do not provide messaging.
  static bool isAvailable(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MessagingScope>() != null;

  @override
  bool updateShouldNotify(MessagingScope oldWidget) =>
      interactor != oldWidget.interactor;
}

/// The signed-in person and their active school, from the session context.
({String userId, String schoolId})? messagingIdentity() {
  final context = ActiveContextController.instance;
  final userId = context.profile?.id;
  final schoolId = context.membership?.schoolId;
  if (userId == null || schoolId == null) return null;
  return (userId: userId, schoolId: schoolId);
}
