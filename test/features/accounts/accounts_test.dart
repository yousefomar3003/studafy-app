import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/secure_storage.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/accounts/data/secure_account_vault.dart';
import 'package:studafy/features/accounts/domain/device_account.dart';
import 'package:studafy/features/accounts/presentation/account_switcher_sheet.dart';
import 'package:studafy/features/accounts/presentation/create_child_account_page.dart';
import 'package:studafy/features/accounts/presentation/sub_account_banner.dart';

import '../../support/localized_app.dart';

void main() {
  const parent = DeviceAccount(
    userId: 'p',
    displayName: 'Yousef',
    role: StudafyRole.parent,
  );
  const child = DeviceAccount(
    userId: 'c',
    displayName: 'Sara',
    role: StudafyRole.student,
    managedBy: 'p',
    managedByName: 'Yousef',
  );

  group('the account vault', () {
    test('keeps accounts and tokens together, in the secure store', () async {
      final store = InMemorySecureStore();
      final vault = SecureAccountVault(store);
      await vault.write(
        const DeviceAccountList(
          accounts: [parent, child],
          tokens: {'p': 'refresh-p'},
        ),
      );

      final read = await SecureAccountVault(store).read();
      expect(read.accounts.map((a) => a.userId), ['p', 'c']);
      expect(read.accounts.last.managedBy, 'p');
      expect(read.tokens, {'p': 'refresh-p'});
    });

    test('damaged contents read as empty rather than failing', () async {
      final store = InMemorySecureStore();
      await store.write('studafy.device_accounts.v1', '{not json');
      expect((await SecureAccountVault(store).read()).accounts, isEmpty);
    });

    test('an empty list leaves nothing behind', () async {
      final store = InMemorySecureStore();
      final vault = SecureAccountVault(store);
      await vault.write(const DeviceAccountList(accounts: [parent]));
      await vault.write(const DeviceAccountList());
      expect(store.snapshot, isEmpty);
    });
  });

  group('the account switcher', () {
    Future<AccountChoice?> open(
      WidgetTester tester, {
      bool canCreateChild = true,
      Future<void> Function()? then,
    }) async {
      AccountChoice? picked;
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showAccountSwitcher(
                context,
                accounts: const [parent, child],
                currentUserId: 'p',
                canCreateChild: canCreateChild,
                roleLabel: (role) => role.name,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await then?.call();
      return picked;
    }

    testWidgets('says whose sub-account a child account is', (tester) async {
      await open(tester);
      expect(find.text('Sub-account · managed by Yousef'), findsOne);
      expect(find.byIcon(Icons.check_circle_rounded), findsOne);
    });

    testWidgets('picking an account switches to it', (tester) async {
      AccountChoice? choice;
      await open(
        tester,
        then: () async {
          await tester.tap(find.text('Sara'));
          await tester.pumpAndSettle();
        },
      ).then((value) => choice = value);
      await tester.pumpAndSettle();
      expect(choice, isA<SwitchToAccount>());
      expect((choice! as SwitchToAccount).account.userId, 'c');
    });

    testWidgets('a child account is not offered "create a child account"', (
      tester,
    ) async {
      await open(tester, canCreateChild: false);
      expect(find.text('Add account'), findsOne);
      expect(find.text('Create a child account'), findsNothing);
    });
  });

  group('creating a child account', () {
    Widget page({
      required Future<ManagedChild> Function(String) create,
      void Function(ManagedChild)? onSwitch,
    }) => localizedApp(
      home: CreateChildAccountPage(
        create: create,
        onSwitch: onSwitch ?? (_) {},
      ),
    );

    testWidgets('needs a name and the parent accepting the terms for them', (
      tester,
    ) async {
      final names = <String>[];
      await tester.pumpWidget(
        page(
          create: (name) async {
            names.add(name);
            return ManagedChild(
              childId: 'c',
              displayName: name,
              createdAt: DateTime(2026, 9, 28),
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), 'Sara');
      await tester.pump();
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(names, isEmpty);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(names, ['Sara']);
      expect(find.text("Sara's account is ready."), findsOne);
      expect(find.text('Switch to Sara'), findsOne);
    });

    testWidgets('the limit is explained', (tester) async {
      await tester.pumpWidget(
        page(
          create: (_) async => throw const ManagedChildException(
            ManagedChildRefusal.limitReached,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Sara');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      expect(find.text('You can manage up to six child accounts.'), findsOne);
    });
  });

  testWidgets('the banner names the parent and switches back', (tester) async {
    var switched = 0;
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SubAccountBanner(
            parentName: 'Yousef',
            onSwitch: () => switched++,
          ),
        ),
      ),
    );
    expect(find.text('Sub-account · managed by Yousef'), findsOne);
    await tester.tap(find.text('Switch'));
    expect(switched, 1);
  });

  testWidgets('reads in Arabic', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: SubAccountBanner(parentName: 'يوسف', onSwitch: () {}),
        ),
      ),
    );
    expect(find.text('حساب فرعي · يديره يوسف'), findsOne);
  });
}
