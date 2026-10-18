import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation.dart';
import '../../../core/studafy_domain.dart';
import '../domain/notification.dart';
import '../domain/notification_taps.dart';
import 'notifications_page.dart';
import 'notifications_scope.dart';

/// Opens a tapped push notification in the signed-in shell, the way a tap
/// on the same notification in the in-app list does.
///
/// Each shell wraps itself in one, with the same [onOpen] it gives its
/// notifications list. A tap names the in-app notification (nothing else);
/// it is looked up in the signed-in account's feed, marked read, and handed
/// to [onOpen], which switches to the tab it is about. When there is no id,
/// the notification is not this account's, or [onOpen] cannot open it, the
/// notifications list opens instead.
///
/// The tap is only taken by the shell of the account signed in when that
/// shell was built: during an account switch the outgoing shell leaves it
/// for the incoming one, and a switch that completes while the lookup is in
/// flight hands the tap on rather than opening the old account's screen.
class NotificationTapOpener extends StatefulWidget {
  const NotificationTapOpener({
    super.key,
    this.onOpen,
    this.activeContext,
    required this.child,
  });

  /// What the shell's notifications list does with a tapped item. Null for
  /// a shell whose list only marks items read; a tap then opens the list.
  final bool Function(NotificationItem item)? onOpen;

  /// Who is signed in; the app-wide controller when null.
  final ActiveContextController? activeContext;

  final Widget child;

  @override
  State<NotificationTapOpener> createState() => _NotificationTapOpenerState();
}

class _NotificationTapOpenerState extends State<NotificationTapOpener> {
  late final ActiveContextController _activeContext =
      widget.activeContext ?? ActiveContextController.instance;

  /// The account this shell was built for. Read when it is built, not on
  /// first use, which could be after a switch.
  late final String? _account;
  NotificationTaps? _taps;
  bool _opening = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _account = _activeContext.profile?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final taps = NotificationsScope.tapsOf(context);
    if (taps == _taps) return;
    _taps?.removeListener(_open);
    _taps = taps?..addListener(_open);
    // A cold start from a tap has published it before this shell existed,
    // so the listener alone would never fire for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _retry?.cancel();
    _taps?.removeListener(_open);
    super.dispose();
  }

  Future<void> _open() async {
    final taps = _taps;
    if (_opening || !mounted || taps == null || taps.pending == null) return;
    final account = _activeContext.profile?.id;
    // Signed out, or this shell belongs to an account being switched away
    // from: whoever is signed in next opens it in their own shell.
    if (account == null || account != _account) return;
    final shell = ModalRoute.of(context);
    if (shell == null) return;
    final tap = taps.consume();
    if (tap == null) return;
    _opening = true;
    try {
      await _show(tap, taps, shell);
    } finally {
      _opening = false;
    }
  }

  Future<void> _show(
    NotificationTap tap,
    NotificationTaps taps,
    ModalRoute<Object?> shell,
  ) async {
    final interactor = NotificationsScope.maybeOf(context);
    final id = tap.notificationId;
    NotificationItem? item;
    if (id != null && interactor != null) {
      item = (await interactor.find(id))
          .fold(onSuccess: (found) => found, onFailure: (_) => null);
    }
    if (!mounted || _activeContext.profile?.id != _account) {
      // The account changed while looking: the next one looks again, in its
      // own feed, rather than this one opening the old account's screen.
      taps.defer(tap);
      return;
    }
    // Back to the shell, as a tap on the list does: past pages, but never
    // past a dialog or sheet (an account switch's progress, a confirmation)
    // or a page that would lose what was typed on it.
    final navigator = Navigator.of(context);
    Route<Object?>? top;
    navigator.popUntil((route) {
      final stop =
          route == shell ||
          route is PopupRoute ||
          route.popDisposition == RoutePopDisposition.doNotPop;
      if (stop) top = route;
      return stop;
    });
    if (top is PopupRoute) {
      // Opened over a dialog, the dialog's owner would close the wrong
      // route. Wait for it to go.
      taps.defer(tap);
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 1), _open);
      return;
    }
    final open = widget.onOpen;
    if (item != null && open != null && shell.isCurrent) {
      // As the list does: read first, then open what it is about.
      if (!item.isRead) unawaited(interactor!.markRead(item.id));
      if (open(item)) return;
    }
    unawaited(
      navigator.pushOnce(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsPage(onOpen: open),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
