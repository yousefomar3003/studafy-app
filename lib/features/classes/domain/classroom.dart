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
    this.legacyLocalId,
  });

  final ClassroomId id;
  final String name;
  final String grade;
  final String section;

  /// Room label; the remote schema has no room column yet.
  final String? room;

  /// ARGB color used by the preview fixture cards; null on remote.
  final int? colorValue;

  final int studentCount;
  final int? weeklySessions;
  final String? termName;

  /// Local SQLite id, kept only to bridge into the legacy class workspace
  /// until that screen is migrated (documented slice-2 debt).
  final int? legacyLocalId;

  /// Bridge map for the legacy `ClassWorkspacePage`. Remove when the
  /// workspace is migrated behind this repository.
  Map<String, Object?> toLegacyMap() => {
    'id': legacyLocalId ?? 0,
    'name': name,
    'grade': int.tryParse(grade) ?? 0,
    'section': section,
    'room': room ?? 'TBD',
    'color': colorValue ?? 0xFF241D73,
    'student_count': studentCount,
    'weekly_sessions': weeklySessions ?? 1,
    if (legacyLocalId == null) 'remote_id': id.value,
  };
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

/// Draft for creating a classroom. Preview-only until the classes write path
/// exists behind the API; remote adapters answer [UnsupportedFailure]-style
/// errors instead of silently faking a write.
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
