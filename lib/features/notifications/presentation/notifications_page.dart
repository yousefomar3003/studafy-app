import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/notification.dart';
import 'notification_copy.dart';
import 'notifications_scope.dart';

/// Real notifications feed, backed by the typed `/v1` notifications
/// repository (MOB-070). Replaces the legacy `StudentNotificationsPage`,
/// which synthesized fake "notification" cards from the first row of
/// whatever grades/notices/assignments/exams happened to be in local SQLite
/// and never persisted read state anywhere.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.visible = true, this.onOpen});

  /// Opens what a notification is about - the host knows its tabs. Returns
  /// true when it handled the item, and this page then closes. Null leaves
  /// a tap at marking the item read.
  final bool Function(NotificationItem item)? onOpen;

  /// Whether this tab is the one on screen.
  ///
  /// The shells keep every tab alive in an IndexedStack, so without this the
  /// feed is read once at startup and never again: a notification that
  /// arrived since launch stayed invisible until the app was killed. The
  /// Messages tab carries the same flag for the same reason. Pushed routes
  /// build fresh every time and leave it at its default.
  final bool visible;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> _items = const [];
  String? _nextCursor;
  bool _isFromCache = false;

  /// False while this tab is off screen: nothing is loading, so a spinner
  /// would be a lie and would never stop.
  late bool _loading = widget.visible;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.visible) unawaited(_refresh());
  }

  @override
  void didUpdateWidget(NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-read on the transition into view, not on every rebuild while
    // visible, which would reload on each keystroke elsewhere in the shell.
    if (widget.visible && !oldWidget.visible) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final interactor = NotificationsScope.of(context);
    await interactor.syncPending();
    final result = await interactor.load();
    if (!mounted) return;
    result.fold(
      onSuccess: (page) => setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _isFromCache = page.isFromCache;
        _loading = false;
        _error = null;
      }),
      onFailure: (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
    );
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    final result = await NotificationsScope.of(context).load(cursor: cursor);
    if (!mounted) return;
    result.fold(
      onSuccess: (page) => setState(() {
        _items = [..._items, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      }),
      onFailure: (_) => setState(() => _loadingMore = false),
    );
  }

  Future<void> _markAllRead() async {
    setState(() {
      _items = [
        for (final item in _items)
          item.isRead ? item : item.copyWith(readAt: DateTime.now()),
      ];
    });
    await NotificationsScope.of(context).markAllRead();
  }

  /// Marks the item read, then opens what it is about when the host can.
  Future<void> _open(NotificationItem item) async {
    unawaited(_markRead(item));
    final open = widget.onOpen;
    if (open != null && open(item) && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    setState(() {
      _items = [
        for (final existing in _items)
          existing.id == item.id
              ? existing.copyWith(readAt: DateTime.now())
              : existing,
      ];
    });
    await NotificationsScope.of(context).markRead(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        title: Text(l10n.notificationsFeedTitle),
        // Notification settings live on the account screen, with the other
        // preferences, rather than here in every role.
        actions: [
          TextButton(
            onPressed: _items.any((item) => !item.isRead) ? _markAllRead : null,
            child: Text(l10n.notificationsFeedMarkAllRead),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: l10n.notificationsFeedErrorTitle,
              message: _error!,
              actionLabel: l10n.notificationsFeedRetry,
              onAction: _refresh,
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                children: [
                  if (_isFromCache)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFAED),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 18,
                              color: Color(0xFF8A7650),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.notificationsFeedOfflineBanner,
                                style: const TextStyle(
                                  color: Color(0xFF8A7650),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_items.isEmpty)
                    StudafyStatusCard(
                      icon: Icons.notifications_none_rounded,
                      title: l10n.notificationsFeedEmptyTitle,
                      message: l10n.notificationsFeedEmptyMessage,
                    )
                  else
                    FeatureCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (index, item) in _items.indexed) ...[
                            if (index > 0)
                              const Divider(
                                height: 1,
                                indent: 66,
                                color: studafyHairline,
                              ),
                            _NotificationRow(
                              item: item,
                              onTap: () => _open(item),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_nextCursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(
                          _loadingMore
                              ? l10n.notificationsFeedLoading
                              : l10n.notificationsFeedLoadMore,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// The icon a notification is recognised by, from its kind.
IconData notificationIcon(String templateKey) =>
    switch (templateKey.split('.').first) {
      'academic' =>
        templateKey.contains('grade')
            ? Icons.grading_rounded
            : Icons.assignment_rounded,
      'communications' =>
        templateKey.contains('announcement')
            ? Icons.campaign_rounded
            : Icons.send_rounded,
      'family' => Icons.family_restroom_rounded,
      'billing' => Icons.workspace_premium_rounded,
      'meetings' => Icons.videocam_rounded,
      _ => Icons.notifications_rounded,
    };

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final unread = !item.isRead;
    final localizations = MaterialLocalizations.of(context);
    final at = item.createdAt.toLocal();
    final now = DateTime.now();
    final when =
        at.year == now.year && at.month == now.month && at.day == now.day
        ? localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at))
        : localizations.formatShortMonthDay(at);
    final title = notificationCopy(l10n, item.title);
    return Semantics(
      button: true,
      label: unread ? '$title. ${l10n.msgUnread}' : title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: notificationIcon(item.templateKey),
                color: unread ? studafyNavy : studafyMuted,
                size: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: studafyInk,
                          fontSize: 15,
                          fontWeight: unread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notificationCopy(l10n, item.detail),
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    when,
                    style: TextStyle(
                      color: unread ? studafyNavy : studafyMuted,
                      fontSize: 12,
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Unread is a dot and bold text, never colour alone.
                  if (unread)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: studafyNavy,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
