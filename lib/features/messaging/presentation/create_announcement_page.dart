import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../application/messaging_interactor.dart';
import '../domain/messaging.dart';

/// One class a teacher may announce to.
///
/// Its own type rather than the classes slice's summary, because features may
/// not import each other; the composition root maps its list into this.
@immutable
class AnnouncementTarget {
  const AnnouncementTarget({required this.id, required this.name});

  final String id;
  final String name;
}

/// Writing an announcement for a class.
///
/// Scoped to a classroom rather than the whole school: a school-wide post is
/// an administrator's to make, and the surface refuses a teacher who tries.
class CreateAnnouncementPage extends StatefulWidget {
  const CreateAnnouncementPage({
    super.key,
    required this.messaging,
    required this.schoolId,
    required this.classes,
    this.initialClassroomId,
  });

  final MessagingInteractor messaging;
  final String schoolId;
  final List<AnnouncementTarget> classes;
  final String? initialClassroomId;

  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _classroomId;
  AnnouncementAudience _audience = AnnouncementAudience.both;
  bool _important = false;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classroomId =
        widget.initialClassroomId ??
        (widget.classes.length == 1 ? widget.classes.single.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String _audienceLabel(AppL10n l10n, AnnouncementAudience audience) =>
      switch (audience) {
        AnnouncementAudience.students => l10n.announcementAudienceStudents,
        AnnouncementAudience.guardians => l10n.announcementAudienceGuardians,
        AnnouncementAudience.both => l10n.announcementAudienceBoth,
      };

  Future<void> _post() async {
    if (_posting) return;
    final l10n = AppL10n.of(context);
    final classroomId = _classroomId;
    final String? problem = switch (null) {
      _ when classroomId == null => l10n.announcementClassRequired,
      _ when _title.text.trim().isEmpty => l10n.announcementTitleRequired,
      _ when _body.text.trim().isEmpty => l10n.announcementBodyRequired,
      _ => null,
    };
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    final posted = l10n.announcementPosted;
    final failed = l10n.announcementFailed;
    final result = await widget.messaging.postAnnouncement(
      AnnouncementDraft(
        schoolId: widget.schoolId,
        classroomId: classroomId,
        title: _title.text.trim(),
        body: _body.text.trim(),
        audience: _audience,
        important: _important,
      ),
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => Navigator.of(context).pop(posted),
      onFailure: (failure) => setState(() {
        _posting = false;
        // The surface's own reason where it has one, since "you may not post
        // school-wide" is worth reading; the generic line otherwise.
        _error = failure.message.isEmpty ? failed : failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.announcementNewTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classroomId,
              decoration: InputDecoration(
                labelText: l10n.announcementClassLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final target in widget.classes)
                  DropdownMenuItem(value: target.id, child: Text(target.name)),
              ],
              onChanged: _posting
                  ? null
                  : (value) => setState(() => _classroomId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_posting,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.announcementTitleLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _body,
              enabled: !_posting,
              minLines: 4,
              maxLines: 10,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: l10n.announcementBodyLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.announcementAudienceLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final audience in AnnouncementAudience.values)
                  ChoiceChip(
                    label: Text(_audienceLabel(l10n, audience)),
                    selected: _audience == audience,
                    onSelected: _posting
                        ? null
                        : (_) => setState(() => _audience = audience),
                  ),
              ],
            ),
            SwitchListTile(
              value: _important,
              onChanged: _posting
                  ? null
                  : (value) => setState(() => _important = value),
              title: Text(l10n.announcementImportantLabel),
              subtitle: Text(l10n.announcementImportantDetail),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _posting ? null : _post,
              child: Text(
                _posting ? l10n.announcementPosting : l10n.announcementPost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
