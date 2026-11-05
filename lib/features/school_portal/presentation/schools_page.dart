import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/school_links_interactor.dart';
import '../domain/school_links.dart';
import 'report_school_dialog.dart';
import 'school_link_request_page.dart';
import 'school_link_text.dart';

/// Account → Schools (plan 6.3): the school that can see the teacher's
/// classes now, requests waiting for an answer, and earlier ones, with
/// Unlink and Report.
class SchoolsPage extends StatefulWidget {
  const SchoolsPage({super.key, required this.links});

  final SchoolLinksInteractor links;

  @override
  State<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends State<SchoolsPage> {
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
    final (result, _) = await (
      widget.links.load(),
      widget.links.loadGroupClasses(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = !result.fold(onSuccess: (_) => true, onFailure: (_) => false);
    });
  }

  Future<void> _open(SchoolLink link) async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) =>
            SchoolLinkRequestPage(links: widget.links, linkId: link.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _unlink(SchoolLink link) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmSchoolLink(
      context,
      title: l10n.schoolLinkUnlinkTitle,
      body: l10n.schoolLinkUnlinkBody(link.org.name),
      confirm: l10n.schoolLinkUnlink,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final result = await widget.links.unlink(link);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showMessage(
      result.fold(
        onSuccess: (_) => l10n.schoolLinkUnlinked,
        onFailure: (failure) => schoolLinkFailureText(l10n, failure),
      ),
    );
  }

  Future<void> _decideGroup(
    SchoolGroupClass entry,
    SchoolGroupClassDecision decision,
  ) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await widget.links.decideGroupClass(entry, decision);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showMessage(
      result.fold(
        onSuccess: (_) => switch (decision) {
          SchoolGroupClassDecision.approve => l10n.schoolGroupApproved,
          SchoolGroupClassDecision.decline => l10n.schoolGroupDeclined,
          SchoolGroupClassDecision.remove => l10n.schoolGroupRemoved,
        },
        onFailure: (failure) => schoolLinkFailureText(l10n, failure),
      ),
    );
  }

  Future<void> _report(SchoolLink link) async {
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
    messenger.showMessage(
      result.fold(
        onSuccess: (_) => l10n.schoolReportSent,
        onFailure: (failure) => schoolLinkFailureText(l10n, failure),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolLinksTitle)),
      body: StudafyRefreshIndicator(
        onRefresh: _load,
        child: ValueListenableBuilder(
          valueListenable: widget.links.current,
          builder: (context, list, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l10n.schoolLinksIntro),
              const SizedBox(height: 8),
              if (_loading && list == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_failed && list == null)
                StudafyStatusCard(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.schoolLinksLoadError,
                  message: l10n.schoolLinkErrorGeneric,
                  actionLabel: l10n.schoolLinkRetry,
                  onAction: _load,
                )
              else ...[
                ..._sections(l10n, list ?? const []),
                ValueListenableBuilder(
                  valueListenable: widget.links.groupClasses,
                  builder: (context, entries, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _groupSection(l10n, entries),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(AppL10n l10n, List<SchoolLink> list) {
    if (list.isEmpty) {
      return [
        const SizedBox(height: 24),
        StudafyEmptyState(
          icon: Icons.school_outlined,
          title: l10n.schoolLinksEmpty,
          message: l10n.schoolLinkReadOnly,
        ),
      ];
    }
    final linked = list.where((link) => link.isLinked).toList();
    final waiting = list.where((link) => link.isPending).toList();
    final earlier = list
        .where((link) => !link.isLinked && !link.isPending)
        .toList();
    return [
      if (linked.isNotEmpty) ...[
        SectionHeader(l10n.schoolLinksLinkedSection),
        for (final link in linked)
          _SchoolCard(
            link: link,
            subtitle: l10n.schoolLinkBanner(link.org.name),
            actions: [
              TextButton(
                onPressed: _busy ? null : () => _unlink(link),
                child: Text(l10n.schoolLinkUnlink),
              ),
              TextButton(
                onPressed: _busy ? null : () => _report(link),
                child: Text(l10n.schoolLinkReport),
              ),
            ],
          ),
      ],
      if (waiting.isNotEmpty) ...[
        SectionHeader(l10n.schoolLinksPendingSection),
        for (final link in waiting)
          _SchoolCard(
            link: link,
            onTap: () => _open(link),
            actions: [
              FilledButton(
                onPressed: () => _open(link),
                child: Text(l10n.schoolLinksReview),
              ),
            ],
          ),
      ],
      if (earlier.isNotEmpty) ...[
        SectionHeader(l10n.schoolLinksPastSection),
        for (final link in earlier)
          _SchoolCard(
            link: link,
            subtitle: schoolLinkStatusText(l10n, link.status),
            onTap: () => _open(link),
          ),
      ],
    ];
  }
}

extension on _SchoolsPageState {
  /// Plan 13a.7: the teacher answers for each class a school asks to group.
  List<Widget> _groupSection(AppL10n l10n, List<SchoolGroupClass> entries) {
    if (entries.isEmpty) return const [];
    final theme = Theme.of(context).textTheme;
    return [
      SectionHeader(l10n.schoolGroupsSection),
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserContentText(entry.className, style: theme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  entry.approved
                      ? l10n.schoolGroupIn(entry.school, entry.groupName)
                      : l10n.schoolGroupAsk(entry.school, entry.groupName),
                  style: theme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: entry.approved
                      ? [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _decideGroup(
                                    entry,
                                    SchoolGroupClassDecision.remove,
                                  ),
                            child: Text(l10n.schoolGroupRemove),
                          ),
                        ]
                      : [
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _decideGroup(
                                    entry,
                                    SchoolGroupClassDecision.approve,
                                  ),
                            child: Text(l10n.schoolGroupApprove),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _decideGroup(
                                    entry,
                                    SchoolGroupClassDecision.decline,
                                  ),
                            child: Text(l10n.schoolGroupDecline),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.link,
    this.subtitle,
    this.onTap,
    this.actions = const [],
  });

  final SchoolLink link;
  final String? subtitle;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FeatureCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserContentText(link.org.name, style: theme.titleMedium),
            const SizedBox(height: 2),
            UserContentText(
              [
                schoolKindText(l10n, link.org.kind),
                link.org.city,
              ].where((part) => part.isNotEmpty).join(' · '),
              style: theme.bodySmall?.copyWith(color: studafyMuted),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: theme.bodyMedium),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
