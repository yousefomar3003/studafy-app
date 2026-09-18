import 'notification.dart';

/// Typed mobile boundary for the notifications slice (MOB-070). Remote
/// implementations must fail closed to the cache, never to a hard error, on
/// a read; preview implementations are the only adapters allowed to be
/// pure in-memory fixtures.
abstract interface class NotificationsRepository {
  Future<NotificationPage> list({String? cursor, int pageSize = 20});

  /// Prefers a live count; falls back to counting unread cached entries when
  /// offline. Never throws for "offline" — that is a normal state here, not
  /// a failure.
  Future<int> unreadCount();

  /// Marks specific notifications read, or every one when [all] is true.
  /// Always optimistic: the cache (and therefore every open `list()`
  /// consumer) reflects the change immediately, whether or not the device
  /// currently has connectivity.
  Future<void> markRead({required List<String> ids, required bool all});

  /// Replays any mutations still waiting in the outbox. Safe to call
  /// whenever the app suspects connectivity returned (pull-to-refresh, app
  /// resume); a no-op when nothing is queued.
  Future<void> syncPending();
}
