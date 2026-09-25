// ignore_for_file: prefer_initializing_formals
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/notifications/application/notifications_interactor.dart';
import 'package:studafy/features/notifications/domain/notification.dart';
import 'package:studafy/features/notifications/domain/notifications_repository.dart';
import 'package:studafy/features/notifications/presentation/notifications_page.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// MOB-070 slice 1: proves the presentation layer never sees a transport
/// map (every rendered string comes from a typed [NotificationItem]) and
/// that English/Arabic parity holds for the strings this screen ships.
void main() {
  Widget harness(
    NotificationsRepository repository, {
    Locale locale = const Locale('en'),
    bool visible = true,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: StudafyLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppL10n.delegate,
      StudafyLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: NotificationsScope(
      interactor: NotificationsInteractor(
        repository: repository,
        telemetry: const NoopTelemetry(),
      ),
      child: NotificationsPage(visible: visible),
    ),
  );

  testWidgets('a hidden tab does not load, and loads when it is shown', (
    tester,
  ) async {
    // The shells keep every tab alive in an IndexedStack, so a page that
    // only loads in initState shows whatever was true when the app started:
    // a notification that arrived since launch stayed invisible until the
    // app was killed.
    final repository = _FakeRepository(items: []);

    await tester.pumpWidget(harness(repository, visible: false));
    await tester.pumpAndSettle();
    expect(repository.loads, 0);
    // Not a spinner: nothing is loading, so one would never stop.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(harness(repository, visible: true));
    await tester.pumpAndSettle();
    expect(repository.loads, 1);

    // Staying visible must not re-request on every rebuild elsewhere.
    await tester.pumpWidget(harness(repository, visible: true));
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
  });

  testWidgets('an empty feed shows the empty state, not a blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(harness(_FakeRepository(items: [])));
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets(
    'items render their resolved title/detail text, never a raw key or map',
    (tester) async {
      await tester.pumpWidget(
        harness(
          _FakeRepository(
            items: [
              NotificationItem(
                id: 'n1',
                templateKey: 'academic.grade_published',
                title: 'notification.academic.grade_published.title',
                detail: 'notification.academic.grade_published.detail',
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New grade'), findsOneWidget);
      expect(
        find.text('A grade was published. Open Grades to view it.'),
        findsOneWidget,
      );
      // The raw localization key must never leak onto the screen.
      expect(find.textContaining('notification.academic'), findsNothing);
    },
  );

  testWidgets(
    'marking all read clears the unread styling without a page reload',
    (tester) async {
      final repository = _FakeRepository(
        items: [
          NotificationItem(
            id: 'n1',
            templateKey: 'academic.grade_published',
            title: 'notification.academic.grade_published.title',
            detail: 'notification.academic.grade_published.detail',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      await tester.pumpWidget(harness(repository));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_active_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(repository.markReadCalls.single.all, isTrue);
    },
  );

  testWidgets('an offline cached page shows an honest offline banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        _FakeRepository(
          items: [
            NotificationItem(
              id: 'n1',
              templateKey: 'academic.grade_published',
              title: 'notification.academic.grade_published.title',
              detail: 'notification.academic.grade_published.detail',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
          isFromCache: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Showing your last saved notifications — reconnect to update.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Arabic locale renders the Arabic strings, not English fallback text',
    (tester) async {
      await tester.pumpWidget(
        harness(
          _FakeRepository(
            items: [
              NotificationItem(
                id: 'n1',
                templateKey: 'academic.grade_published',
                title: 'notification.academic.grade_published.title',
                detail: 'notification.academic.grade_published.detail',
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الإشعارات'), findsOneWidget); // "Notifications"
      expect(find.text('درجة جديدة'), findsOneWidget); // "New grade"
      expect(find.text('تعليم الكل كمقروء'), findsOneWidget); // "Mark all read"
    },
  );
}

class _FakeRepository implements NotificationsRepository {
  _FakeRepository({
    required List<NotificationItem> items,
    this.isFromCache = false,
  }) : _items = items;

  final List<NotificationItem> _items;
  final bool isFromCache;
  final markReadCalls = <({List<String> ids, bool all})>[];

  /// First-page reads only, so a test can tell a reload from a rebuild.
  int loads = 0;

  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async {
    if (cursor == null) loads++;
    return NotificationPage(
      items: List.of(_items),
      nextCursor: null,
      isFromCache: isFromCache,
    );
  }

  @override
  Future<int> unreadCount() async =>
      _items.where((item) => !item.isRead).length;

  @override
  Future<void> markRead({required List<String> ids, required bool all}) async {
    markReadCalls.add((ids: ids, all: all));
    for (var i = 0; i < _items.length; i++) {
      if (all || ids.contains(_items[i].id)) {
        _items[i] = _items[i].copyWith(readAt: DateTime.now());
      }
    }
  }

  @override
  Future<void> syncPending() async {}

  @override
  Future<List<NotificationPreference>> preferences() async => const [];

  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
}
