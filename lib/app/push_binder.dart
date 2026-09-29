import 'dart:async';

import '../core/studafy_domain.dart';
import '../features/notifications/domain/push_registrar.dart';

/// Registers the phone for push for whichever account is signed in: at
/// sign-in, and again after a switch to another account on the device, so
/// each account kept here gets its own notifications.
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
