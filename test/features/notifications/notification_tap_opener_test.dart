import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/notifications/application/notifications_interactor.dart';
import 'package:studafy/features/notifications/domain/notification.dart';
import 'package:studafy/features/notifications/domain/notification_taps.dart';
import 'package:studafy/features/notifications/domain/notifications_repository.dart';
import 'package:studafy/features/notifications/presentation/notification_tap_opener.dart';
import 'package:studafy/features/notifications/presentation/notifications_page.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// A tap on a push opens what the notification is about, through the same
/// routing as a tap in the in-app list, for the account signed in - and
/// never the wrong account's screen.
void main() {
  final context = ActiveContextController.instance;
  tearDown(context.signOut);

  void signIn(String id) => context.hydrate(
    authenticatedProfile: UserProfile(
      id: id,
      displayName: id,
      email: '',
      memberships: const [],
    ),
  );

  final assessment = NotificationItem(
    id: '101',
    templateKey: 'academic.assessment_published',
    title: 'notification.academic.assessment_published.title',
    detail: 'notification.academic.assessment_published.detail',
    createdAt: DateTime(2026, 10, 18),
  );

  late _Repository repository;
  late NotificationTaps taps;
  late List<NotificationItem> opened;

  setUp(() {
    repository = _Repository([assessment]);
    taps = NotificationTaps();
    opened = [];
  });

  /// A shell, as the student's and parent's are: [onOpen] stands in for
  /// their `_openNotification`, which switches tab and returns true.
  Widget app({
    bool Function(NotificationItem item)? onOpen,
    bool withOpen = true,
    Key? shellKey,
  }) => MaterialApp(
    supportedLocales: AppL10n.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (_, child) => NotificationsScope(
      interactor: NotificationsInteractor(
        repository: repository,
        telemetry: const NoopTelemetry(),
        taps: taps,
      ),
      child: child!,
    ),
    home: NotificationTapOpener(
      key: shellKey,
      onOpen: withOpen
          ? onOpen ??
                (item) {
                  opened.add(item);
                  return true;
                }
          : null,
      child: const Scaffold(body: Text('shell')),
    ),
  );

  testWidgets('a tap opens its notification and marks it read, as the list '
      'does', (tester) async {
    signIn('student');
    await tester.pumpWidget(app());
    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(opened.map((item) => item.id), ['101']);
    expect(repository.markedRead, ['101']);
    expect(find.byType(NotificationsPage), findsNothing);
    expect(taps.pending, isNull);
  });

  testWidgets('a tap that started the app opens once the shell is up', (
    tester,
  ) async {
    signIn('student');
    taps.tapped('101');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(opened.map((item) => item.id), ['101']);
  });

  testWidgets('a push naming no notification opens the list', (tester) async {
    signIn('student');
    await tester.pumpWidget(app());
    taps.tapped(null);
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(opened, isEmpty);
    expect(repository.lookups, 1, reason: 'only the list itself reads');
  });

  testWidgets('a notification this account cannot find opens the list', (
    tester,
  ) async {
    // Another account's push, or one too old to look for: the feed of the
    // account signed in does not have it.
    signIn('student');
    await tester.pumpWidget(app());
    taps.tapped('999');
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(opened, isEmpty);
    expect(repository.markedRead, isEmpty);
  });

  testWidgets('a kind the shell cannot open falls back to the list', (
    tester,
  ) async {
    signIn('student');
    await tester.pumpWidget(app(onOpen: (_) => false));
    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
  });

  testWidgets('a teacher, whose list only marks items read, gets the list', (
    tester,
  ) async {
    signIn('teacher');
    await tester.pumpWidget(app(withOpen: false));
    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsPage), findsOneWidget);
    // Left unread, so it stands out in the list it opened.
    expect(repository.markedRead, isEmpty);
  });

  testWidgets('a page on top is closed first, so the tab is in view', (
    tester,
  ) async {
    signIn('student');
    await tester.pumpWidget(app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const Text('a lesson')),
      ),
    );
    await tester.pumpAndSettle();

    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(find.text('a lesson'), findsNothing);
    expect(find.text('shell'), findsOneWidget);
    expect(opened.map((item) => item.id), ['101']);
  });

  testWidgets('an open dialog is left alone until it closes', (tester) async {
    // The account switch's progress dialog, for one: whoever opened it
    // closes it with Navigator.pop, which must not close a page opened
    // over it instead.
    signIn('student');
    await tester.pumpWidget(app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      showDialog<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('switching')),
      ),
    );
    await tester.pumpAndSettle();

    taps.tapped('101');
    await tester.pumpAndSettle();
    expect(find.text('switching'), findsOneWidget);
    expect(opened, isEmpty);
    expect(taps.pending?.notificationId, '101');

    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(opened.map((item) => item.id), ['101']);
  });

  testWidgets('the outgoing shell of an account switch leaves the tap for '
      'the next one', (tester) async {
    signIn('parent');
    await tester.pumpWidget(app());
    signIn('child'); // Switched; the parent's shell is still on screen.
    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(repository.lookups, 0);
    expect(taps.pending?.notificationId, '101');

    // The child's shell replaces it and opens the tap in the child's feed.
    await tester.pumpWidget(app(shellKey: const ValueKey('child')));
    await tester.pumpAndSettle();
    expect(opened.map((item) => item.id), ['101']);
  });

  testWidgets('a switch while looking it up never opens the old account\'s '
      'notification', (tester) async {
    signIn('parent');
    final gate = Completer<void>();
    repository.gate = gate;
    await tester.pumpWidget(app());
    taps.tapped('101');
    await tester.pump();

    signIn('child');
    gate.complete();
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(repository.markedRead, isEmpty);
    expect(find.byType(NotificationsPage), findsNothing);
    // Handed on, to be looked up again as the child.
    expect(taps.pending?.notificationId, '101');
  });

  testWidgets('nothing opens while nobody is signed in', (tester) async {
    await tester.pumpWidget(app());
    taps.tapped('101');
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.byType(NotificationsPage), findsNothing);
    expect(taps.pending, isNotNull);
  });
}

class _Repository implements NotificationsRepository {
  _Repository(this.items);

  final List<NotificationItem> items;
  final markedRead = <String>[];
  int lookups = 0;

  /// Holds every read until completed.
  Completer<void>? gate;

  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async {
    lookups++;
    await gate?.future;
    return NotificationPage(
      items: List.of(items),
      nextCursor: null,
      isFromCache: false,
    );
  }

  @override
  Future<void> markRead({required List<String> ids, required bool all}) async =>
      markedRead.addAll(ids);

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> syncPending() async {}

  @override
  Future<List<NotificationPreference>> preferences() async => const [];

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
}
