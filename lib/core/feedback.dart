import 'package:flutter/material.dart';

/// Short confirmations and errors, shown the same way on every screen.
extension StudafyMessages on ScaffoldMessengerState {
  /// Shows [text] at the bottom of the screen for a few seconds.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMessage(
    String text,
  ) => showSnackBar(SnackBar(content: Text(text)));
}
