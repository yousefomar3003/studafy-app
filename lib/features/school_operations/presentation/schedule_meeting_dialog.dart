import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';

/// The shape of a Google Meet link; the server enforces the same.
final _meetLink = RegExp(
  r'^https://meet\.google\.com/[A-Za-z0-9-]{3,64}(\?[A-Za-z0-9=&._-]{0,200})?$',
);

/// What the teacher chose when scheduling a class meeting.
class MeetingDraft {
  const MeetingDraft({
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.meetUrl,
  });

  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  /// `guardians`, `students` or `class`.
  final String audience;

  /// The Google Meet link the teacher created and pasted.
  final Uri meetUrl;
}

/// Asks for a meeting: title, day and time, length, who is invited, and the
/// Google Meet link. Null when the teacher cancels or leaves the title empty.
Future<MeetingDraft?> showScheduleMeetingDialog(
  BuildContext context,
  AppL10n l10n, {
  required Future<bool> Function(Uri url) openLink,
}) async {
  final title = TextEditingController();
  var starts = DateTime.now().add(const Duration(days: 1));
  var duration = 30;
  var audience = 'guardians';
  final link = TextEditingController();
  String? linkError;
  final ok =
      await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text(l10n.classroomAdminScheduleMeeting),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: l10n.announcementTitleLabel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.classroomAdminStarts),
                    subtitle: Text(studafyFullDate(context, starts)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: starts,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (d != null) {
                        setDialog(
                          () => starts = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            starts.hour,
                            starts.minute,
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    title: Text(l10n.classroomAdminTime),
                    subtitle: Text(
                      TimeOfDay.fromDateTime(starts).format(context),
                    ),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(starts),
                      );
                      if (time != null && context.mounted) {
                        setDialog(
                          () => starts = DateTime(
                            starts.year,
                            starts.month,
                            starts.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: duration,
                    decoration: InputDecoration(
                      labelText: l10n.classroomAdminDuration,
                    ),
                    items: [30, 45, 60, 90]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v ${l10n.classroomAdminMinutes}'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => duration = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    decoration: InputDecoration(
                      labelText: l10n.classroomAdminAudience,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'guardians',
                        child: Text(l10n.schoolAdminGuardians),
                      ),
                      DropdownMenuItem(
                        value: 'students',
                        child: Text(l10n.announcementAudienceStudents),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text(l10n.classroomAdminWholeClass),
                      ),
                    ],
                    onChanged: (v) => setDialog(() => audience = v!),
                  ),
                  const SizedBox(height: 12),
                  // Studafy does not host the call. The teacher makes it in
                  // Google Meet and hands over the link.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          openLink(Uri.parse('https://meet.google.com/new')),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(l10n.classroomAdminCreateItInGoogleMeet),
                    ),
                  ),
                  TextField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.classroomAdminGoogleMeetLink,
                      hintText: 'https://meet.google.com/abc-defg-hij',
                      errorText: linkError,
                      suffixIcon: IconButton(
                        tooltip: l10n.joinClassPaste,
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = data?.text?.trim();
                          if (text != null && text.isNotEmpty) {
                            setDialog(() => link.text = text);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.academicCancel),
              ),
              FilledButton(
                onPressed: () {
                  // Checked here, not only by the server, so the teacher
                  // fixes the link without losing the rest of the form.
                  if (!_meetLink.hasMatch(link.text.trim())) {
                    setDialog(
                      () => linkError = l10n.classroomAdminPasteALinkThatStarts,
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: Text(l10n.classroomAdminSchedule),
              ),
            ],
          ),
        ),
      ) ??
      false;
  if (!ok || title.text.trim().isEmpty) return null;
  return MeetingDraft(
    title: title.text,
    startsAt: starts,
    endsAt: starts.add(Duration(minutes: duration)),
    audience: audience,
    meetUrl: Uri.parse(link.text.trim()),
  );
}
