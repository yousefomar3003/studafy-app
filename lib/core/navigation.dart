import 'package:flutter/widgets.dart';

/// How soon after a page opens a second push is taken to be the same tap
/// again. Long enough to cover the opening animation and two loads that
/// finish together; short enough that nobody can deliberately open a page
/// and then tap something on it inside it.
const _repeatWindow = Duration(milliseconds: 700);

final _lastPush = Expando<({Route<Object?> route, DateTime at})>();

/// Opening a page once per tap.
///
/// A tap on a slow connection gives no feedback until the next page is on
/// screen, so people tap again - and every tap pushed another copy of the
/// page, which read as the app reloading itself. Every page in the app is
/// opened through [pushOnce], which ignores a push while the page pushed
/// from this navigator a moment ago is still the one on top.
extension PushOnce on NavigatorState {
  Future<T?> pushOnce<T extends Object?>(Route<T> route) {
    final last = _lastPush[this];
    final now = DateTime.now();
    if (last != null &&
        last.route.isCurrent &&
        now.difference(last.at) < _repeatWindow) {
      return Future<T?>.value();
    }
    _lastPush[this] = (route: route, at: now);
    return push(route);
  }
}
