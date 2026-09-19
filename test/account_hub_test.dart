import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/core/account_lifecycle.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/account/domain/data_export.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/student_features.dart';

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

Widget _app(Widget home, {DataExportRepository? exports}) => MaterialApp(
  supportedLocales: StudafyLocalizations.supportedLocales,
  localizationsDelegates: const [
    StudafyLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => AccountScope(
    account: AccountInteractor(_Account(), exports: exports),
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

  test('every account string exists in English and Arabic', () {
    final keys = accountHubStringKeys();
    expect(keys['ar'], keys['en']);
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
    await tester.pumpWidget(_app(const AccountHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('Sara Al-Amin'), findsOneWidget);
    expect(find.text('sara@example.test'), findsOneWidget);
    expect(find.text('Al-Noor International · Student'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Nadia Hassan'), findsNothing);
  });

  testWidgets('the student shell reaches the account screen', (tester) async {
    await tester.pumpWidget(
      _app(StudentShell(academic: PreviewAcademicRepository())),
    );
    await tester.pump();
    expect(find.byIcon(Icons.account_circle_outlined), findsWidgets);
    await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete account'), findsOneWidget);
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
}
