import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/data/local_cache/cache_scope.dart';
import 'package:studafy/data/local_cache/offline_cache_database.dart';
import 'package:studafy/data/local_cache/session_cache_binder.dart';
import 'package:studafy/features/notifications/data/api_notifications_repository.dart';

/// MOB-070 slice 1 (student notifications): proves the repository built on
/// the shared cache/outbox behaves correctly for the scenarios the roadmap
/// calls out by name — airplane mode, reconnect, duplicate replay, partial
/// page, and a read receipt that must never regress.
void main() {
  // No shared-directory wipe here: `scope` below is re-keyed with a unique
  // id per test in setUp, and tearDown wipes only that scope's own file. A
  // directory-wide wipe would race other test files sharing this same ffi
  // database directory when the suite runs them concurrently.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late CacheScope scope;
  late SessionCacheBinder binder;
  late _ScriptedTransport transport;
  late ApiNotificationsRepository repository;

  setUp(() {
    final userId = 'student-${DateTime.now().microsecondsSinceEpoch}';
    scope = CacheScope(userId: userId, schoolId: 'school-1');
    ActiveContextController.instance.hydrate(
      authenticatedProfile: UserProfile(
        id: userId,
        displayName: 'Student',
        email: 'student@example.test',
        memberships: [
          const SchoolMembership(
            id: 'm1',
            schoolId: 'school-1',
            schoolName: 'School',
            role: StudafyRole.student,
            active: true,
          ),
        ],
      ),
      activeMembership: const SchoolMembership(
        id: 'm1',
        schoolId: 'school-1',
        schoolName: 'School',
        role: StudafyRole.student,
        active: true,
      ),
    );
    binder = SessionCacheBinder(context: ActiveContextController.instance);
    transport = _ScriptedTransport();
    repository = ApiNotificationsRepository(V1ApiClient(transport), binder);
  });

  tearDown(() async {
    binder.dispose();
    ActiveContextController.instance.signOut();
    await OfflineCacheDatabase.wipe(scope);
  });

  test(
    'a live page is cached and mapped to typed items, not raw maps',
    () async {
      transport.nextPage = _page([
        _notification(id: 'n1', templateKey: 'academic.grade_published'),
      ]);

      final page = await repository.list();

      expect(page.isFromCache, isFalse);
      expect(page.items.single.id, 'n1');
      expect(
        page.items.single.title,
        'notification.academic.grade_published.title',
      );
      expect(page.items.single.isRead, isFalse);
    },
  );

  test('airplane mode falls back to the cache instead of throwing', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'academic.grade_published'),
    ]);
    await repository.list(); // primes the cache while "online"

    transport.failNextGet = true;
    final offlinePage = await repository.list();

    expect(offlinePage.isFromCache, isTrue);
    expect(offlinePage.items.single.id, 'n1');
  });

  test(
    'offline pagination reports no next page rather than inventing a cursor',
    () async {
      transport.failNextGet = true;
      final page = await repository.list(
        cursor: 'some-cursor-from-before-airplane-mode',
      );

      expect(page.isFromCache, isTrue);
      expect(page.nextCursor, isNull);
    },
  );

  test('marking read while offline is optimistic locally and queues durably', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'academic.grade_published'),
    ]);
    await repository.list();

    transport.failNextGet = true;
    transport.failNextPost = true; // the mark-read call itself is offline too
    await repository.markRead(ids: const ['n1'], all: false);
    await _settle(); // let the fire-and-forget opportunistic flush attempt run

    final offlinePage = await repository.list();
    expect(
      offlinePage.items.single.isRead,
      isTrue,
      reason: 'optimistic local read must apply immediately',
    );
    expect(
      transport.postAttempts,
      1,
      reason: 'the immediate opportunistic flush should have been attempted once and failed',
    );
  });

  test('reconnecting replays the queued mutation with its original idempotency key', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'academic.grade_published'),
    ]);
    await repository.list();

    transport.failNextPost = true;
    await repository.markRead(ids: const ['n1'], all: false);
    await _settle();
    expect(transport.postAttempts, 1);

    transport.failNextPost = false;
    await repository.syncPending();

    expect(transport.postAttempts, 2);
    expect(
      transport.idempotencyKeys.first,
      transport.idempotencyKeys.last,
      reason: 'a retried mutation must reuse its original idempotency key',
    );
    expect(transport.postBodies.last['ids'], ['n1']);
  });

  test('a dropped response is replayed safely: the server\'s "already applied" reply is treated as success', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'academic.grade_published'),
    ]);
    await repository.list();

    // First attempt: the request reached the server and applied, but the
    // client never saw the response (connection dropped mid-reply).
    transport.dropResponseOnNextPost = true;
    await repository.markRead(ids: const ['n1'], all: false);
    await _settle();
    expect(transport.postAttempts, 1);

    // Retry reuses the same idempotency key; the server reports it was
    // already applied rather than applying it twice.
    transport.replyIdempotencyKeyReusedOnNextPost = true;
    await repository.syncPending();

    expect(transport.postAttempts, 2);
    // No crash, no exception surfaced — a safe replay is a success.
  });

  test('a stale server snapshot fetched during an in-flight replay does not un-read a notification', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'academic.grade_published'),
    ]);
    await repository.list();

    transport.failNextPost =
        true; // mark-read stays queued, not yet applied server-side
    await repository.markRead(ids: const ['n1'], all: false);

    // A concurrent read returns the server's still-unread snapshot.
    transport.nextPage = _page([
      _notification(
        id: 'n1',
        templateKey: 'academic.grade_published',
        readAt: null,
      ),
    ]);
    final page = await repository.list();

    expect(
      page.items.single.isRead,
      isTrue,
      reason: 'the local read receipt must win over a stale unread snapshot',
    );
  });

  test(
    'unread count falls back to the cache when the live count is unavailable',
    () async {
      transport.nextPage = _page([
        _notification(id: 'n1', templateKey: 'academic.grade_published'),
        _notification(
          id: 'n2',
          templateKey: 'communications.message_sent',
          readAt: '2026-01-01T00:00:00Z',
        ),
      ]);
      await repository.list();

      transport.failNextGet = true;
      final count = await repository.unreadCount();

      expect(count, 1);
    },
  );

  test('an unrecognized template key falls back to generic localization keys instead of crashing', () async {
    transport.nextPage = _page([
      _notification(id: 'n1', templateKey: 'future.unknown_template'),
    ]);

    final page = await repository.list();

    expect(page.items.single.title, 'notification.generic.title');
    expect(page.items.single.detail, 'notification.generic.detail');
  });
}

/// Gives the fire-and-forget opportunistic flush a turn to run. `markRead`
/// deliberately does not await it (an optimistic write must not block the
/// UI on network latency), so a test asserting on its outcome has to yield
/// to the event loop explicitly instead of racing it.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  String? nextCursor,
}) => {'items': items, 'nextCursor': nextCursor};

Map<String, dynamic> _notification({
  required String id,
  required String templateKey,
  String? readAt,
}) => {
  'id': id,
  'templateKey': templateKey,
  'payload': <String, dynamic>{},
  'createdAt': '2026-01-01T00:00:00Z',
  'readAt': readAt,
};

class _ScriptedTransport implements V1JsonTransport {
  Map<String, dynamic> nextPage = {'items': <dynamic>[], 'nextCursor': null};
  bool failNextGet = false;
  bool failNextPost = false;
  bool dropResponseOnNextPost = false;
  bool replyIdempotencyKeyReusedOnNextPost = false;

  int postAttempts = 0;
  final List<Map<String, Object?>> postBodies = [];
  final List<String?> idempotencyKeys = [];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (failNextGet) {
      failNextGet = false;
      throw const SocketException('offline');
    }
    if (path.contains('unread-count')) {
      final items = nextPage['items'] as List<dynamic>;
      final unread = items
          .cast<Map<String, dynamic>>()
          .where((n) => n['readAt'] == null)
          .length;
      return {'unreadCount': unread};
    }
    return nextPage;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    postAttempts++;
    postBodies.add(body);
    idempotencyKeys.add(idempotencyKey);

    if (replyIdempotencyKeyReusedOnNextPost) {
      replyIdempotencyKeyReusedOnNextPost = false;
      throw const V1ApiException(
        status: 409,
        code: 'IDEMPOTENCY_KEY_REUSED',
        message: 'already applied',
      );
    }
    if (dropResponseOnNextPost) {
      dropResponseOnNextPost = false;
      throw const SocketException('connection dropped');
    }
    if (failNextPost) {
      failNextPost = false;
      throw const SocketException('offline');
    }
    return {
      'markedCount': (body['all'] == true) ? 1 : (body['ids'] as List).length,
    };
  }
}
