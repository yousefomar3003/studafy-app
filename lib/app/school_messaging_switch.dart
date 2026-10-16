import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/studafy_domain.dart';
import '../features/messaging/presentation/messaging_scope.dart';

/// Whether the school a member (a teacher or a student) is acting in has
/// messaging switched on, read from the school's content controls - the
/// switch the server enforces on every new conversation and message
/// (DL-049).
///
/// Off until the school says it is on, and off when it cannot be read: the
/// app offers no way into messaging that the server would refuse. A guardian
/// holds no membership; their shell reads the same switch from each child's
/// link instead.
mixin SchoolMessagingSwitch<T extends StatefulWidget> on State<T> {
  bool _messagingOn = false;
  String? _messagingReadFor;

  /// True once the member's school has said messaging is on.
  bool get messagingOn => MessagingScope.isAvailable(context) && _messagingOn;

  /// Reads the switch for the member's current school, once per school.
  /// Safe to call from `build`: it does nothing until the school changes.
  void readMessagingSwitch() {
    if (!MessagingScope.isAvailable(context)) return;
    final schoolId = ActiveContextController.instance.membership?.schoolId;
    if (schoolId == _messagingReadFor) return;
    _messagingReadFor = schoolId;
    if (schoolId == null) {
      _messagingOn = false;
      return;
    }
    final read = MessagingScope.of(context).messagingEnabled(schoolId);
    unawaited(
      read.then((result) {
        if (!mounted || _messagingReadFor != schoolId) return;
        final on = result.fold(onSuccess: (on) => on, onFailure: (_) => false);
        if (on != _messagingOn) setState(() => _messagingOn = on);
      }),
    );
  }
}
