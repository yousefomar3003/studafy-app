import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/school_links_interactor.dart';
import '../domain/school_links.dart';

/// "From your school": announcements a school sent to the reader's class,
/// their child's class, or them as a linked teacher (plan 13a.6). The push
/// named nothing; the words are read here, after sign-in.
class SchoolAnnouncementsPage extends StatefulWidget {
  const SchoolAnnouncementsPage({super.key, required this.links});

  final SchoolLinksInteractor links;

  @override
  State<SchoolAnnouncementsPage> createState() =>
      _SchoolAnnouncementsPageState();
}

class _SchoolAnnouncementsPageState extends State<SchoolAnnouncementsPage> {
  List<SchoolAnnouncement>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final result = await widget.links.announcements();
    if (!mounted) return;
    result.fold(
      onSuccess: (items) => setState(() => _items = items),
      onFailure: (_) => setState(() => _failed = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.schoolAnnouncementsTitle)),
      body: StudafyRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_failed && items == null)
              StudafyStatusCard(
                icon: Icons.cloud_off_outlined,
                title: l10n.schoolAnnouncementsLoadError,
                message: l10n.schoolLinkErrorGeneric,
                actionLabel: l10n.schoolLinkRetry,
                onAction: _load,
              )
            else if (items == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              StudafyEmptyState(
                icon: Icons.campaign_outlined,
                title: l10n.schoolAnnouncementsEmpty,
              )
            else
              for (final item in items) _Announcement(item: item),
          ],
        ),
      ),
    );
  }
}

class _Announcement extends StatelessWidget {
  const _Announcement({required this.item});

  final SchoolAnnouncement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserContentText(
              item.school,
              style: theme.labelMedium?.copyWith(color: studafyMuted),
            ),
            const SizedBox(height: 4),
            UserContentText(item.title, style: theme.titleMedium),
            const SizedBox(height: 8),
            UserContentText(item.body, style: theme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '${studafyMediumDate(context, item.createdAt)} · '
              '${studafyTime(context, item.createdAt)}',
              style: theme.bodySmall?.copyWith(color: studafyMuted),
            ),
          ],
        ),
      ),
    );
  }
}
