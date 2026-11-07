import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/school_links_interactor.dart';
import '../domain/school_links.dart';
import 'report_school_dialog.dart';
import 'school_link_text.dart';

/// One school's request: who asks, exactly what the school would see and
/// never see, and Accept, Decline or Report (plan 6.2). Also shows a link
/// that is no longer waiting, with Report.
class SchoolLinkRequestPage extends StatefulWidget {
  const SchoolLinkRequestPage({
    super.key,
    required this.links,
    required this.linkId,
  });

  final SchoolLinksInteractor links;
  final String linkId;

  @override
  State<SchoolLinkRequestPage> createState() => _SchoolLinkRequestPageState();
}

class _SchoolLinkRequestPageState extends State<SchoolLinkRequestPage> {
  SchoolLink? _link;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await widget.links.load();
    if (!mounted) return;
    result.fold(
      onSuccess: (list) => setState(() {
        _link = list.where((link) => link.id == widget.linkId).firstOrNull;
        _loading = false;
      }),
      onFailure: (_) => setState(() {
        _loading = false;
        _failed = true;
      }),
    );
  }

  Future<void> _decide({required bool accept}) async {
    final link = _link;
    if (link == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmSchoolLink(
      context,
      title: accept
          ? l10n.schoolLinkAcceptTitle(link.org.name)
          : l10n.schoolLinkDeclineTitle,
      body: accept
          ? l10n.schoolLinkAcceptBody
          : l10n.schoolLinkDeclineBody(link.org.name),
      confirm: accept ? l10n.schoolLinkAccept : l10n.schoolLinkDecline,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    var result = await widget.links.decide(link, accept: accept);
    if (!mounted) return;
    // One school at a time: leaving the current one is the teacher's call.
    if (accept &&
        result.fold(
          onSuccess: (_) => false,
          onFailure: (failure) => failure.code == 'LINKED_ELSEWHERE',
        )) {
      final current = widget.links.linked;
      final replace = await confirmSchoolLink(
        context,
        title: l10n.schoolLinkReplaceTitle,
        body: l10n.schoolLinkReplaceBody(
          current?.org.name ?? '',
          link.org.name,
        ),
        confirm: l10n.schoolLinkReplaceConfirm,
        destructive: true,
      );
      if (!mounted) return;
      if (!replace) {
        setState(() => _busy = false);
        return;
      }
      result = await widget.links.decide(
        link,
        accept: true,
        replaceCurrent: true,
      );
      if (!mounted) return;
    }
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) {
        messenger.showMessage(
          accept ? l10n.schoolLinkAccepted : l10n.schoolLinkDeclined,
        );
        Navigator.of(context).pop();
      },
      onFailure: (failure) {
        messenger.showMessage(schoolLinkFailureText(l10n, failure));
        _load();
      },
    );
  }

  Future<void> _report() async {
    final link = _link;
    if (link == null) return;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final report = await askSchoolReport(context);
    if (report == null || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.links.report(
      link,
      reason: report.reason,
      details: report.details,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      onSuccess: (_) => messenger.showMessage(l10n.schoolReportSent),
      onFailure: (failure) =>
          messenger.showMessage(schoolLinkFailureText(l10n, failure)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final link = _link;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolLinkRequestTitle)),
      body: StudafyRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_failed)
              StudafyStatusCard(
                icon: Icons.cloud_off_outlined,
                title: l10n.schoolLinksLoadError,
                message: l10n.schoolLinkErrorGeneric,
                actionLabel: l10n.schoolLinkRetry,
                onAction: _load,
              )
            else if (link == null)
              StudafyStatusCard(
                icon: Icons.history_rounded,
                title: l10n.schoolLinkNoLongerWaiting,
                message: l10n.schoolLinksIntro,
              )
            else
              ..._details(context, l10n, link),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, AppL10n l10n, SchoolLink link) {
    final theme = Theme.of(context).textTheme;
    final by = link.requestedBy;
    return [
      Text(
        l10n.schoolLinkRequestHeading(link.org.name),
        style: theme.headlineSmall,
      ),
      const SizedBox(height: 8),
      UserContentText(
        [
          schoolKindText(l10n, link.org.kind),
          link.org.city,
          link.org.country,
        ].where((part) => part.isNotEmpty).join(' · '),
        style: theme.bodyMedium?.copyWith(color: studafyMuted),
      ),
      if (by != null) ...[
        SectionHeader(l10n.schoolLinkAskedBy),
        FeatureCard(
          child: Row(
            children: [
              InitialsAvatar(name: by.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(by.name, style: theme.titleMedium),
                    if (by.jobTitle case final title? when title.isNotEmpty)
                      UserContentText(title, style: theme.bodyMedium),
                    if (by.email case final email? when email.isNotEmpty)
                      UserContentText(
                        email,
                        style: theme.bodySmall?.copyWith(color: studafyMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      SectionHeader(l10n.schoolLinkSeesTitle),
      _List(
        icon: Icons.visibility_outlined,
        items: [
          l10n.schoolLinkSeesClasses,
          l10n.schoolLinkSeesStudents,
          l10n.schoolLinkSeesParents,
          l10n.schoolLinkSeesLessons,
          l10n.schoolLinkSeesWork,
          l10n.schoolLinkSeesMarks,
          l10n.schoolLinkSeesAttendance,
          l10n.schoolLinkSeesWellbeing,
        ],
      ),
      SectionHeader(l10n.schoolLinkNeverTitle),
      _List(
        icon: Icons.lock_outline_rounded,
        items: [
          l10n.schoolLinkNeverMessages,
          l10n.schoolLinkNeverTutor,
          l10n.schoolLinkNeverNotes,
        ],
      ),
      const SizedBox(height: 16),
      Text(l10n.schoolLinkReadOnly, style: theme.bodyMedium),
      const SizedBox(height: 20),
      if (link.isPending) ...[
        FilledButton(
          onPressed: _busy ? null : () => _decide(accept: true),
          child: Text(l10n.schoolLinkAccept),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : () => _decide(accept: false),
          child: Text(l10n.schoolLinkDecline),
        ),
      ] else
        StatusPill(
          label: schoolLinkStatusText(l10n, link.status),
          icon: Icons.info_outline_rounded,
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _busy ? null : _report,
        icon: const Icon(Icons.flag_outlined),
        label: Text(l10n.schoolLinkReport),
      ),
    ];
  }
}

class _List extends StatelessWidget {
  const _List({required this.icon, required this.items});

  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) => FeatureCard(
    child: Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: studafyCyan),
                const SizedBox(width: 12),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    ),
  );
}
