import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/runtime_environment.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Loads the existing API's widget page. Never carries access tokens or secrets.
class FamilyChallengePage extends StatefulWidget {
  const FamilyChallengePage({super.key, required this.url});
  final Uri url;
  @override
  State<FamilyChallengePage> createState() => _FamilyChallengePageState();
}

class _FamilyChallengePageState extends State<FamilyChallengePage> {
  WebViewController? _controller;
  bool _failed = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.url;
    final local = plainHttpAllowedFor(
      url.host,
      production:
          StudafyRuntime.policy.environment == StudafyEnvironment.production,
    );
    if ((url.scheme != 'https' && !(url.scheme == 'http' && local)) ||
        url.userInfo.isNotEmpty ||
        url.path != '/auth/bot-check') {
      _failed = true;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'StudafyChallenge',
        onMessageReceived: (message) {
          if (!_completed &&
              mounted &&
              message.message.isNotEmpty &&
              message.message.length <= 2048) {
            _completed = true;
            Navigator.pop(context, message.message);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null ||
                !target.hasAuthority ||
                !['http', 'https'].contains(target.scheme)) {
              return NavigationDecision.prevent;
            }
            if (request.isMainFrame) {
              return target.origin == url.origin &&
                      target.path == '/auth/bot-check'
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            }
            return target.scheme == 'https' &&
                    target.host == 'challenges.cloudflare.com'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
          onHttpError: (error) {
            if (error.request?.uri == widget.url && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppL10n.of(context).familyChallengeSecurityCheck),
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppL10n.of(context).familyChallengeTheCheckCouldNotLoad,
                ),
              ),
            )
          : WebViewWidget(controller: _controller!),
    );
  }
}

/// Whether the security check may be loaded over plain HTTP from [host].
///
/// Only this device or a private network (a development API on the same
/// Wi-Fi, as the phone build uses), and never in production, where the page
/// must come over HTTPS.
bool plainHttpAllowedFor(String host, {required bool production}) {
  if (['localhost', '127.0.0.1'].contains(host)) return true;
  if (production) return false;
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
    return false;
  }
  final [a, b, _, _] = parts.cast<int>();
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}
