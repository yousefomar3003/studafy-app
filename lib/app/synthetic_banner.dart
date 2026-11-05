import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';

/// The strip across the top of a synthetic (test-data) build, so nobody
/// mistakes it for the real app.
class SyntheticBanner extends StatelessWidget {
  const SyntheticBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: const Color(0xFFFFE0A3),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 30,
            child: Center(
              child: Text(
                AppL10n.of(context).syntheticBanner,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF5E3B00),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
