import 'package:flutter/foundation.dart';

/// A tap on a push notification, waiting for the app to open it.
///
/// It carries only the id of the in-app notification the push was sent for,
/// as the push itself does. What the notification is about is read through
/// the API, as whoever is signed in when it is opened.
@immutable
class NotificationTap {
  const NotificationTap(this.notificationId);

  /// Null when the push named none (one sent before pushes carried it); the
  /// app then opens the notifications list.
  final String? notificationId;
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
  void tapped(String? notificationId) {
    final id = notificationId?.trim();
    final valid =
        id != null &&
        id.isNotEmpty &&
        id.length <= 64 &&
        RegExp(r'^[A-Za-z0-9-]+$').hasMatch(id);
    _pending = NotificationTap(valid ? id : null);
    notifyListeners();
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
