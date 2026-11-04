import 'dart:async';

import '../core/studafy_domain.dart';
import '../features/notifications/domain/push_registrar.dart';

/// Registers the phone for push for whichever account is signed in: at
/// sign-in, and again after a switch to another account on the device, so
/// each account kept here gets its own notifications.
///
/// A switch never takes the phone off the account switched away from: the
/// server keeps one registration per account (DL-082), so every account
/// that has been open on this phone keeps getting its pushes until it signs
/// out of the phone. Only the account signed in can register itself - the
/// others' saved sessions are not spent in the background, since each use
/// rotates them - so an account added before this change, or one whose
/// token Firebase replaced, is registered again the next time it is open.
class PushBinder {
  PushBinder({required this.registrar, ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance {
    _context.addListener(_changed);
    _changed();
  }

  final PushRegistrar registrar;
  final ActiveContextController _context;
  String? _registeredFor;

  void _changed() {
    final userId = _context.profile?.id;
    if (userId == null || userId == _registeredFor) {
      if (userId == null) _registeredFor = null;
      return;
    }
    _registeredFor = userId;
    unawaited(registrar.register());
  }

  void dispose() => _context.removeListener(_changed);
}
