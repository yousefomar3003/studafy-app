import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/result.dart';
import '../../../core/studafy_design.dart';
import '../application/class_list_interactor.dart';
import '../domain/classroom.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Typed teacher class list (ARC-011 classes slice).
///
/// Reads through [ClassListInteractor] only — no SQL, no provider client, no
/// dynamic maps. The header and the legacy workspace navigation are injected
/// by the app shell so this feature never imports other features.
class ClassesPage extends StatefulWidget {
  const ClassesPage({
    super.key,
    required this.classes,
    required this.onOpenClassroom,
    this.header,
  });

  final ClassListInteractor classes;

  /// Opens the (still legacy) class workspace; the shell builds the bridge.
  /// Completing it means the workspace closed, so the list can refresh.
  final Future<void> Function(ClassroomSummary classroom) onOpenClassroom;

  /// Optional app-supplied header; defaults to a minimal title header.
  final Widget? header;

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  Future<Result<List<ClassroomSummary>>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = widget.classes.loadClasses();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      widget.header ?? const _ClassesTitleHeader(),
      Expanded(
        child: FutureBuilder<Result<List<ClassroomSummary>>>(
          future: _future,
          builder: (context, snapshot) {
            final result = snapshot.data;
            final classrooms = result?.fold(
              onSuccess: (value) => value,
              onFailure: (_) => const <ClassroomSummary>[],
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        AppL10n.of(context).classesTitle,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _createClass(context),
                      icon: const Icon(Icons.add),
                      label: Text(AppL10n.of(context).classesCreate),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),
                if (result != null && result.isFailure)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: Text(
                      result.fold(
                        onSuccess: (_) => '',
                        onFailure: (failure) => failure.message,
                      ),
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
                for (final classroom
                    in classrooms ?? const <ClassroomSummary>[])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 12),
                    child: _ClassCard(
                      classroom: classroom,
                      onTap: () async {
                        await widget.onOpenClassroom(classroom);
                        _refresh();
                      },
                      onInvite: () => _invite(context, classroom),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Future<void> _createClass(BuildContext context) async {
    final name = TextEditingController();
    final room = TextEditingController();
    int grade = 10;
    String section = 'A';
    int weeklySessions = 1;
    String? createFailure;
    final sessions = <ClassSessionDraft>[
      ClassSessionDraft(weekday: 1, startTime: '08:00', endTime: '08:50'),
    ];
    final dayNames = studafyWeekdayNames(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(AppL10n.of(dialogContext).classesCreateTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: AppL10n.of(dialogContext).classesNameLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: room,
                  decoration: InputDecoration(
                    labelText: AppL10n.of(dialogContext).classesRoomLabel,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: grade,
                        decoration: InputDecoration(
                          labelText: AppL10n.of(dialogContext)
                              .classesGradeLabel,
                        ),
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              AppL10n.of(dialogContext)
                                  .classesGradeOption(i + 1),
                            ),
                          ),
                        ),
                        onChanged: (v) => setDialog(() => grade = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: section,
                        decoration: InputDecoration(
                          labelText: AppL10n.of(dialogContext)
                              .classesSectionLabel,
                        ),
                        items: ['A', 'B', 'C', 'D']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setDialog(() => section = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: weeklySessions,
                  decoration: InputDecoration(
                    labelText: AppL10n.of(dialogContext).classesWeeklyLabel,
                    prefixIcon: const Icon(Icons.event_repeat_rounded),
                  ),
                  items: List.generate(
                    14,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        AppL10n.of(dialogContext).classesWeeklyOption(i + 1),
                      ),
                    ),
                  ),
                  onChanged: (value) => setDialog(() {
                    weeklySessions = value ?? 1;
                    while (sessions.length < weeklySessions) {
                      sessions.add(
                        ClassSessionDraft(
                          weekday: sessions.last.weekday,
                          startTime: sessions.last.startTime,
                          endTime: sessions.last.endTime,
                        ),
                      );
                    }
                    while (sessions.length > weeklySessions) {
                      sessions.removeLast();
                    }
                  }),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppL10n.of(dialogContext).classesChooseTimes,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < sessions.length; i++)
                  Container(
                    margin: const EdgeInsetsDirectional.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: [
                        studafyCyan,
                        const Color(0xFF7737EE),
                        const Color(0xFFFF6B6B),
                        const Color(0xFF20B981),
                        const Color(0xFFFFB84D),
                      ][i % 5].withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppL10n.of(dialogContext).classesSessionNumber(i + 1),
                          style: const TextStyle(
                            color: studafyInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: sessions[i].weekday,
                          decoration: InputDecoration(
                            labelText: AppL10n.of(dialogContext)
                                .classesDayLabel,
                          ),
                          items: List.generate(
                            7,
                            (day) => DropdownMenuItem(
                              value: day + 1,
                              child: Text(dayNames[day]),
                            ),
                          ),
                          onChanged: (value) => setDialog(
                            () => sessions[i] = ClassSessionDraft(
                              weekday: value ?? 1,
                              startTime: sessions[i].startTime,
                              endTime: sessions[i].endTime,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: _parseTimeOfday(
                                      sessions[i].startTime,
                                    ),
                                  );
                                  if (t != null) {
                                    setDialog(
                                      () => sessions[i] = ClassSessionDraft(
                                        weekday: sessions[i].weekday,
                                        startTime: _formatTimeOfDay(t),
                                        endTime: sessions[i].endTime,
                                      ),
                                    );
                                  }
                                },
                                child: Text(sessions[i].startTime),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(AppL10n.of(dialogContext).classesTo),
                            ),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final t = await showTimePicker(
                                    context: dialogContext,
                                    initialTime: _parseTimeOfday(
                                      sessions[i].endTime,
                                    ),
                                  );
                                  if (t != null) {
                                    setDialog(
                                      () => sessions[i] = ClassSessionDraft(
                                        weekday: sessions[i].weekday,
                                        startTime: sessions[i].startTime,
                                        endTime: _formatTimeOfDay(t),
                                      ),
                                    );
                                  }
                                },
                                child: Text(sessions[i].endTime),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppL10n.of(dialogContext).classesCancel),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || sessions.isEmpty) return;
                final draft = NewClassDraft(
                  name: name.text.trim(),
                  grade: grade,
                  section: section,
                  room: room.text.trim().isEmpty ? 'TBD' : room.text.trim(),
                  firstSessionStart: sessions.first.startTime,
                  firstSessionEnd: sessions.first.endTime,
                  weeklySessions: weeklySessions,
                  sessions: List.unmodifiable(sessions),
                );
                final result = await widget.classes.createClass(draft);
                if (!dialogContext.mounted) return;
                switch (result) {
                  case Success():
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, true);
                    }
                  case FailureResult(:final failure):
                    createFailure = failure.message;
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, false);
                    }
                }
              },
              child: Text(AppL10n.of(dialogContext).classesCreateAction),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _refresh();
    } else if (createFailure != null && context.mounted) {
      _showFailure(context, createFailure!);
    }
  }

  Future<void> _invite(BuildContext context, ClassroomSummary classroom) async {
    // A live link is shown for what it is before a new one is minted:
    // creating another silently supersedes it, and a teacher who has already
    // shared one should be told that rather than discovering it later.
    final existing = await widget.classes.activeJoinLink(classroom.id.value);
    if (!context.mounted) return;
    final live = existing.fold(
      onSuccess: (link) => link,
      onFailure: (_) => null,
    );
    if (live != null) {
      final replace = await _showLiveLinkSheet(context, live);
      if (!context.mounted || !replace) return;
    }
    final result = await widget.classes.inviteLinkFor(classroom.id);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (link) => _showInviteDialog(context, link),
      onFailure: (failure) => _showFailure(context, failure.message),
    );
  }

  /// Shows the live link and offers to revoke it or replace it.
  ///
  /// Returns true when the teacher wants a new link minted.
  Future<bool> _showLiveLinkSheet(
    BuildContext context,
    ClassJoinLinkInfo link,
  ) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.joinLinkActive,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.joinLinkUses(link.useCount)),
              Text(
                l10n.joinLinkExpires(
                  '${link.expiresAt.year}-'
                  '${link.expiresAt.month.toString().padLeft(2, '0')}-'
                  '${link.expiresAt.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.joinLinkNewReplaces,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, 'revoke'),
                      child: Text(l10n.joinLinkRevoke),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, 'replace'),
                      child: Text(AppL10n.of(sheetContext).classesInviteTitle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'revoke') {
      final revoked = await widget.classes.revokeJoinLink(link.id);
      revoked.fold(
        onSuccess: (_) => messenger.showSnackBar(
          SnackBar(content: Text(l10n.joinLinkRevoked)),
        ),
        onFailure: (_) => messenger.showSnackBar(
          SnackBar(content: Text(l10n.joinLinkRevokeFailed)),
        ),
      );
      return false;
    }
    return choice == 'replace';
  }

  void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInviteDialog(BuildContext context, String link) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppL10n.of(dialogContext).classesInviteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppL10n.of(dialogContext).classesInviteBody),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: studafyNavy.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(
                  color: studafyNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppL10n.of(dialogContext).classesInviteCopied,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(AppL10n.of(dialogContext).classesCopy),
          ),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: AppL10n.of(dialogContext).classesShareMessage(link),
              ),
            ),
            icon: const Icon(Icons.ios_share),
            label: Text(AppL10n.of(dialogContext).classesShareLink),
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classroom,
    required this.onTap,
    required this.onInvite,
  });

  final ClassroomSummary classroom;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final tint = Color(classroom.colorValue ?? 0xFF241D73);
    final l10n = AppL10n.of(context);
    final detail = [
      l10n.classesStudentCount(classroom.studentCount),
      if (classroom.weeklySessions != null)
        l10n.classesPerWeek(classroom.weeklySessions!),
      classroom.room ?? l10n.classesRoomTbd,
    ].join(' · ');
    return FeatureCard(
      tint: tint,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The teacher named this class; it shows as they wrote it.
                UserContentText(
                  classroom.name,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.classesGradeSection(
                    classroom.grade.toString(),
                    classroom.section,
                  ),
                  style: const TextStyle(color: studafyMuted),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: studafyMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          Icon(forwardChevron(context), color: studafyMuted),
        ],
      ),
    );
  }
}

class _ClassesTitleHeader extends StatelessWidget {
  const _ClassesTitleHeader();

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Classes',
              style: const TextStyle(
                color: studafyInk,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

TimeOfDay _parseTimeOfday(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
    minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
  );
}

String _formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
