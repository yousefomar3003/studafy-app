import 'package:flutter/foundation.dart';

/// A meeting someone was invited to.
///
/// Studafy does not host the call. The teacher creates it in Google Meet and
/// gives Studafy the link; this is what the people invited need to join it.
@immutable
class UpcomingMeeting {
  const UpcomingMeeting({
    required this.id,
    required this.classroomName,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.state,
    this.meetUrl,
  });

  final String id;
  final String classroomName;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  /// scheduled, pending, cancelled or failed.
  final String state;

  /// Null until the meeting has a link to join.
  final Uri? meetUrl;

  bool get isCancelled => state == 'cancelled' || state == 'failed';

  /// Joinable: has a link, is not cancelled, and has not ended.
  bool canJoin(DateTime now) =>
      meetUrl != null && !isCancelled && endsAt.isAfter(now);
}

abstract interface class MeetingsRepository {
  /// Meetings the signed-in person was invited to, soonest first.
  Future<List<UpcomingMeeting>> upcoming();
}
