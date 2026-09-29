import '../domain/meetings.dart';

/// Synthetic builds have no meetings.
class PreviewMeetingsRepository implements MeetingsRepository {
  const PreviewMeetingsRepository();

  @override
  Future<List<UpcomingMeeting>> upcoming() async => const [];
}
