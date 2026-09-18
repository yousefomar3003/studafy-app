import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/data/local_cache/cache_scope.dart';
import 'package:studafy/data/local_cache/mutation_outbox_engine.dart';
import 'package:studafy/data/local_cache/offline_cache_database.dart';
import 'package:studafy/data/local_cache/offline_cache_store.dart';
import 'package:studafy/data/local_cache/session_cache_binder.dart';

/// MOB-070 shared offline infrastructure: the cache/outbox foundation every
/// feature slice sits on, tested independently of any one feature so a
/// future slice can trust it without re-proving these guarantees.
void main() {
  // No shared-directory wipe here: every scope below is keyed by a unique
  // per-test id, and each test cleans up its own file via
  // OfflineCacheDatabase.wipe. A directory-wide wipe would race other test
  // files that share this same ffi database directory when the suite runs
  // them concurrently.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CacheScope', () {
    test('two ids produce the same fileKey deterministically', () {
      const a = CacheScope(userId: 'u1', schoolId: 's1');
      const b = CacheScope(userId: 'u1', schoolId: 's1');
      expect(a.fileKey, b.fileKey);
      expect(a, b);
    });

    test('a different school for the same user is a different scope', () {
      const a = CacheScope(userId: 'u1', schoolId: 's1');
      const b = CacheScope(userId: 'u1', schoolId: 's2');
      expect(a, isNot(b));
      expect(a.fileKey, isNot(b.fileKey));
    });

    test('the file key never contains the raw user or school id', () {
      const scope = CacheScope(
        userId: 'teacher@example.test',
        schoolId: 'school-1',
      );
      expect(scope.fileKey, isNot(contains('teacher')));
      expect(scope.fileKey, isNot(contains('school-1')));
    });
  });

  group('OfflineCacheStore', () {
    late CacheScope scope;

    setUp(() {
      scope = CacheScope(
        userId: 'store-user-${DateTime.now().microsecondsSinceEpoch}',
        schoolId: 'school-a',
      );
    });

    tearDown(() => OfflineCacheDatabase.wipe(scope));

    test('cached entities round-trip and can be tombstoned out of the default read', () async {
      final store = OfflineCacheStore(await OfflineCacheDatabase.open(scope));
      await store.putEntities('notification', [
        CachedEntity(entityId: '1', payload: {'title': 'A'}, updatedAt: 't1'),
        CachedEntity(
          entityId: '2',
          payload: {'title': 'B'},
          updatedAt: 't2',
          tombstoned: true,
        ),
      ]);

      final visible = await store.entitiesFor('notification');
      expect(visible.map((e) => e.entityId), ['1']);

      final all = await store.entitiesFor(
        'notification',
        includeTombstoned: true,
      );
      expect(all, hasLength(2));
    });

    test('mergeEntity preserves fields the resolver does not touch', () async {
      final store = OfflineCacheStore(await OfflineCacheDatabase.open(scope));
      await store.putEntities('notification', [
        CachedEntity(
          entityId: '1',
          payload: {'title': 'A', 'readAt': null},
          updatedAt: 't1',
        ),
      ]);

      await store.mergeEntity(
        'notification',
        '1',
        (current) => {...current, 'readAt': 'now'},
        't2',
      );

      final rows = await store.entitiesFor('notification');
      expect(rows.single.payload['title'], 'A');
      expect(rows.single.payload['readAt'], 'now');
    });

    test(
      'the outbox reports only mutations whose retry time has arrived',
      () async {
        final store = OfflineCacheStore(await OfflineCacheDatabase.open(scope));
        final now = DateTime.now().toUtc();
        await store.enqueueMutation(
          QueuedMutation(
            id: 'due',
            kind: 'k',
            idempotencyKey: 'idem-due',
            payload: const {},
            createdAt: now.toIso8601String(),
            attempts: 0,
            nextAttemptAt: now.subtract(const Duration(seconds: 1)),
            status: 'pending',
          ),
        );
        await store.enqueueMutation(
          QueuedMutation(
            id: 'not-due',
            kind: 'k',
            idempotencyKey: 'idem-not-due',
            payload: const {},
            createdAt: now.toIso8601String(),
            attempts: 1,
            nextAttemptAt: now.add(const Duration(minutes: 5)),
            status: 'pending',
          ),
        );

        final due = await store.duePending(now);
        expect(due.map((m) => m.id), ['due']);
      },
    );
  });

  group('MutationOutboxEngine', () {
    late CacheScope scope;
    late OfflineCacheStore store;

    setUp(() async {
      scope = CacheScope(
        userId: 'engine-user-${DateTime.now().microsecondsSinceEpoch}',
        schoolId: 'school-a',
      );
      store = OfflineCacheStore(await OfflineCacheDatabase.open(scope));
    });

    tearDown(() => OfflineCacheDatabase.wipe(scope));

    test('a mutation that succeeds is marked done and not retried', () async {
      var calls = 0;
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async {
          calls++;
          return const MutationDone({'ok': true});
        },
      );
      await engine.enqueue(kind: 'k', payload: const {'x': 1});
      await engine.drain();
      await engine.drain();

      expect(calls, 1);
      expect(
        (await store.duePending(
          DateTime.now().toUtc().add(const Duration(days: 1)),
        )),
        isEmpty,
      );
    });

    test('a transient failure keeps the mutation pending and backs off before the next attempt', () async {
      var calls = 0;
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async {
          calls++;
          return const MutationTransientFailure('offline');
        },
        backoff: (attempts) => const Duration(minutes: 10),
      );
      await engine.enqueue(kind: 'k', payload: const {});
      await engine.drain();
      await engine.drain();

      // The second drain ran immediately, well before the 10-minute backoff
      // elapsed, so it must not have re-attempted the same mutation.
      expect(calls, 1);
    });

    test('duplicate replay of an already-applied mutation is treated as success, not an error', () async {
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async => throw const V1ApiException(
          status: 409,
          code: 'IDEMPOTENCY_KEY_REUSED',
          message: 'already applied',
        ),
      );
      await engine.enqueue(kind: 'k', payload: const {});
      await engine.drain();

      final rows = await store.all();
      expect(rows.single.status, 'done');
    });

    test('a version conflict is parked, not retried forever, and the caller is told', () async {
      final conflicts = <String>[];
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async => throw const V1ApiException(
          status: 409,
          code: 'VERSION_CONFLICT',
          message: 'stale',
        ),
        onConflict: (mutation, reason) => conflicts.add(mutation.id),
      );
      final id = await engine.enqueue(kind: 'k', payload: const {});
      await engine.drain();

      expect(conflicts, [id]);
      final rows = await store.all();
      expect(rows.single.status, 'conflict');

      // A second drain must not attempt it again — it is no longer pending.
      var callsAfterConflict = 0;
      final engineAgain = MutationOutboxEngine(
        store: store,
        executor: (mutation) async {
          callsAfterConflict++;
          return const MutationDone({});
        },
      );
      await engineAgain.drain();
      expect(callsAfterConflict, 0);
    });

    test('a permanent rejection is parked as failed', () async {
      final rejected = <String>[];
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async => throw const V1ApiException(
          status: 422,
          code: 'VALIDATION',
          message: 'bad input',
        ),
        onRejected: (mutation, reason) => rejected.add(reason),
      );
      await engine.enqueue(kind: 'k', payload: const {});
      await engine.drain();

      expect(rejected, ['VALIDATION']);
      expect((await store.all()).single.status, 'failed');
    });

    test('a lost session halts the whole drain so other mutations are not spuriously failed', () async {
      final attempted = <String>[];
      final engine = MutationOutboxEngine(
        store: store,
        executor: (mutation) async {
          attempted.add(mutation.id);
          throw const V1ApiException(
            status: 401,
            code: 'UNAUTHENTICATED',
            message: 'expired',
          );
        },
      );
      await engine.enqueue(kind: 'k', payload: const {});
      await engine.enqueue(kind: 'k', payload: const {});
      await engine.drain();

      // Only the first mutation was attempted; the second was left untouched
      // rather than being attempted and failed for the same reason.
      expect(attempted, hasLength(1));
      final rows = await store.all();
      expect(rows.every((m) => m.status == 'pending'), isTrue);
    });
  });

  group('SessionCacheBinder', () {
    tearDown(ActiveContextController.instance.signOut);

    test(
      'signing out wipes the scope that was active, not just closes it',
      () async {
        final context = ActiveContextController.instance;
        context.hydrate(
          authenticatedProfile: const UserProfile(
            id: 'wipe-user',
            displayName: 'Wipe User',
            email: 'wipe@example.test',
            memberships: [
              SchoolMembership(
                id: 'm1',
                schoolId: 'school-wipe',
                schoolName: 'School',
                role: StudafyRole.student,
                active: true,
              ),
            ],
          ),
          activeMembership: const SchoolMembership(
            id: 'm1',
            schoolId: 'school-wipe',
            schoolName: 'School',
            role: StudafyRole.student,
            active: true,
          ),
        );
        final binder = SessionCacheBinder(context: context);
        addTearDown(binder.dispose);
        final store = await binder.currentStore();
        expect(store, isNotNull);
        await store!.putEntities('notification', [
          CachedEntity(entityId: '1', payload: const {}, updatedAt: 't'),
        ]);

        context.signOut();
        // The listener callback runs synchronously off notifyListeners, but the
        // wipe it kicks off (close, then delete) is async; give it time to
        // finish rather than assuming a fixed number of microtask turns.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        const scope = CacheScope(userId: 'wipe-user', schoolId: 'school-wipe');
        final reopened = OfflineCacheStore(
          await OfflineCacheDatabase.open(scope),
        );
        final rows = await reopened.entitiesFor('notification');
        expect(
          rows,
          isEmpty,
          reason: 'sign-out must not leave cached rows behind',
        );
        await OfflineCacheDatabase.wipe(scope);
      },
    );

    test(
      'switching school re-keys without deleting the previous scope\'s data',
      () async {
        final context = ActiveContextController.instance;
        const membershipA = SchoolMembership(
          id: 'm1',
          schoolId: 'school-x',
          schoolName: 'School X',
          role: StudafyRole.teacher,
          active: true,
        );
        const membershipB = SchoolMembership(
          id: 'm2',
          schoolId: 'school-y',
          schoolName: 'School Y',
          role: StudafyRole.teacher,
          active: true,
        );
        context.hydrate(
          authenticatedProfile: const UserProfile(
            id: 'switch-user',
            displayName: 'Switch User',
            email: 'switch@example.test',
            memberships: [membershipA, membershipB],
          ),
          activeMembership: membershipA,
        );
        final binder = SessionCacheBinder(context: context);
        addTearDown(binder.dispose);
        final storeA = await binder.currentStore();
        await storeA!.putEntities('notification', [
          CachedEntity(entityId: '1', payload: const {}, updatedAt: 't'),
        ]);

        context.switchMembership(membershipB);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final storeB = await binder.currentStore();
        expect(await storeB!.entitiesFor('notification'), isEmpty);

        const scopeA = CacheScope(userId: 'switch-user', schoolId: 'school-x');
        final reopenedA = OfflineCacheStore(
          await OfflineCacheDatabase.open(scopeA),
        );
        expect(await reopenedA.entitiesFor('notification'), hasLength(1));

        await OfflineCacheDatabase.wipe(scopeA);
        const scopeB = CacheScope(userId: 'switch-user', schoolId: 'school-y');
        await OfflineCacheDatabase.wipe(scopeB);
      },
    );
  });
}
