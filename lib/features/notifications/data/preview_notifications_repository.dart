import '../domain/notification.dart';
import '../domain/notifications_repository.dart';

/// Synthetic-only in-memory adapter. Keeps its state in process, is never
/// selected by a remote runtime policy, and never touches the legacy
/// preview SQLite database — the fake "recent activity" screen it replaces
/// used to synthesize notifications from grade/notice/assignment rows; this
/// seeds a small fixed set instead of resurrecting that coupling.
class PreviewNotificationsRepository implements NotificationsRepository {
  PreviewNotificationsRepository()
    : _items = [
        NotificationItem(
          id: 'preview-1',
          templateKey: 'academic.grade_published',
          title: 'notification.academic.grade_published.title',
          detail: 'notification.academic.grade_published.detail',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        NotificationItem(
          id: 'preview-2',
          templateKey: 'communications.announcement_created',
          title: 'notification.communications.announcement_created.title',
          detail: 'notification.communications.announcement_created.detail',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        NotificationItem(
          id: 'preview-3',
          templateKey: 'academic.assignment_published',
          title: 'notification.academic.assignment_published.title',
          detail: 'notification.academic.assignment_published.detail',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          readAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

  final List<NotificationItem> _items;

  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async =>
      NotificationPage(
        items: List.of(_items),
        nextCursor: null,
        isFromCache: false,
      );

  @override
  Future<int> unreadCount() async =>
      _items.where((item) => !item.isRead).length;

  @override
  Future<void> markRead({required List<String> ids, required bool all}) async {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isRead) continue;
      if (all || ids.contains(item.id)) {
        _items[i] = item.copyWith(readAt: DateTime.now());
      }
    }
  }

  @override
  Future<void> syncPending() async {}
}
