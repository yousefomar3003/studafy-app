import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/studafy_design.dart';

/// Whether the first frame is held back until the wordmarks are decoded.
bool _firstFrameHeld = false;

/// Runs [app], keeping the native launch screen up until [BrandPrecache]
/// has decoded the wordmarks, so the splash appears whole instead of its
/// tagline first and the wordmark a moment later. Never longer than two
/// seconds, whatever happens to the images.
void runAppAfterBrand(Widget app) {
  if (!_firstFrameHeld) {
    WidgetsBinding.instance.deferFirstFrame();
    _firstFrameHeld = true;
    Timer(const Duration(seconds: 2), _releaseFirstFrame);
  }
  runApp(app);
}

void _releaseFirstFrame() {
  if (!_firstFrameHeld) return;
  _firstFrameHeld = false;
  WidgetsBinding.instance.allowFirstFrame();
}

/// Decodes both wordmarks as soon as the app has a MediaQuery (it sits in
/// the app's builder), then lets a held first frame through.
class BrandPrecache extends StatefulWidget {
  const BrandPrecache({super.key, this.child});

  final Widget? child;

  @override
  State<BrandPrecache> createState() => _BrandPrecacheState();
}

class _BrandPrecacheState extends State<BrandPrecache> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // precacheImage reports a failed load and completes; it never throws.
    unawaited(
      precacheStudafyWordmarks(context).whenComplete(_releaseFirstFrame),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
