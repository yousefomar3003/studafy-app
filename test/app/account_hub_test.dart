import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/app/student_shell.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/account/domain/data_export.dart';
import 'package:studafy/features/account/domain/profile_repository.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// Apple 5.1.1(v) / Google Play: sign-out and in-app account deletion must
/// be reachable for every role. Before this screen the student shell had no
/// account entry at all, in any build.
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

class _Exports implements DataExportRepository {
  _Exports(this.current);

  DataExportStatus? current;
  int requests = 0;

  @override
  Future<DataExportStatus?> status() async => current;
  @override
  Future<DataExportStatus> request() async {
    requests++;
    return current = DataExportStatus(
      id: 'export-1',
      state: DataExportState.pending,
      requestedAt: DateTime(2026, 9, 19),
    );
  }

  @override
  Future<String> download() async => '{}';
}

class _Profiles implements ProfileRepository {
  String name = 'Rana Haddad';
  final renamed = <String>[];

  @override
  Future<void> updateLocale(String locale) async {}
  @override
  Future<String?> readLocale() async => null;
  @override
  Future<OwnProfile> readOwn() async =>
      OwnProfile(displayName: name, publicId: '4827159360');
  @override
  Future<OwnProfile> rename(String displayName) async {
    renamed.add(displayName);
    name = displayName;
    return readOwn();
  }
}

Widget _app(
  Widget home, {
  DataExportRepository? exports,
  ProfileRepository? profiles,
}) => MaterialApp(
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => AccountScope(
    account: AccountInteractor(
      _Account(),
      exports: exports,
      profiles: profiles,
    ),
    child: child!,
  ),
  home: home,
);

void main() {
  tearDown(() {
    ActiveContextController.instance
      ..profile = null
      ..membership = null;
  });

  testWidgets('the account screen shows the signed-in person, not a sample', (
    tester,
  ) async {
    const membership = SchoolMembership(
      id: 'membership-1',
      schoolId: 'school-1',
      schoolName: 'Al-Noor International',
      role: StudafyRole.student,
      active: true,
    );
    ActiveContextController.instance
      ..membership = membership
      ..profile = const UserProfile(
        id: 'user-1',
        displayName: 'Sara Al-Amin',
        email: 'sara@example.test',
        memberships: [membership],
      );
    // Tall enough that the whole account screen is built, sign-out and
    // account deletion at the bottom included.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const AccountHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sara Al-Amin'), findsOneWidget);
    expect(find.text('sara@example.test'), findsOneWidget);
    // Notification settings are adjusted here, in every role.
    expect(find.text('Notification preferences'), findsOneWidget);
    // The header shows these as separate chips now; both must still be the
    // real school and role, not a sample.
    expect(find.text('Al-Noor International'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    // Deleting the account lives in Sign-in and security, not on the
    // profile itself.
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Nadia Hassan'), findsNothing);
    // No photo on this device: the first two letters of the name.
    expect(find.text('SA'), findsWidgets);
  });

  testWidgets('the student shell reaches the account screen', (tester) async {
    await tester.pumpWidget(
      _app(StudentShell(academic: PreviewAcademicRepository())),
    );
    await tester.pump();
    expect(find.byTooltip('Account'), findsWidgets);
    await tester.tap(find.byTooltip('Account').first);
    await tester.pumpAndSettle();
    expect(find.byType(AccountHubPage), findsOneWidget);
    expect(find.text('Notification preferences'), findsOneWidget);
  });

  testWidgets('the profile button is on Today only, beside the logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(StudentShell(academic: PreviewAcademicRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Studafy'), findsOne);
    expect(find.byTooltip('Notifications'), findsOne);
    expect(find.byTooltip('Account'), findsOne);

    for (final tab in ['Lessons', 'Work']) {
      await tester.tap(find.byTooltip(tab));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Account'), findsNothing, reason: tab);
    }
  });

  testWidgets('a person can request a copy of their data', (tester) async {
    final exports = _Exports(null);
    await tester.pumpWidget(_app(const AccountHubPage(), exports: exports));
    await tester.pumpAndSettle();
    expect(find.text('Download my data'), findsOneWidget);
    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    expect(exports.requests, 1);
    expect(find.textContaining('Preparing your copy'), findsOneWidget);
  });

  testWidgets('a ready copy offers a download', (tester) async {
    final exports = _Exports(
      DataExportStatus(
        id: 'export-1',
        state: DataExportState.ready,
        requestedAt: DateTime(2026, 9, 19),
        readyAt: DateTime(2026, 9, 19),
      ),
    );
    await tester.pumpWidget(_app(const AccountHubPage(), exports: exports));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('builds without a server show no export row', (tester) async {
    await tester.pumpWidget(_app(const AccountHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('Download my data'), findsNothing);
  });

  testWidgets('a student is shown one ID to share, and the account id only '
      'under sign-in and security', (tester) async {
    ActiveContextController.instance
      ..profile = const UserProfile(
        id: 'user-uuid-1',
        displayName: 'Sara Al-Amin',
        email: 'sara@example.test',
        memberships: [],
      )
      ..membership = const SchoolMembership(
        id: 'membership-1',
        schoolId: 'school-1',
        schoolName: 'Al-Noor International',
        role: StudafyRole.student,
        active: true,
      );
    await tester.pumpWidget(_app(const AccountHubPage()));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE INFORMATION'), findsOne);
    expect(find.text('Account ID'), findsNothing);
    await tester.scrollUntilVisible(find.text('Technical account ID'), 200);
    expect(find.text('Technical account ID'), findsOne);
    expect(find.text('SIGN-IN AND SECURITY'), findsOne);
  });

  testWidgets(
    "a teacher's internal account id is kept under sign-in and security",
    (tester) async {
      ActiveContextController.instance
        ..profile = const UserProfile(
          id: 'user-uuid-2',
          displayName: 'Rana Haddad',
          email: 'rana@example.test',
          memberships: [],
        )
        ..membership = const SchoolMembership(
          id: 'membership-2',
          schoolId: 'school-1',
          schoolName: 'Al-Noor International',
          role: StudafyRole.teacher,
          active: true,
        );
      await tester.pumpWidget(_app(const AccountHubPage()));
      await tester.pumpAndSettle();
      // The UUID that read like a link is gone from the profile; it is the
      // technical id now, explained, with the security controls.
      expect(find.text('Account ID'), findsNothing);
      await tester.scrollUntilVisible(find.text('Technical account ID'), 200);
      expect(find.text('Technical account ID'), findsOne);
    },
  );

  testWidgets('anyone can change their name, in any script, and it is saved', (
    tester,
  ) async {
    ActiveContextController.instance
      ..profile = const UserProfile(
        id: 'user-uuid-3',
        displayName: 'Rana Haddad',
        email: 'rana@example.test',
        memberships: [],
      )
      ..signedInAs = StudafyRole.parent;
    final profiles = _Profiles();
    await tester.pumpWidget(_app(const AccountHubPage(), profiles: profiles));
    await tester.pumpAndSettle();

    // An adult sees their numeric Studafy ID, never the internal UUID.
    expect(find.textContaining('4827159360'), findsOne);
    expect(find.textContaining('user-uuid-3'), findsNothing);

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Rana Haddad'), findsOne);

    // Blank is refused before it is sent.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name of up to 160 characters.'), findsOne);
    expect(profiles.renamed, isEmpty);

    await tester.enterText(find.byType(TextField), '  رنا   حداد ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(profiles.renamed, ['رنا حداد']);
    expect(ActiveContextController.instance.profile?.displayName, 'رنا حداد');
    expect(find.text('Name saved'), findsOne);
  });

  test(
    'a teacher\'s Studafy ID reads as a code; a parent\'s is the number',
    () {
      expect(studafyIdFor('9963198566', teacher: true), 'TC-9963198566');
      expect(studafyIdFor('8279671903', teacher: false), '8279671903');
    },
  );

  testWidgets('a teacher sees their Studafy ID as a TC- code', (tester) async {
    const teaching = SchoolMembership(
      id: 'membership-t',
      schoolId: 'school-1',
      schoolName: 'Rara Nana',
      role: StudafyRole.teacher,
      active: true,
    );
    ActiveContextController.instance
      ..profile = const UserProfile(
        id: 'user-uuid-4',
        displayName: 'Mr.ahmad',
        email: 'ahmad@example.test',
        memberships: [teaching],
      )
      ..membership = teaching;
    await tester.pumpWidget(
      _app(const AccountHubPage(), profiles: _Profiles()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TC-4827159360'), findsOne);
  });
}
