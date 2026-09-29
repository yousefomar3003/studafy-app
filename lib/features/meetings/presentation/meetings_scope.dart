import 'package:flutter/material.dart';

import '../domain/meetings.dart';

/// Makes the meetings list reachable from any home screen that shows it.
class MeetingsScope extends InheritedWidget {
  const MeetingsScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final MeetingsRepository repository;

  static MeetingsRepository? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MeetingsScope>()?.repository;

  @override
  bool updateShouldNotify(MeetingsScope oldWidget) =>
      repository != oldWidget.repository;
}
