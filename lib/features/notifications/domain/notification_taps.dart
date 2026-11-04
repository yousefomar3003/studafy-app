import 'package:flutter/foundation.dart';

/// A tap on a push notification, waiting for the app to open it.
///
/// It carries only what the push itself does: the id of the in-app
/// notification it was sent for, and the id of the account it was sent to.
/// What the notification is about is read through the API, as that account.
@immutable
class NotificationTap {
  const NotificationTap(this.notificationId, {this.recipientId});

  /// Null when the push named none (one sent before pushes carried it); the
  /// app then opens the notifications list.
  final String? notificationId;

  /// The account the push was sent to. A phone can be signed in to several
  /// accounts and gets each one's pushes (DL-082), so a tap for an account
  /// that is not the current one switches to it first, and one for an
  /// account no longer on the phone is ignored. Null for a push sent before
  /// pushes named their account: it opens as whoever is signed in.
  final String? recipientId;
}

/// Holds a tapped push until the app has somewhere to open it.
///
/// A tap can arrive before anyone is signed in (a cold start from the
/// notification), during an account switch, or while a dialog is open, so it
/// is published here rather than acted on: the signed-in shell takes it with
/// [consume] when it can open it, and [defer]s it when it cannot yet. One tap
/// opens one screen.
class NotificationTaps extends ChangeNotifier {
  NotificationTap? _pending;

  /// The tap waiting to be opened, or null.
  NotificationTap? get pending => _pending;

  /// Publishes a tap. Anything that is not a plain id is dropped and the tap
  /// opens the notifications list instead: the push payload comes from
  /// outside the app.
  void tapped(String? notificationId, {String? recipientId}) {
    _pending = NotificationTap(
      _plainId(notificationId),
      recipientId: _plainId(recipientId),
    );
    notifyListeners();
  }

  /// Opens a tap meant for another account on this phone: switches to that
  /// account, when the phone still has it, so its own shell opens the tap.
  /// Set by the app, which knows the phone's accounts; while unset, such a
  /// tap is dropped rather than opened as the wrong account.
  Future<void> Function(NotificationTap tap)? anotherAccount;

  static String? _plainId(String? value) {
    final id = value?.trim();
    final valid =
        id != null &&
        id.isNotEmpty &&
        id.length <= 64 &&
        RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id);
    return valid ? id : null;
  }

  /// Takes the waiting tap, so it is opened once.
  NotificationTap? consume() {
    final tap = _pending;
    _pending = null;
    return tap;
  }

  /// Puts a taken tap back without announcing it, for whoever can open it
  /// next. A newer tap that arrived in the meantime wins.
  void defer(NotificationTap tap) => _pending ??= tap;
}
