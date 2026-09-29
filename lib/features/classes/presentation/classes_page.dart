import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/feedback.dart';
import '../../../core/result.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/class_list_interactor.dart';
import '../domain/classroom.dart';
import 'create_class_dialog.dart';

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
    if (await showCreateClassDialog(context, widget.classes)) _refresh();
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
    // The code already shared is the one shown: a teacher writes it on the
    // board once, and looking it up again must not replace it.
    if (live?.invite case final invite?) {
      await _showInviteDialog(context, invite, classroom: classroom);
      return;
    }
    // A live link whose code cannot be shown again - made before codes were
    // re-derivable - is described, with the choice to replace it.
    if (live != null) {
      final replace = await _showLiveLinkSheet(context, live);
      if (!context.mounted || !replace) return;
    }
    await _mintAndShow(context, classroom);
  }

  Future<void> _mintAndShow(
    BuildContext context,
    ClassroomSummary classroom,
  ) async {
    final result = await widget.classes.inviteLinkFor(classroom.id);
    if (!context.mounted) return;
    result.fold(
      onSuccess: (invite) =>
          _showInviteDialog(context, invite, classroom: classroom),
      onFailure: (failure) => _showFailure(context, failure.message),
    );
  }

  /// Replaces the code, after saying what that does to the old one.
  Future<void> _newCode(
    BuildContext dialogContext,
    ClassroomSummary classroom,
  ) async {
    final l10n = AppL10n.of(dialogContext);
    final sure = await showDialog<bool>(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        title: Text(l10n.classesNewCodeTitle),
        content: Text(l10n.classesNewCodeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: Text(
              MaterialLocalizations.of(confirmContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmContext, true),
            child: Text(l10n.classesNewCodeConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    if (!mounted) return;
    await _mintAndShow(context, classroom);
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
        onSuccess: (_) => messenger.showMessage(l10n.joinLinkRevoked),
        onFailure: (_) => messenger.showMessage(l10n.joinLinkRevokeFailed),
      );
      return false;
    }
    return choice == 'replace';
  }

  void _showFailure(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showMessage(message);
  }

  Future<void> _showInviteDialog(
    BuildContext context,
    ClassInvite invite, {
    required ClassroomSummary classroom,
  }) async {
    final link = invite.link;
    final code = invite.code;
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
            // The code first and large: it is what a teacher reads out or
            // writes on the board, and what a young child types on a
            // parent's phone. The link below is for sending in a message.
            if (code != null) ...[
              Text(
                AppL10n.of(dialogContext).classesInviteCodeLabel,
                style: Theme.of(dialogContext).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: studafyNavy.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  // Left to right even in Arabic: a code is read character
                  // by character in the order it was minted.
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: studafyNavy,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppL10n.of(dialogContext).classesInviteLinkLabel,
                style: Theme.of(dialogContext).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
            ],
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
          TextButton(
            onPressed: () => _newCode(dialogContext, classroom),
            child: Text(AppL10n.of(dialogContext).classesNewCode),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext)
                    .showMessage(AppL10n.of(dialogContext).classesInviteCopied);
              }
            },
            icon: const Icon(Icons.copy),
            label: Text(AppL10n.of(dialogContext).classesCopy),
          ),
          FilledButton.icon(
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: code == null
                    ? AppL10n.of(dialogContext).classesShareMessage(link)
                    : AppL10n.of(dialogContext)
                          .classesShareMessageWithCode(link, code),
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
