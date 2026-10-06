import 'package:flutter/widgets.dart';

/// An [IndexedStack] that builds each tab the first time it is shown, then
/// keeps it, as [IndexedStack] does, so its scroll position and loaded data
/// survive switching away and back.
///
/// A role's home has four or five tabs, and every one loads from the server
/// as it is built. Building them all at once made opening the app wait on
/// every tab's requests, though only the first is on screen.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.builtAhead = const {},
  });

  final int index;
  final List<Widget> children;

  /// Tabs built from the start anyway, for a page that works while out of
  /// sight (the inbox says "delivered" for the whole session). Such a page
  /// must not load its content until it is shown.
  final Set<int> builtAhead;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _shown = {};

  @override
  Widget build(BuildContext context) {
    _shown.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (final (index, child) in widget.children.indexed)
          _shown.contains(index) || widget.builtAhead.contains(index)
              ? child
              : const SizedBox.shrink(),
      ],
    );
  }
}
