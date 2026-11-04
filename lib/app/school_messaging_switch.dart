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
///
/// A student in classes from several teachers is in each teacher's school
/// (every teacher's workspace is a school of its own): messaging is on for
/// them when any of those schools has it on, and the server still decides
/// per school whom they may write to.
mixin SchoolMessagingSwitch<T extends StatefulWidget> on State<T> {
  bool _messagingOn = false;
  String? _messagingReadFor;

  /// True once the member's school has said messaging is on.
  bool get messagingOn => MessagingScope.isAvailable(context) && _messagingOn;

  /// Reads the switch for the member's current schools, once per change.
  /// Safe to call from `build`: it does nothing until the schools change.
  void readMessagingSwitch() {
    if (!MessagingScope.isAvailable(context)) return;
    final context_ = ActiveContextController.instance;
    final schoolIds = context_.membership == null
        ? const <String>[]
        : context_.schoolIds;
    final readFor = schoolIds.isEmpty ? null : schoolIds.join(',');
    if (readFor == _messagingReadFor) return;
    _messagingReadFor = readFor;
    if (readFor == null) {
      _messagingOn = false;
      return;
    }
    final messaging = MessagingScope.of(context);
    unawaited(
      Future.wait([
        for (final schoolId in schoolIds)
          messaging
              .messagingEnabled(schoolId)
              .then(
                (result) =>
                    result.fold(onSuccess: (on) => on, onFailure: (_) => false),
              ),
      ]).then((answers) {
        if (!mounted || _messagingReadFor != readFor) return;
        final on = answers.any((on) => on);
        if (on != _messagingOn) setState(() => _messagingOn = on);
      }),
    );
  }
}
