import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/messaging.dart';
import 'conversations_page.dart';
import 'messaging_scope.dart';

/// A school whose announcements reach the reader, and through whom.
@immutable
class AnnouncementSource {
  const AnnouncementSource({
    required this.schoolId,
    required this.schoolName,
    required this.children,
  });

  final String schoolId;
  final String schoolName;

  /// The reader's children at that school, by id and name.
  final Map<String, String> children;
}

/// Announcements, on a page of their own: every school the reader's children
/// attend, newest first, each labelled with where it came from, and a filter
/// by child. Reading only - posting one is a teacher's tool and is not here.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({
    super.key,
    required this.sources,
    this.visible = true,
  });

  final List<AnnouncementSource> sources;

  /// Re-reads on coming into view; the shell keeps every tab alive.
  final bool visible;

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  /// The child to show the school of; null shows every school.
  String? _child;
  Future<List<(Announcement, AnnouncementSource)>>? _items;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.visible) _items ??= _load();
  }

  @override
  void didUpdateWidget(AnnouncementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sourcesChanged =
        oldWidget.sources.map((s) => s.schoolId).join() !=
        widget.sources.map((s) => s.schoolId).join();
    if ((widget.visible && !oldWidget.visible) || sourcesChanged) {
      setState(() {
        _items = _load();
      });
    }
  }

  List<AnnouncementSource> get _shown {
    final child = _child;
    if (child == null) return widget.sources;
    return [
      for (final source in widget.sources)
        if (source.children.containsKey(child)) source,
    ];
  }

  /// One request per school - a handful at most - each school's list
  /// labelled with it, then newest first together.
  Future<List<(Announcement, AnnouncementSource)>> _load() async {
    final messaging = MessagingScope.of(context);
    final lists = await Future.wait([
      for (final source in _shown)
        messaging
            .announcements(schoolId: source.schoolId)
            .then(
              (result) => result.fold(
                onSuccess: (items) => [
                  for (final item in items) (item, source),
                ],
                onFailure: (failure) => throw failure,
              ),
            ),
    ]);
    return [for (final list in lists) ...list]
      ..sort((a, b) => b.$1.createdAt.compareTo(a.$1.createdAt));
  }

  void _select(String? child) => setState(() {
    _child = child;
    _items = _load();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final children = {for (final source in widget.sources) ...source.children};
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Scaffold(
      body: Column(
        children: [
          StudafyLargeTitle(
            title: l10n.navAnnouncements,
            subtitle: l10n.announcementsSubtitle,
          ),
          if (children.length > 1) ...[
            PillTabs<String?>(
              values: [null, ...children.keys],
              selected: _child,
              label: (id) =>
                  id == null ? l10n.announcementsAllChildren : children[id]!,
              icon: (id) =>
                  id == null ? Icons.groups_rounded : Icons.child_care_rounded,
              onSelected: _select,
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: widget.sources.isEmpty
                ? Center(
                    child: StudafyEmptyState(
                      icon: Icons.campaign_outlined,
                      title: l10n.msgAnnouncementsEmpty,
                      message: l10n.announcementsNoChildren,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: motion,
                    child: KeyedSubtree(
                      key: ValueKey(_child),
                      child: _list(l10n),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _list(AppL10n l10n) =>
      FutureBuilder<List<(Announcement, AnnouncementSource)>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: StudafyEmptyState(
                icon: Icons.wifi_off_rounded,
                title: l10n.msgAnnouncementsFailed,
                actionLabel: l10n.msgRetry,
                onAction: () => setState(() {
                  _items = _load();
                }),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          final labelled = widget.sources.length > 1;
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() => _items = next);
              await next.then((_) {}, onError: (_) {});
            },
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 28),
              children: [
                if (items.isEmpty)
                  StudafyEmptyState(
                    icon: Icons.campaign_outlined,
                    title: l10n.msgAnnouncementsEmpty,
                  ),
                for (final (item, source) in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnnouncementCard(
                      announcement: item,
                      from: labelled || source.children.length > 1
                          ? l10n.announcementsFrom(
                              source.schoolName,
                              source.children.values.join(', '),
                            )
                          : source.schoolName,
                    ),
                  ),
              ],
            ),
          );
        },
      );
}
