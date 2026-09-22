import 'package:flutter/widgets.dart';

import '../core/class_join_link.dart';

/// Claims a tapped class join link and holds its token for the app to act on.
///
/// Two jobs, and the first is not optional: nothing routes
/// `io.studafy.app://join?t=...`, so without claiming it here `WidgetsApp`
/// would push it as a named route and throw, exactly as the OAuth callback
/// used to. Shipping a link format without this would mean every student who
/// tapped one met a crash.
///
/// The token is published rather than acted on, because a link can arrive
/// before there is a navigator to show anything: the app reads [pendingToken]
/// when it is ready and clears it with [consume].
class ClassJoinLinkGuard extends WidgetsBindingObserver {
  ClassJoinLinkGuard();

  /// The token from the most recent tapped link, or null when none is
  /// waiting. Listenable so the app can react whenever one arrives.
  final ValueNotifier<String?> pendingToken = ValueNotifier<String?>(null);

  /// Takes the waiting token, clearing it so one tap opens one screen.
  String? consume() {
    final token = pendingToken.value;
    pendingToken.value = null;
    return token;
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    if (!isClassJoinLink(uri)) {
      return super.didPushRouteInformation(routeInformation);
    }
    pendingToken.value = uri.queryParameters[classJoinTokenParameter];
    return true;
  }
}
