import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    final local = ['localhost', '127.0.0.1'].contains(url.host);
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
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تحقق سريع' : 'Security check')),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ar
                      ? 'تعذر تحميل التحقق. ارجع وحاول مرة أخرى.'
                      : 'The check could not load. Go back and try again.',
                ),
              ),
            )
          : WebViewWidget(controller: _controller!),
    );
  }
}
