import 'dart:async';

import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../../../data/local_cache/mutation_outbox_engine.dart';
import '../../../data/local_cache/offline_cache_store.dart';
import '../../../data/local_cache/session_cache_binder.dart';
import '../domain/notification.dart';
import '../domain/notifications_repository.dart';

const _entityType = 'notification';

/// Authoritative MOB-070 notifications adapter. Reads prefer the network and
/// fall back to the scoped offline cache; writes are optimistic against the
/// cache and durable against the network through the mutation outbox, so a
/// "mark read" tapped in airplane mode is never lost and never replayed
/// twice.
class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._client, this._cache);

  final V1ApiClient _client;
  final SessionCacheBinder _cache;

  Future<OfflineCacheStore> _store() async {
    final store = await _cache.currentStore();
    if (store == null) throw Failure.unauthorized;
    return store;
  }

  MutationOutboxEngine _engineFor(OfflineCacheStore store) =>
      MutationOutboxEngine(store: store, executor: _execute);

  Future<MutationOutcome> _execute(QueuedMutation mutation) async {
    if (mutation.kind != 'mark_read') {
      return const MutationRejected('UNKNOWN_MUTATION_KIND');
    }
    final ids = (mutation.payload['ids'] as List).cast<String>();
    final all = mutation.payload['all'] as bool;
    final response = await _client.markNotificationsRead(
      V1MarkNotificationsReadRequestDto(ids: ids.isEmpty ? null : ids, all: all ? true : null),
      idempotencyKey: mutation.idempotencyKey,
    );
    return MutationDone(response.toJson());
  }

  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async {
    final store = await _store();
    try {
      final page = await _client.listNotifications(
        cursor: cursor,
        pageSize: pageSize,
      );
      await _cacheMerged(store, page.items);
      return NotificationPage(
        items: page.items.map(_mapDto).toList(),
        nextCursor: page.nextCursor,
        isFromCache: false,
      );
    } on V1ApiException {
      return _fromCache(store);
    } catch (_) {
      // Network unreachable (airplane mode, DNS failure, timeout): the
      // offline cache is the honest answer, not an error dialog.
      return _fromCache(store);
    }
  }

  Future<NotificationPage> _fromCache(OfflineCacheStore store) async {
    final cached = await store.entitiesFor(_entityType);
    final items = cached.map(_mapCached).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // Offline pagination cannot promise a real next page it hasn't fetched,
    // so it reports none rather than inventing a cursor.
    return NotificationPage(items: items, nextCursor: null, isFromCache: true);
  }

  /// Writes the freshly-fetched page into the cache without regressing a
  /// read receipt applied locally while offline: once `readAt` is set
  /// locally, a stale server snapshot fetched concurrently with an
  /// in-flight outbox replay must not un-read it.
  Future<void> _cacheMerged(
    OfflineCacheStore store,
    List<V1NotificationDto> items,
  ) async {
    final existing = await store.entitiesFor(_entityType, includeTombstoned: true);
    final localReadAt = {
      for (final entity in existing)
        entity.entityId: entity.payload['readAt'] as String?,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    await store.putEntities(_entityType, [
      for (final item in items)
        CachedEntity(
          entityId: item.id,
          payload: {
            ...item.toJson(),
            'readAt': localReadAt[item.id] ?? item.readAt,
          },
          updatedAt: now,
        ),
    ]);
  }

  @override
  Future<int> unreadCount() async {
    final store = await _store();
    try {
      return (await _client.getUnreadCount()).unreadCount;
    } catch (_) {
      final cached = await store.entitiesFor(_entityType);
      return cached.where((entity) => entity.payload['readAt'] == null).length;
    }
  }

  @override
  Future<void> markRead({required List<String> ids, required bool all}) async {
    final store = await _store();
    final now = DateTime.now().toUtc().toIso8601String();
    if (all) {
      final cached = await store.entitiesFor(_entityType);
      for (final entity in cached) {
        if (entity.payload['readAt'] != null) continue;
        await store.mergeEntity(
          _entityType,
          entity.entityId,
          (current) => {...current, 'readAt': now},
          now,
        );
      }
    } else {
      for (final id in ids) {
        await store.mergeEntity(
          _entityType,
          id,
          (current) => {...current, 'readAt': current['readAt'] ?? now},
          now,
        );
      }
    }
    final engine = _engineFor(store);
    await engine.enqueue(kind: 'mark_read', payload: {'ids': ids, 'all': all});
    // Best-effort immediate flush; the mutation stays durably queued either
    // way, so a failure here changes nothing about correctness.
    unawaited(engine.drain());
  }

  @override
  Future<void> syncPending() async {
    final store = await _store();
    await _engineFor(store).drain();
  }

  static NotificationItem _mapDto(V1NotificationDto dto) => NotificationItem(
    id: dto.id,
    templateKey: dto.templateKey,
    title: _titleKey(dto.templateKey),
    detail: _detailKey(dto.templateKey),
    createdAt: DateTime.parse(dto.createdAt),
    readAt: dto.readAt == null ? null : DateTime.parse(dto.readAt!),
  );

  static NotificationItem _mapCached(CachedEntity entity) {
    final templateKey = entity.payload['templateKey'] as String? ?? '';
    final readAt = entity.payload['readAt'] as String?;
    return NotificationItem(
      id: entity.entityId,
      templateKey: templateKey,
      title: _titleKey(templateKey),
      detail: _detailKey(templateKey),
      createdAt: DateTime.parse(entity.payload['createdAt'] as String),
      readAt: readAt == null ? null : DateTime.parse(readAt),
    );
  }
}

/// Every `template_key` the server can currently emit (notification_outbox
/// inserts across the API-041/042 migrations). Kept in sync by hand: an
/// unrecognized key falls back to the generic copy instead of surfacing a
/// raw, untranslated localization key to the user.
const _knownTemplateKeys = <String>{
  'academic.assessment_published',
  'academic.assignment_published',
  'academic.grade_published',
  'academic.resource_published',
  'academic.wellbeing_shared',
  'communications.announcement_created',
  'communications.message_sent',
  'family.guardian_link_requested',
  'family.guardian_link_revoked',
  'family.guardian_link_verified',
  'invitations.issued',
  'meetings.cancelled',
  'meetings.requested',
  'school_admin.classroom_staff_assigned',
  'school_admin.classroom_staff_removed',
  'school_admin.membership_granted',
  'school_admin.student_enrolled',
  'school_admin.student_transferred',
  'school_admin.student_withdrawn',
  'support_access.approved',
  'support_access.requested',
  'support_access.revoked',
  'support_access.started',
};

String _resolvedKey(String templateKey) =>
    _knownTemplateKeys.contains(templateKey) ? templateKey : 'generic';
String _titleKey(String templateKey) =>
    'notification.${_resolvedKey(templateKey)}.title';
String _detailKey(String templateKey) =>
    'notification.${_resolvedKey(templateKey)}.detail';
