import 'dart:async';

import '../core/studafy_domain.dart';

/// Picks up store purchases for whichever account is signed in: at
/// sign-in, and again after a switch to another account on the device.
///
/// Access itself follows the Studafy account on every device, because the
/// server holds the entitlement. This covers the purchase the server has not
/// verified yet - the app closed between the store sheet and verification,
/// or a new phone - by listening to the store as soon as someone signs in.
class StoreSyncBinder {
  StoreSyncBinder({required this.resume, ActiveContextController? context})
    : _context = context ?? ActiveContextController.instance {
    _context.addListener(_changed);
    _changed();
  }

  final Future<void> Function() resume;
  final ActiveContextController _context;
  String? _resumedFor;

  void _changed() {
    final userId = _context.profile?.id;
    if (userId == null || userId == _resumedFor) {
      if (userId == null) _resumedFor = null;
      return;
    }
    _resumedFor = userId;
    unawaited(resume().catchError((Object _) {}));
  }

  void dispose() => _context.removeListener(_changed);
}
