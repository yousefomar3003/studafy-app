import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/notification.dart';
import '../domain/notifications_repository.dart';

/// Loads and mutates notifications through the repository port. Presentation
/// calls this, never a database, provider client, or the repository
/// directly (ARC-011).
class NotificationsInteractor {
  NotificationsInteractor({required this.repository, required this.telemetry});

  final NotificationsRepository repository;
  final Telemetry telemetry;

  Future<Result<NotificationPage>> load({String? cursor}) {
    return runCatching(() async {
      final page = await repository.list(cursor: cursor);
      telemetry.event('notifications_loaded', {
        'count': page.items.length,
        'from_cache': page.isFromCache,
      });
      return page;
    });
  }

  Future<Result<int>> unreadCount() => runCatching(repository.unreadCount);

  Future<Result<void>> markAllRead() {
    return runCatching(() async {
      await repository.markRead(ids: const [], all: true);
      telemetry.event('notifications_marked_read', {'all': true});
    });
  }

  Future<Result<void>> markRead(String id) {
    return runCatching(() async {
      await repository.markRead(ids: [id], all: false);
      telemetry.event('notifications_marked_read', {'all': false});
    });
  }

  Future<Result<void>> syncPending() =>
      runCatching(repository.syncPending);
}
