import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_localizations.dart';
import '../domain/notification.dart';
import 'notifications_scope.dart';
import 'notification_preferences_page.dart';

/// Real notifications feed, backed by the typed `/v1` notifications
/// repository (MOB-070). Replaces the legacy `StudentNotificationsPage`,
/// which synthesized fake "notification" cards from the first row of
/// whatever grades/notices/assignments/exams happened to be in local SQLite
/// and never persisted read state anywhere.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> _items = const [];
  String? _nextCursor;
  bool _isFromCache = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
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
    final t = StudafyLocalizations.of(context).text;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(t('notifications.title')),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'ar'
                ? 'تفضيلات الإشعارات'
                : 'Notification preferences',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationPreferencesPage(),
              ),
            ),
          ),
          TextButton(
            onPressed: _items.any((item) => !item.isRead) ? _markAllRead : null,
            child: Text(t('notifications.markAllRead')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? StudafyStatusCard(
              icon: Icons.error_outline_rounded,
              title: t('notifications.errorTitle'),
              message: _error!,
              actionLabel: t('notifications.retry'),
              onAction: _refresh,
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
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
                                t('notifications.offlineBanner'),
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
                      title: t('notifications.emptyTitle'),
                      message: t('notifications.emptyMessage'),
                    )
                  else
                    for (final item in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FeatureCard(
                          tint: item.isRead ? null : studafyCyan,
                          onTap: () => _markRead(item),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item.isRead
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                color: item.isRead ? studafyMuted : studafyNavy,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t(item.title),
                                      style: TextStyle(
                                        color: studafyInk,
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      t(item.detail),
                                      style: const TextStyle(
                                        color: studafyMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_nextCursor != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton(
                        onPressed: _loadingMore ? null : _loadMore,
                        child: Text(
                          _loadingMore
                              ? t('notifications.loading')
                              : t('notifications.loadMore'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
