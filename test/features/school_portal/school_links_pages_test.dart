import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/school_portal/application/school_links_interactor.dart';
import 'package:studafy/features/school_portal/domain/school_links.dart';
import 'package:studafy/features/school_portal/presentation/school_announcements_page.dart';
import 'package:studafy/features/school_portal/presentation/school_link_banner.dart';
import 'package:studafy/features/school_portal/presentation/school_link_request_page.dart';
import 'package:studafy/features/school_portal/presentation/schools_page.dart';

import '../../support/localized_app.dart';

SchoolLink _link(String id, SchoolLinkStatus status, String school) =>
    SchoolLink(
      id: id,
      status: status,
      requestedAt: DateTime(2026, 11, 5, 9),
      org: SchoolLinkOrg(
        id: 'org-$id',
        name: school,
        city: 'Amman',
        country: 'Jordan',
        kind: SchoolKind.private,
        active: true,
      ),
      requestedBy: const SchoolLinkRequester(
        name: 'Huda Saleh',
        email: 'head@cedar.example',
        jobTitle: 'Principal',
      ),
    );

/// Remembers every change and answers like the server would.
class _Links implements SchoolLinksRepository {
  _Links(this.items);

  List<SchoolLink> items;
  final decisions = <(String, bool, bool)>[];
  final unlinked = <String>[];
  final reports = <(String, SchoolReportReason)>[];

  /// Accepting while linked elsewhere is refused until the teacher agrees.
  bool linkedElsewhere = false;

  List<SchoolAnnouncement> news = const [];

  @override
  Future<List<SchoolLink>> list() async => items;

  @override
  Future<List<SchoolAnnouncement>> announcements() async => news;

  @override
  Future<void> decide(
    String linkId, {
    required bool accept,
    bool replaceCurrent = false,
  }) async {
    if (accept && linkedElsewhere && !replaceCurrent) {
      throw const Failure('LINKED_ELSEWHERE', 'LINKED_ELSEWHERE');
    }
    decisions.add((linkId, accept, replaceCurrent));
  }

  @override
  Future<void> unlink(String linkId) async {
    unlinked.add(linkId);
    items = [
      for (final link in items)
        if (link.id != linkId) link,
    ];
  }

  @override
  Future<void> report(
    String linkId, {
    required SchoolReportReason reason,
    String? details,
  }) async => reports.add((linkId, reason));
}

SchoolLinksInteractor _interactor(_Links links) =>
    SchoolLinksInteractor(links: links, telemetry: const NoopTelemetry());

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets('$language: the request says who asks and what is shared', (
      tester,
    ) async {
      await _phone(tester);
      final links = _Links([
        _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
      ]);
      await tester.pumpWidget(
        localizedApp(
          locale: Locale(language),
          home: SchoolLinkRequestPage(links: _interactor(links), linkId: 'r1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Cedar Grove'), findsWidgets);
      expect(find.text('Huda Saleh'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accepting asks first, then links', (tester) async {
    await _phone(tester);
    final links = _Links([
      _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
    ]);
    await tester.pumpWidget(
      localizedApp(
        home: SchoolLinkRequestPage(links: _interactor(links), linkId: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('What the school will see'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Messages'), 200);
    expect(find.text('What it will never see'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Accept'), 200);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    // The confirmation: Cancel changes nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(links.decisions, isEmpty);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept').last);
    await tester.pumpAndSettle();
    expect(links.decisions, [('r1', true, false)]);
  });

  testWidgets('declining is confirmed and sent as a decline', (tester) async {
    await _phone(tester);
    final links = _Links([
      _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
    ]);
    await tester.pumpWidget(
      localizedApp(
        home: SchoolLinkRequestPage(links: _interactor(links), linkId: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Decline'), 200);
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(find.textContaining("can't ask again for 30 days"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
    await tester.pumpAndSettle();
    expect(links.decisions, [('r1', false, false)]);
  });

  testWidgets('one school at a time: the teacher agrees to leave the first', (
    tester,
  ) async {
    await _phone(tester);
    final links = _Links([
      _link('now', SchoolLinkStatus.linked, 'Oak Hill'),
      _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
    ])..linkedElsewhere = true;
    await tester.pumpWidget(
      localizedApp(
        home: SchoolLinkRequestPage(links: _interactor(links), linkId: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Accept'), 200);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Accept').last);
    await tester.pumpAndSettle();
    expect(find.text("You're linked with another school"), findsOneWidget);
    expect(find.textContaining('Oak Hill'), findsWidgets);
    await tester.tap(find.text('Unlink and accept'));
    await tester.pumpAndSettle();
    expect(links.decisions, [('r1', true, true)]);
  });

  testWidgets('a school can be reported with a reason', (tester) async {
    await _phone(tester);
    final links = _Links([
      _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
    ]);
    await tester.pumpWidget(
      localizedApp(
        home: SchoolLinkRequestPage(links: _interactor(links), linkId: 'r1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Report this school'), 200);
    await tester.tap(find.text('Report this school'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm being pressured to accept"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(links.reports, [('r1', SchoolReportReason.pressure)]);
  });

  testWidgets('the banner names the school and unlinks after a confirmation', (
    tester,
  ) async {
    await _phone(tester);
    final links = _Links([_link('now', SchoolLinkStatus.linked, 'Oak Hill')]);
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: SchoolLinkBanner(links: _interactor(links))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your classes are visible to'), findsOneWidget);
    await tester.tap(find.text('Unlink'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
    await tester.pumpAndSettle();
    expect(links.unlinked, ['now']);
    expect(find.textContaining('Your classes are visible to'), findsNothing);
  });

  testWidgets('no banner while no school is linked', (tester) async {
    await _phone(tester);
    final links = _Links([
      _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
    ]);
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: SchoolLinkBanner(links: _interactor(links))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Your classes are visible to'), findsNothing);
  });

  testWidgets(
    'Schools lists the linked school, waiting requests and earlier ones',
    (tester) async {
      await _phone(tester);
      final links = _Links([
        _link('now', SchoolLinkStatus.linked, 'Oak Hill'),
        _link('r1', SchoolLinkStatus.pending, 'Cedar Grove'),
        _link('old', SchoolLinkStatus.declined, 'Pine Academy'),
      ]);
      await tester.pumpWidget(
        localizedApp(home: SchoolsPage(links: _interactor(links))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Linked now'), findsOneWidget);
      expect(find.text('Waiting for your answer'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Schools says when no school has asked', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      localizedApp(home: SchoolsPage(links: _interactor(_Links([])))),
    );
    await tester.pumpAndSettle();
    expect(find.text('No school has asked to link with you.'), findsOneWidget);
  });

  testWidgets('From your school shows each announcement, or says none came', (
    tester,
  ) async {
    await _phone(tester);
    final links = _Links([])
      ..news = [
        SchoolAnnouncement(
          id: 'a1',
          title: 'Sports day',
          body: 'Friday from 9.',
          school: 'Cedar Grove',
          createdAt: DateTime(2026, 11, 3, 8),
        ),
      ];
    await tester.pumpWidget(
      localizedApp(home: SchoolAnnouncementsPage(links: _interactor(links))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sports day'), findsOneWidget);
    expect(find.text('Cedar Grove'), findsOneWidget);
    await tester.pumpWidget(
      localizedApp(
        home: SchoolAnnouncementsPage(
          key: const ValueKey('empty'),
          links: _interactor(_Links([])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No announcements from a school yet.'), findsOneWidget);
  });
}
