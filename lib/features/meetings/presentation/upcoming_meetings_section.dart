import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
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

/// Opens [url] in Google Meet, or the browser where the app is not installed.
typedef MeetingLauncher = Future<bool> Function(Uri url);

Future<bool> _launch(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Upcoming meetings for the person signed in, each with a Join button.
///
/// Renders nothing when there are none or the list cannot be loaded: this
/// sits on a home screen, and an empty or failed section is noise there.
class UpcomingMeetingsSection extends StatefulWidget {
  const UpcomingMeetingsSection({
    super.key,
    this.repository,
    this.launch = _launch,
    this.now,
  });

  /// Falls back to [MeetingsScope].
  final MeetingsRepository? repository;
  final MeetingLauncher launch;

  /// Overrides the clock. Tests supply their own.
  final DateTime Function()? now;

  @override
  State<UpcomingMeetingsSection> createState() =>
      _UpcomingMeetingsSectionState();
}

class _UpcomingMeetingsSectionState extends State<UpcomingMeetingsSection> {
  Future<List<UpcomingMeeting>>? _meetings;

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = widget.repository ?? MeetingsScope.maybeOf(context);
    _meetings ??= repository == null
        ? Future.value(const <UpcomingMeeting>[])
        : Future.sync(repository.upcoming);
  }

  String _when(DateTime start) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(start)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start))}';
  }

  Future<void> _join(UpcomingMeeting meeting) async {
    final url = meeting.meetUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = _t(
      'Google Meet could not be opened.',
      'تعذّر فتح Google Meet.',
    );
    final opened = await widget.launch(url);
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<UpcomingMeeting>>(
    future: _meetings,
    builder: (context, snapshot) {
      final meetings = snapshot.data ?? const <UpcomingMeeting>[];
      if (snapshot.hasError || meetings.isEmpty) {
        return const SizedBox.shrink();
      }
      final now = (widget.now ?? DateTime.now)();
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                _t('Upcoming meetings', 'الاجتماعات القادمة'),
                style: const TextStyle(
                  color: studafyInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final meeting in meetings)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    meeting.isCancelled
                        ? Icons.event_busy_outlined
                        : Icons.videocam_outlined,
                  ),
                  title: UserContentText(meeting.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserContentText(meeting.classroomName),
                      Text(_when(meeting.startsAt)),
                      if (meeting.isCancelled)
                        Text(
                          _t('Cancelled', 'أُلغي'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (meeting.meetUrl == null)
                        Text(
                          _t('The link will appear here.', 'سيظهر الرابط هنا.'),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: meeting.canJoin(now)
                      ? FilledButton(
                          onPressed: () => _join(meeting),
                          child: Text(_t('Join', 'انضمام')),
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    },
  );
}
