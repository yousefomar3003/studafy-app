import 'package:flutter/material.dart';

/// Closes the on-screen keyboard the way people expect on a phone: a tap
/// outside any text field, or dragging a page. Flutter's text fields only
/// let go of focus on a tap outside when a mouse is used, and the number
/// pads used for marks have no Done key, so without this a teacher typing a
/// mark could not close the keyboard to reach Save or Publish.
///
/// Wraps the whole app (`MaterialApp.builder`). A tap on a button, a field
/// or anything else that handles taps itself still goes to it; only a tap
/// nothing else claims closes the keyboard. Scrolling inside a text field
/// (a long answer) leaves the keyboard open.
class KeyboardDismissal extends StatelessWidget {
  const KeyboardDismissal({super.key, required this.child});

  /// `MaterialApp.builder`'s child, which is null only before routing.
  final Widget? child;

  static void _dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  static bool _insideTextField(BuildContext? context) =>
      context?.findAncestorStateOfType<EditableTextState>() != null;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: _dismiss,
    child: NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        // Only a person's drag: a field scrolled into view when the
        // keyboard opens must not close it again.
        if (notification.dragDetails != null &&
            !_insideTextField(notification.context)) {
          _dismiss();
        }
        return false;
      },
      child: child ?? const SizedBox.shrink(),
    ),
  );
}
