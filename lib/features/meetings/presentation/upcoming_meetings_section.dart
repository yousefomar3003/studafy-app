import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/meetings.dart';
import 'meetings_scope.dart';

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
    this.refreshToken = 0,
  });

  /// Falls back to [MeetingsScope].
  final MeetingsRepository? repository;
  final MeetingLauncher launch;

  /// Overrides the clock. Tests supply their own.
  final DateTime Function()? now;

  /// Changed by the host when the person pulls to refresh, so the meetings
  /// are read again with the rest of the page.
  final int refreshToken;

  @override
  State<UpcomingMeetingsSection> createState() =>
      _UpcomingMeetingsSectionState();
}

class _UpcomingMeetingsSectionState extends State<UpcomingMeetingsSection> {
  Future<List<UpcomingMeeting>>? _meetings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _meetings ??= _read();
  }

  @override
  void didUpdateWidget(UpcomingMeetingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _meetings = _read();
  }

  Future<List<UpcomingMeeting>> _read() {
    final repository = widget.repository ?? MeetingsScope.maybeOf(context);
    return repository == null
        ? Future.value(const <UpcomingMeeting>[])
        : Future.sync(repository.upcoming);
  }

  Future<void> _join(UpcomingMeeting meeting) async {
    final url = meeting.meetUrl;
    if (url == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).meetingsGoogleMeetCouldNotBe;
    final opened = await widget.launch(url);
    if (!opened) messenger.showMessage(failed);
  }

  // The section arrives after the page around it, so it grows into place
  // rather than shoving everything below it down in one jump.
  @override
  Widget build(BuildContext context) => StudafyAnimatedSize(
    duration: const Duration(milliseconds: 220),
    alignment: AlignmentDirectional.topStart,
    child: _section(context),
  );

  Widget _section(BuildContext context) => FutureBuilder<List<UpcomingMeeting>>(
    future: _meetings,
    builder: (context, snapshot) {
      final meetings = snapshot.data ?? const <UpcomingMeeting>[];
      if (snapshot.hasError || meetings.isEmpty) {
        return const SizedBox.shrink();
      }
      final now = (widget.now ?? DateTime.now)();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(AppL10n.of(context).meetingsUpcomingMeetings),
          for (final meeting in meetings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
                child: Row(
                  children: [
                    IconBadge(
                      icon: meeting.isCancelled
                          ? Icons.event_busy_rounded
                          : Icons.videocam_rounded,
                      color: meeting.isCancelled ? studafyMuted : studafyTeal,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserContentText(
                            meeting.title,
                            style: const TextStyle(
                              color: studafyInk,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          UserContentText(
                            meeting.classroomName,
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            studafyDateTime(context, meeting.startsAt),
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 13,
                            ),
                          ),
                          if (meeting.isCancelled)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: StatusPill(
                                label: AppL10n.of(context).meetingsCancelled,
                                icon: Icons.event_busy_rounded,
                                color: studafyDanger,
                              ),
                            )
                          else if (meeting.meetUrl == null)
                            Text(
                              AppL10n.of(context).meetingsTheLinkWillAppearHere,
                              style: const TextStyle(
                                color: studafyMuted,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (meeting.canJoin(now))
                      FilledButton(
                        onPressed: () => _join(meeting),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(AppL10n.of(context).meetingsJoin),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
