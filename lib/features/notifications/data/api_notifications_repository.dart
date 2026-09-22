import 'dart:async';
import 'dart:math';

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
  final Map<String, String> _preferenceKeys = {};

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
      V1MarkNotificationsReadRequestDto(
        ids: ids.isEmpty ? null : ids,
        all: all ? true : null,
      ),
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
      final items = await _cacheMerged(store, page.items);
      return NotificationPage(
        items: items,
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
  /// read receipt applied locally while offline — once `readAt` is set
  /// locally, a stale server snapshot fetched concurrently with an
  /// in-flight outbox replay must not un-read it — and returns the same
  /// merged view, so a caller reading the result right now sees the same
  /// truth the cache now holds, not the raw pre-merge server snapshot.
  Future<List<NotificationItem>> _cacheMerged(
    OfflineCacheStore store,
    List<V1NotificationDto> items,
  ) async {
    final existing = await store.entitiesFor(
      _entityType,
      includeTombstoned: true,
    );
    final localReadAt = {
      for (final entity in existing)
        entity.entityId: entity.payload['readAt'] as String?,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    final entities = <CachedEntity>[];
    final merged = <NotificationItem>[];
    for (final item in items) {
      final readAt = localReadAt[item.id] ?? item.readAt;
      entities.add(
        CachedEntity(
          entityId: item.id,
          payload: {...item.toJson(), 'readAt': readAt},
          updatedAt: now,
        ),
      );
      merged.add(
        NotificationItem(
          id: item.id,
          templateKey: item.templateKey,
          title: _titleKey(item.templateKey),
          detail: _detailKey(item.templateKey),
          createdAt: DateTime.parse(item.createdAt),
          readAt: readAt == null ? null : DateTime.parse(readAt),
        ),
      );
    }
    await store.putEntities(_entityType, entities);
    return merged;
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
    await _engineFor(store).drain(force: true);
  }

  @override
  Future<List<NotificationPreference>> preferences() async {
    final response = await _client.getNotificationPreferences();
    return [
      for (final item in response.items)
        NotificationPreference(
          schoolId: item.schoolId,
          channel: item.channel,
          category: item.category,
          enabled: item.enabled,
        ),
    ];
  }

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async {
    final fingerprint =
        '${preference.schoolId}|${preference.channel}|${preference.category}|${preference.enabled}';
    final key = _preferenceKeys.putIfAbsent(
      fingerprint,
      () =>
          'pref-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
    );
    final value = await _client.updateNotificationPreferences(
      V1UpdateNotificationPreferenceRequestDto(
        schoolId: preference.schoolId,
        channel: preference.channel,
        category: preference.category,
        enabled: preference.enabled,
      ),
      idempotencyKey: key,
    );
    _preferenceKeys.remove(fingerprint);
    return NotificationPreference(
      schoolId: value.schoolId,
      channel: value.channel,
      category: value.category,
      enabled: value.enabled,
    );
  }

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
  'billing.purchase_approval_approved',
  'billing.purchase_approval_declined',
  'billing.purchase_approval_requested',
  'communications.announcement_created',
  'communications.message_sent',
  'family.guardian_link_requested',
  'family.guardian_link_revoked',
  'family.guardian_link_verified',
  'invitations.issued',
  'meetings.cancelled',
  'meetings.failed',
  'meetings.requested',
  'meetings.scheduled',
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
