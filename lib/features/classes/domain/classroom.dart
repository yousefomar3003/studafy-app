import 'package:flutter/foundation.dart';

import '../../../core/ids.dart';

/// Typed classroom summary for the teacher's class list (ARC-011 classes
/// slice). `grade` is a string because the authoritative remote column is
/// text; the legacy preview integer is converted inside the preview adapter.
@immutable
class ClassroomSummary {
  const ClassroomSummary({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    this.room,
    this.colorValue,
    required this.studentCount,
    this.weeklySessions,
    this.termName,
  });

  final ClassroomId id;
  final String name;
  final String grade;
  final String section;

  /// Human-readable room label from the authoritative classroom aggregate.
  final String? room;

  /// ARGB color used by the preview fixture cards; null on remote.
  final int? colorValue;

  final int studentCount;
  final int? weeklySessions;
  final String? termName;
}

/// One weekly session slot of a new classroom draft.
@immutable
class ClassSessionDraft {
  const ClassSessionDraft({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  /// 1–7, Monday–Sunday.
  final int weekday;

  /// 'HH:mm' local wall-clock.
  final String startTime;
  final String endTime;
}

/// Draft for creating a classroom through either the authoritative API or the
/// isolated synthetic preview adapter.
@immutable
class NewClassDraft {
  const NewClassDraft({
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.firstSessionStart,
    required this.firstSessionEnd,
    required this.weeklySessions,
    required this.sessions,
  });

  final String name;
  final int grade;
  final String section;
  final String room;
  final String firstSessionStart;
  final String firstSessionEnd;
  final int weeklySessions;
  final List<ClassSessionDraft> sessions;
}
