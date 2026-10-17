import 'package:flutter/widgets.dart';

/// System back on a home screen with tabs, as Android does it.
///
/// From the first tab, back leaves the app as it always has. From any other
/// tab it returns to the first one (or wherever [onBack] says) instead of
/// closing the app on whatever the person was in the middle of.
///
/// It is a [PopScope], so it only ever sees back when the tabs are the page
/// on top: a page pushed over them handles back itself and pops as usual.
class TabBackScope extends StatelessWidget {
  const TabBackScope({
    super.key,
    required this.atFirstTab,
    required this.onBack,
    required this.child,
  });

  /// Whether back should leave the screen, as it does from the first tab.
  final bool atFirstTab;

  /// What back does from any other tab; usually, going to the first tab.
  final VoidCallback onBack;

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: atFirstTab,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) onBack();
    },
    child: child,
  );
}
