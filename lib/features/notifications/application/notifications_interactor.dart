import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/notification.dart';
import '../domain/notification_taps.dart';
import '../domain/notifications_repository.dart';

/// Loads and mutates notifications through the repository port. Presentation
/// calls this, never a database, provider client, or the repository
/// directly (ARC-011).
class NotificationsInteractor {
  NotificationsInteractor({
    required this.repository,
    required this.telemetry,
    this.taps,
  });

  final NotificationsRepository repository;
  final Telemetry telemetry;

  /// Taps on push notifications, waiting for the signed-in shell to open
  /// them. Null in builds with no push.
  final NotificationTaps? taps;

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

  /// The notification [id] from the newest pages of the feed, or null when
  /// it is not there: it belongs to another account, or is too old to look
  /// for. Reads the same feed the list shows, so offline it is the cache.
  Future<Result<NotificationItem?>> find(String id, {int maxPages = 3}) {
    return runCatching(() async {
      String? cursor;
      NotificationItem? found;
      for (var page = 0; page < maxPages && found == null; page++) {
        final result = await repository.list(cursor: cursor);
        found = result.items.where((item) => item.id == id).firstOrNull;
        cursor = result.nextCursor;
        if (cursor == null) break;
      }
      telemetry.event('notification_tap_lookup', {'found': found != null});
      return found;
    });
  }

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

  Future<Result<void>> syncPending() => runCatching(repository.syncPending);

  Future<Result<List<NotificationPreference>>> loadPreferences() =>
      runCatching(repository.preferences);

  Future<Result<NotificationPreference>> updatePreference(
    NotificationPreference preference,
  ) => runCatching(() async {
    final value = await repository.updatePreference(preference);
    telemetry.event('notification_preference_updated', {
      'channel': value.channel,
      'category': value.category,
      'enabled': value.enabled,
    });
    return value;
  });
}
