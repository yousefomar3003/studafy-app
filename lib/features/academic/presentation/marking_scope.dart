import 'package:flutter/widgets.dart';

import '../domain/marking.dart';

/// Studafy AI Marking for every screen that marks work (ADR-0046).
///
/// The marking screens are opened from many places - Today, the gradebook,
/// a class - so the composition root provides the slice once, above the
/// navigator, rather than threading it through each of them. Where none is
/// provided nothing about suggestions is shown, and marking works as it
/// always did.
class MarkingScope extends InheritedWidget {
  const MarkingScope({super.key, required this.services, required super.child});

  final MarkingServices services;

  static MarkingServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkingScope>()?.services;

  @override
  bool updateShouldNotify(MarkingScope oldWidget) =>
      services != oldWidget.services;
}
