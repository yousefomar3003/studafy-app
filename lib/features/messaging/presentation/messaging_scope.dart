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

/// The signed-in person and the school they are acting in, if any.
///
/// The school is nullable on purpose. Listing and reading conversations is
/// self-scoped and spans every school (`conversation.list` is not tenant
/// bound), so it needs no school at all; only picking new recipients and
/// starting a conversation do, because the contact policy is per school.
///
/// Requiring a school here is what made messaging dead for guardians: they
/// hold no membership, so this returned null and the page rendered "no
/// school" instead of the conversations the server was perfectly willing to
/// serve them.
({String userId, String? schoolId})? messagingIdentity() {
  final context = ActiveContextController.instance;
  final userId = context.profile?.id;
  if (userId == null) return null;
  return (userId: userId, schoolId: context.activeSchoolId);
}
