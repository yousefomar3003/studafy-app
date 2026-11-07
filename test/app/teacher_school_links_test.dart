import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/app/teacher_school_links.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/school_portal/application/school_links_interactor.dart';
import 'package:studafy/features/school_portal/domain/school_links.dart';
import 'package:studafy/features/school_portal/presentation/school_link_request_page.dart';
import 'package:studafy/features/school_portal/presentation/schools_page.dart';

import '../support/localized_app.dart';

class _Nothing implements SchoolLinksRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One school waiting for the teacher's answer.
class _Waiting implements SchoolLinksRepository {
  @override
  Future<List<SchoolLink>> list() async => [
    SchoolLink(
      id: 'r1',
      status: SchoolLinkStatus.pending,
      requestedAt: DateTime(2026, 11, 6, 9),
      org: const SchoolLinkOrg(
        id: 'org-1',
        name: 'Cedar Grove School',
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
    ),
  ];

  @override
  Future<List<SchoolGroupClass>> groupClasses() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account implements AccountRepository {
  @override
  Future<DeletionImpact> deletionImpact() => throw UnimplementedError();
  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) => throw UnimplementedError();
  @override
  Future<bool> cancelAccountDeletion() async => false;
}

UserProfile _teacher({required bool schoolPortal}) => UserProfile(
  id: 'teacher-1',
  displayName: 'Rania Haddad',
  email: 'rania@example.test',
  memberships: const [],
  schoolPortal: schoolPortal,
);

/// An adult who teaches at one school and is also a parent.
UserProfile _teachingParent({bool teaches = true}) => UserProfile(
  id: 'teacher-1',
  displayName: 'Rania Haddad',
  email: 'rania@example.test',
  memberships: [
    if (teaches)
      const SchoolMembership(
        id: 'm1',
        schoolId: 'school-1',
        schoolName: 'Al-Noor International',
        role: StudafyRole.teacher,
        active: true,
      ),
  ],
  accountKind: AccountKind.adult,
  schoolPortal: true,
);

void main() {
  final links = SchoolLinksInteractor(
    links: _Nothing(),
    telemetry: const NoopTelemetry(),
  );

  test('the School Portal appears only while the server says it is on', () {
    expect(schoolLinksWhenOn(_teacher(schoolPortal: true), links), links);
    expect(schoolLinksWhenOn(_teacher(schoolPortal: false), links), isNull);
    expect(schoolLinksWhenOn(null, links), isNull);
    // A build with no server has no links to show, whatever the flag.
    expect(schoolLinksWhenOn(_teacher(schoolPortal: true), null), isNull);
  });

  group('a teacher using the app as a parent', () {
    tearDown(() => ActiveContextController.instance.signOut());

    /// The parent shell's notification handler, in an account scope.
    Widget parentMode(SchoolLinksRepository repository, String? linkId) =>
        localizedApp(
          home: AccountScope(
            account: AccountInteractor(_Account()),
            schoolLinks: SchoolLinksInteractor(
              links: repository,
              telemetry: const NoopTelemetry(),
            ),
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    // What a tapped "a school asks to link" notification
                    // does in the parent shell.
                    onPressed: () => openSchoolLinkIn(context)?.call(linkId),
                    child: Text(
                      openSchoolLinkIn(context) == null ? 'none' : 'open',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets("opens the school's request, which is the account's", (
      tester,
    ) async {
      ActiveContextController.instance.hydrate(
        authenticatedProfile: _teachingParent(),
        signedInAs: StudafyRole.parent,
      );
      await tester.pumpWidget(parentMode(_Waiting(), 'r1'));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolLinkRequestPage), findsOneWidget);
      expect(find.textContaining('Cedar Grove School'), findsWidgets);
      expect(find.text('Huda Saleh'), findsOneWidget);
    });

    testWidgets('a class-group question opens the Schools list', (
      tester,
    ) async {
      ActiveContextController.instance.hydrate(
        authenticatedProfile: _teachingParent(),
        signedInAs: StudafyRole.parent,
      );
      await tester.pumpWidget(parentMode(_Waiting(), null));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolsPage), findsOneWidget);
      expect(find.text('Waiting for your answer'), findsOneWidget);
    });

    testWidgets('a parent who teaches nowhere has nothing to open', (
      tester,
    ) async {
      ActiveContextController.instance.hydrate(
        authenticatedProfile: _teachingParent(teaches: false),
        signedInAs: StudafyRole.parent,
      );
      await tester.pumpWidget(parentMode(_Waiting(), 'r1'));
      expect(find.text('none'), findsOneWidget);
    });
  });
}
