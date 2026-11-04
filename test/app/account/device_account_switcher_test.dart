import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account/account_switching.dart';
import 'package:studafy/app/account/device_account_switcher.dart';
import 'package:studafy/app/account/push_tap_accounts.dart';
import 'package:studafy/app/push_binder.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/accounts/domain/device_account.dart';
import 'package:studafy/features/notifications/domain/notification_taps.dart';
import 'package:studafy/features/notifications/domain/push_registrar.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';

import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';

/// Several accounts on one device, and a parent's child accounts. What
/// matters is that a switch lands on exactly the account asked for, that a
/// child account is only ever entered through its parent, and that a
/// failure puts the person back where they were.
void main() {
  const parent = 'parent-1';
  const child = 'child-1';
  const other = 'teacher-1';

  final context = ActiveContextController.instance;
  tearDown(context.signOut);

  const parentAccount = DeviceAccount(
    userId: parent,
    displayName: 'Yousef',
    role: StudafyRole.parent,
  );
  const childAccount = DeviceAccount(
    userId: child,
    displayName: 'Sara',
    role: StudafyRole.student,
    managedBy: parent,
    managedByName: 'Yousef',
  );
  const otherAccount = DeviceAccount(
    userId: other,
    displayName: 'Rana',
    role: StudafyRole.teacher,
  );

  Future<(DeviceAccountSwitcher, _Sessions, _Vault, _Children)> start({
    required String signedIn,
    List<DeviceAccount> accounts = const [],
    Map<String, String> tokens = const {},
    List<String>? forgotten,
    List<String>? events,
    _PushServer? push,
  }) async {
    final sessions = _Sessions(signedIn);
    final vault = _Vault(DeviceAccountList(accounts: accounts, tokens: tokens));
    final children = _Children(sessions);
    final interactor = SessionInteractor(
      repository: sessions,
      context: context,
      telemetry: const NoopTelemetry(),
      runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
    );
    // The phone's push registration, each call made with the session that
    // is current at the time - as the real one's API calls are.
    final registrar = push == null ? null : _PhonePush(push, sessions);
    final switcher = DeviceAccountSwitcher(
      session: interactor,
      vault: vault,
      managedChildren: children,
      forgetAccount: forgotten == null ? null : (id) async => forgotten.add(id),
      beforeSignOut:
          registrar?.unregister ??
          (events == null
              ? null
              : () async => events.add(
                  // Still signed in: the server call to drop the phone works.
                  'unregister while ${sessions.current ?? 'nobody'} is signed in',
                )),
      childrenAdded: registrar?.register,
      context: context,
    );
    if (registrar != null) {
      final binder = PushBinder(registrar: registrar, context: context);
      addTearDown(binder.dispose);
    }
    final role = accounts
        .where((a) => a.userId == signedIn)
        .map((a) => a.role)
        .firstOrNull;
    await interactor.completeRemoteLogin(
      role: role ?? StudafyRole.parent,
      consentAccepted: false,
      locale: 'en',
    );
    await pumpEventQueue();
    return (switcher, sessions, vault, children);
  }

  test('every token the session is issued is kept for its account', () async {
    final (_, sessions, vault, _) = await start(
      signedIn: parent,
      accounts: [parentAccount],
    );
    sessions.issue(parent, 'rotated-token');
    await pumpEventQueue();

    expect(vault.saved.tokens[parent], 'rotated-token');
  });

  test('a new sign-in joins the list with the role it was opened as', () async {
    final (switcher, _, vault, _) = await start(signedIn: parent);

    expect(switcher.accounts.single.userId, parent);
    expect(switcher.accounts.single.role, StudafyRole.parent);
    expect(vault.saved.accounts.single.displayName, 'Yousef');
  });

  test('switching to an adult resumes their own saved session', () async {
    final (switcher, sessions, _, children) = await start(
      signedIn: parent,
      accounts: [parentAccount, otherAccount],
      tokens: {parent: 'p', other: 'o'},
    );

    final role = await switcher.switchTo(otherAccount, locale: 'en');

    expect(role, StudafyRole.teacher);
    expect(sessions.current, other);
    expect(context.profile?.id, other);
    expect(children.tokensIssued, isEmpty);
  });

  test(
    'a child account is entered through its parent, never by itself',
    () async {
      final (switcher, sessions, _, children) = await start(
        signedIn: parent,
        accounts: [parentAccount, childAccount],
        tokens: {parent: 'p'},
      );

      final role = await switcher.switchTo(childAccount, locale: 'en');

      expect(role, StudafyRole.student);
      expect(children.tokensIssued, [child]);
      expect(sessions.entered, [child]);
      expect(switcher.current?.isManaged, isTrue);
    },
  );

  test(
    'from another account, the parent is resumed first to reach a child',
    () async {
      final (switcher, sessions, _, children) = await start(
        signedIn: other,
        accounts: [otherAccount, parentAccount, childAccount],
        tokens: {parent: 'p', other: 'o'},
      );

      await switcher.switchTo(childAccount, locale: 'en');

      expect(sessions.resumed, ['p']);
      expect(children.tokensIssuedBy, [parent]);
      expect(sessions.current, child);
    },
  );

  test('a child whose parent is not on the device cannot be opened', () async {
    final (switcher, sessions, _, children) = await start(
      signedIn: other,
      accounts: [otherAccount, childAccount],
      tokens: {other: 'o'},
    );

    await expectLater(
      switcher.switchTo(childAccount, locale: 'en'),
      throwsA(
        isA<AccountSwitchException>().having(
          (e) => e.failure,
          'failure',
          AccountSwitchFailure.needsParent,
        ),
      ),
    );
    expect(children.tokensIssued, isEmpty);
    expect(sessions.current, other);
    expect(context.profile?.id, other);
  });

  test('a used-up token that leaves the old session in place is a failure, '
      'not a switch', () async {
    final (switcher, sessions, _, _) = await start(
      signedIn: parent,
      accounts: [parentAccount, otherAccount],
      tokens: {parent: 'p', other: 'o'},
    );
    // What Supabase does with a token already used: keeps the session it had.
    sessions.ignoreResume = true;

    await expectLater(
      switcher.switchTo(otherAccount, locale: 'en'),
      throwsA(isA<AccountSwitchException>()),
    );
    expect(context.profile?.id, parent);
    expect(switcher.current?.userId, parent);
  });

  test('child accounts are created from the parent interface only', () async {
    final (switcher, _, _, _) = await start(
      signedIn: other,
      accounts: [otherAccount],
      tokens: {other: 'o'},
    );
    // Rana is signed in as a teacher, not as a parent.
    expect(switcher.canCreateChild, isFalse);
  });

  test('a child account cannot create child accounts', () async {
    final (switcher, _, _, _) = await start(
      signedIn: parent,
      accounts: [parentAccount, childAccount],
      tokens: {parent: 'p'},
    );
    expect(switcher.canCreateChild, isTrue);

    await switcher.switchTo(childAccount, locale: 'en');

    expect(switcher.canCreateChild, isFalse);
  });

  test('a created child is kept as the parent\'s sub-account', () async {
    final (switcher, _, vault, _) = await start(
      signedIn: parent,
      accounts: [parentAccount],
      tokens: {parent: 'p'},
    );

    await switcher.createChild('Omar', locale: 'ar');
    await pumpEventQueue();

    final saved = vault.saved.accounts.last;
    expect(saved.displayName, 'Omar');
    expect(saved.managedBy, parent);
    expect(saved.managedByName, 'Yousef');
    expect(saved.role, StudafyRole.student);
  });

  test('signing the parent out takes their children off the device too, '
      'and leaves everyone else', () async {
    final (switcher, sessions, vault, _) = await start(
      signedIn: parent,
      accounts: [parentAccount, childAccount, otherAccount],
      tokens: {parent: 'p', other: 'o'},
    );

    final next = await switcher.signOutCurrent();
    await pumpEventQueue();

    expect(next?.userId, other);
    expect(sessions.signOutScopes, [SignOutScope.currentDevice]);
    expect(vault.saved.accounts.map((a) => a.userId), [other]);
    expect(vault.saved.tokens.keys, [other]);
  });

  // Regression: the frame once built itself inside itself, and the app
  // opened on a stack overflow for every account.
  testWidgets('the frame shows the app, with no banner on an own account', (
    tester,
  ) async {
    final (switcher, _, _, _) = await tester.runAsync(
      () => start(signedIn: parent, accounts: [parentAccount]),
    ) as (DeviceAccountSwitcher, _Sessions, _Vault, _Children);
    await tester.pumpWidget(
      localizedApp(
        home: DeviceAccountsFrame(
          switcher: switcher,
          onSwitch: () {},
          child: const Text('the app'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('the app'), findsOne);
    expect(find.textContaining('Sub-account'), findsNothing);
  });

  testWidgets('in a child account, the frame says whose it is', (tester) async {
    final (switcher, _, _, _) = await tester.runAsync(() async {
      final started = await start(
        signedIn: parent,
        accounts: [parentAccount, childAccount],
        tokens: {parent: 'p'},
      );
      await started.$1.switchTo(childAccount, locale: 'en');
      return started;
    }) as (DeviceAccountSwitcher, _Sessions, _Vault, _Children);
    await tester.pumpWidget(
      localizedApp(
        home: DeviceAccountsFrame(
          switcher: switcher,
          onSwitch: () {},
          child: const Text('the app'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('the app'), findsOne);
    expect(find.text('Managed by Yousef'), findsOne);
  });

  test("signing out deletes the account's chats, and its children's", () async {
    final forgotten = <String>[];
    final (switcher, _, _, _) = await start(
      signedIn: parent,
      accounts: [parentAccount, childAccount, otherAccount],
      tokens: {parent: 'p', other: 'o'},
      forgotten: forgotten,
    );

    await switcher.signOutCurrent();

    expect(forgotten.toSet(), {parent, child});
  });

  test('the phone leaves push before the account signs out', () async {
    final events = <String>[];
    final (switcher, _, _, _) = await start(
      signedIn: parent,
      accounts: [parentAccount],
      tokens: {parent: 'p'},
      events: events,
    );

    await switcher.signOutCurrent();

    expect(events, ['unregister while parent-1 is signed in']);
  });

  group('push reaches every account on the phone (DL-082)', () {
    test('each account is registered as itself when it is signed in, and a '
        'switch takes nobody off', () async {
      final push = _PushServer();
      final (switcher, _, _, _) = await start(
        signedIn: parent,
        accounts: [parentAccount, otherAccount],
        tokens: {parent: 'p', other: 'o'},
        push: push,
      );
      await pumpEventQueue();
      expect(push.calls, ['register as $parent']);

      await switcher.switchTo(otherAccount, locale: 'en');
      await pumpEventQueue();
      await switcher.switchTo(parentAccount, locale: 'en');
      await pumpEventQueue();

      expect(push.calls, [
        'register as $parent',
        'register as $other',
        'register as $parent',
      ]);
      expect(push.live, {parent, other});
    });

    test('signing an account out takes only that account off', () async {
      final push = _PushServer();
      final (switcher, _, _, _) = await start(
        signedIn: parent,
        accounts: [parentAccount, otherAccount],
        tokens: {parent: 'p', other: 'o'},
        push: push,
      );
      await switcher.switchTo(otherAccount, locale: 'en');
      await pumpEventQueue();

      await switcher.signOutCurrent();

      expect(push.calls.last, 'unregister as $other');
      expect(push.live, {parent});
    });

    test('a new child account registers the phone again, as the parent, '
        'whose registration covers it', () async {
      final push = _PushServer();
      final (switcher, _, _, _) = await start(
        signedIn: parent,
        accounts: [parentAccount],
        tokens: {parent: 'p'},
        push: push,
      );
      await pumpEventQueue();

      await switcher.createChild('Sara', locale: 'en');
      await pumpEventQueue();

      expect(push.calls, ['register as $parent', 'register as $parent']);
    });
  });

  group('a tapped push for another account on the phone', () {
    test('switches to that account and leaves the tap for its shell', () async {
      final (switcher, sessions, _, _) = await start(
        signedIn: parent,
        accounts: [parentAccount, otherAccount],
        tokens: {parent: 'p', other: 'o'},
      );
      final taps = NotificationTaps()..tapped('77', recipientId: other);
      final tap = taps.consume()!;

      await openTapForAccount(
        tap,
        taps: taps,
        switcher: switcher,
        switchTo: (account) =>
            switcher.switchTo(account, locale: 'en').then((_) {}),
      );

      expect(sessions.current, other);
      expect(context.profile?.id, other);
      expect(taps.pending?.notificationId, '77');
      expect(taps.pending?.recipientId, other);
    });

    test('is ignored when that account is no longer on the phone', () async {
      final (switcher, sessions, _, _) = await start(
        signedIn: parent,
        accounts: [parentAccount],
        tokens: {parent: 'p'},
      );
      final taps = NotificationTaps()..tapped('77', recipientId: 'gone-1');
      var switched = 0;

      await openTapForAccount(
        taps.consume()!,
        taps: taps,
        switcher: switcher,
        switchTo: (_) async => switched++,
      );

      expect(switched, 0);
      expect(sessions.current, parent);
      expect(taps.pending, isNull);
    });

    test(
      'is dropped when the switch fails, so it is not tried again',
      () async {
        final (switcher, sessions, _, _) = await start(
          signedIn: parent,
          accounts: [parentAccount, otherAccount],
          tokens: {parent: 'p'},
        );
        final taps = NotificationTaps()..tapped('77', recipientId: other);

        await openTapForAccount(
          taps.consume()!,
          taps: taps,
          switcher: switcher,
          switchTo: (account) =>
              switcher.switchTo(account, locale: 'en').then((_) {}),
        );

        expect(sessions.current, parent);
        expect(taps.pending, isNull);
      },
    );
  });

  test('leaving a child account goes back to its parent', () async {
    final (switcher, _, _, _) = await start(
      signedIn: parent,
      accounts: [otherAccount, parentAccount, childAccount],
      tokens: {parent: 'p', other: 'o'},
    );
    await switcher.switchTo(childAccount, locale: 'en');

    final next = await switcher.signOutCurrent();

    expect(next?.userId, parent);
  });
}

/// The server's push registrations for one phone: one per account.
class _PushServer {
  final calls = <String>[];
  final live = <String>{};
}

/// The phone's registrar: every call is made as the account whose session
/// is current, the only one the API would accept it from.
class _PhonePush implements PushRegistrar {
  _PhonePush(this.server, this.sessions);

  final _PushServer server;
  final _Sessions sessions;

  @override
  Future<void> register() async {
    final account = sessions.current;
    if (account == null) return;
    server.calls.add('register as $account');
    server.live.add(account);
  }

  @override
  Future<void> unregister() async {
    final account = sessions.current;
    if (account == null) return;
    server.calls.add('unregister as $account');
    server.live.remove(account);
  }
}

/// A device's sessions: one current, the rest resumable by token.
class _Sessions extends FakeSessionRepositoryBase {
  _Sessions(this.current);

  String? current;
  bool ignoreResume = false;
  final resumed = <String>[];
  final entered = <String>[];
  final _tokens = StreamController<SessionToken>.broadcast();

  static const _owners = {'p': 'parent-1', 'o': 'teacher-1'};
  static const _names = {
    'parent-1': 'Yousef',
    'child-1': 'Sara',
    'teacher-1': 'Rana',
  };

  void issue(String userId, String token) =>
      _tokens.add(SessionToken(userId: userId, refreshToken: token));

  @override
  bool get hasCurrentSession => current != null;
  @override
  String? get currentUserId => current;
  @override
  Stream<SessionToken> get sessionTokens => _tokens.stream;
  @override
  Stream<bool> get sessionChanges => const Stream.empty();
  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async => current == null
      ? null
      : UserProfile(
          id: current!,
          displayName: _names[current!]!,
          email: '',
          memberships: const [],
        );

  @override
  Future<void> resumeSession(String refreshToken) async {
    resumed.add(refreshToken);
    if (ignoreResume) return;
    final owner = _owners[refreshToken];
    if (owner == null) throw StateError('invalid refresh token');
    current = owner;
  }

  @override
  Future<void> enterManagedAccount(String tokenHash) async {
    final childId = tokenHash.replaceFirst('hash-for-', '');
    entered.add(childId);
    current = childId;
  }

  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {
    await super.signOut(scope: scope);
    current = null;
  }
}

class _Vault implements AccountVault {
  _Vault(this.saved);
  DeviceAccountList saved;

  @override
  Future<DeviceAccountList> read() async => saved;
  @override
  Future<void> write(DeviceAccountList list) async => saved = list;
}

class _Children implements ManagedChildrenRepository {
  _Children(this.sessions);

  /// The server issues a child sign-in to whoever's session makes the call.
  final _Sessions sessions;
  final tokensIssued = <String>[];
  final tokensIssuedBy = <String?>[];

  @override
  Future<List<ManagedChild>> list() async => const [];

  @override
  Future<ManagedChild> create({
    required String displayName,
    required String locale,
  }) async => ManagedChild(
    childId: 'child-new',
    displayName: displayName,
    createdAt: DateTime(2026, 9, 28),
  );

  @override
  Future<String> signInToken(String childId) async {
    tokensIssued.add(childId);
    tokensIssuedBy.add(sessions.current);
    return 'hash-for-$childId';
  }
}
