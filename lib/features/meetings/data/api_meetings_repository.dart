import '../../../data/contracts/v1_client.generated.dart';
import '../domain/meetings.dart';

class ApiMeetingsRepository implements MeetingsRepository {
  const ApiMeetingsRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<List<UpcomingMeeting>> upcoming() async {
    final page = await _client.listMeetings();
    return [
      for (final item in page.items)
        UpcomingMeeting(
          id: item.id,
          classroomName: item.classroomName,
          title: item.title,
          startsAt: DateTime.parse(item.startsAt).toLocal(),
          endsAt: DateTime.parse(item.endsAt).toLocal(),
          state: item.state,
          meetUrl: _safeLink(item.meetUrl),
        ),
    ];
  }

  /// The server only stores meet.google.com links; checked again here so a
  /// link that somehow is not one is shown as no link rather than opened.
  static Uri? _safeLink(String? value) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host != 'meet.google.com') {
      return null;
    }
    return uri;
  }
}
