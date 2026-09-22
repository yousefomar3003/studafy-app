import 'package:flutter/widgets.dart';

/// Claims the OAuth callback that the provider browser hands back to the app.
///
/// The callback is delivered twice. The Supabase client takes one copy and
/// exchanges the code for a session; the other reaches Flutter's own route
/// handling as route information. Nothing routes `"/login-callback?code=..."`,
/// so `WidgetsApp` pushed it as a named route and threw
/// `Could not find a generator for route` on every single sign-in.
///
/// Reporting the callback as handled here stops that push. This observer is
/// registered before `runApp`, so it sits ahead of the one `WidgetsApp`
/// installs and is consulted first. The session still arrives the only way it
/// ever did, through the auth stream.
class OAuthCallbackGuard extends WidgetsBindingObserver {
  OAuthCallbackGuard();

  /// Whether [uri] is a provider callback rather than a place to navigate to.
  ///
  /// Covers the PKCE code, the implicit-flow token in the fragment, and the
  /// provider's error reply — a cancelled or refused sign-in must not push a
  /// route either.
  static bool isCallback(Uri uri) {
    final query = uri.queryParameters;
    return query.containsKey('code') ||
        query.containsKey('error') ||
        uri.fragment.contains('access_token') ||
        uri.fragment.contains('error=');
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    if (isCallback(routeInformation.uri)) return true;
    return super.didPushRouteInformation(routeInformation);
  }
}
