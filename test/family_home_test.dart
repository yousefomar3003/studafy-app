import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_home_page.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/family/presentation/family_strings.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// MOB-070 parent slice: a guardian's home runs on typed /v1 data, only a
/// verified link opens a child, linking goes through the school, and
/// purchase approval proves a recent sign-in before deciding.
class _Fake implements FamilyRepository, PurchaseApprovalRepository {
  _Fake(this.children_);

  final List<GuardianChild> children_;
  final List<String> requested = [];
  final List<(String, bool)> decisions = [];
  List<PurchaseApprovalRequest> approvals = const [];

  @override
  Future<List<GuardianChild>> children() async => List.of(children_);

  @override
  Future<LocatedStudent?> locate(String studafyId) async =>
      studafyId == 'STU-42'
      ? const LocatedStudent(studentId: 'student-42', displayName: 'Omar')
      : null;

  @override
  Future<GuardianChild> requestLink(
    String studentId, {
    String? relationship,
  }) async {
    requested.add(studentId);
    final child = GuardianChild(
      linkId: 'link-new',
      studentId: studentId,
      studentName: 'Omar',
      schoolId: 'school-1',
      schoolName: 'Al-Noor',
      status: GuardianLinkStatus.pending,
    );
    children_.add(child);
    return child;
  }

  @override
  Future<ChildProgress> progress(String studentId) async => const ChildProgress(
    gradedCount: 2,
    averagePercent: 75,
    present: 8,
    late: 1,
    absent: 1,
    excused: 3,
  );

  @override
  Future<List<PurchaseApprovalRequest>> pending() async => approvals;

  @override
  Future<void> decide(String approvalId, {required bool approve}) async =>
      decisions.add((approvalId, approve));
}

const _verified = GuardianChild(
  linkId: 'link-1',
  studentId: 'student-1',
  studentName: 'Layla',
  schoolId: 'school-1',
  schoolName: 'Al-Noor',
  status: GuardianLinkStatus.verified,
);
const _pending = GuardianChild(
  linkId: 'link-2',
  studentId: 'student-2',
  studentName: 'Sami',
  schoolId: 'school-1',
  schoolName: 'Al-Noor',
  status: GuardianLinkStatus.pending,
);

Widget _app(
  _Fake fake, {
  Future<void> Function()? reauth,
  void Function(GuardianChild)? onOpen,
  Locale locale = const Locale('en'),
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
  builder: (context, child) => FamilyScope(
    interactor: FamilyInteractor(
      family: fake,
      approvals: fake,
      confirmRecentAuth: reauth ?? () async {},
      telemetry: const NoopTelemetry(),
    ),
    child: child!,
  ),
  home: FamilyHomePage(onOpenChild: onOpen),
);

void main() {
  setUp(() => ActiveContextController.instance.selectStudent(null));

  test('every family string exists in English and Arabic', () {
    final keys = familyStringKeys();
    expect(keys['ar'], keys['en']);
  });

  test('attendance ignores excused sessions and counts late as present', () {
    const progress = ChildProgress(
      gradedCount: 0,
      present: 8,
      late: 1,
      absent: 1,
      excused: 3,
    );
    expect(progress.attendancePercent, 90);
    expect(progress.sessions, 13);
  });

  testWidgets('children show their link status and the first verified child '
      'becomes the selected one', (tester) async {
    GuardianChild? selected;
    await tester.pumpWidget(
      _app(_Fake([_verified, _pending]), onOpen: (c) => selected = c),
    );
    await tester.pumpAndSettle();
    expect(find.text('Layla'), findsOneWidget);
    expect(find.text('Linked'), findsOneWidget);
    expect(find.text('Sami'), findsOneWidget);
    expect(find.text('Waiting for the school'), findsOneWidget);
    expect(selected?.studentId, 'student-1');
  });

  testWidgets('a pending child cannot be opened', (tester) async {
    await tester.pumpWidget(_app(_Fake([_pending])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sami'));
    await tester.pumpAndSettle();
    expect(find.textContaining('progress'), findsNothing);
  });

  testWidgets('a verified child opens progress with sourced figures', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Fake([_verified])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Layla'));
    await tester.pumpAndSettle();
    expect(find.text('Layla\'s progress'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.textContaining('published'), findsWidgets);
  });

  testWidgets('linking finds the student by Studafy ID and requests a link', (
    tester,
  ) async {
    final fake = _Fake([]);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(find.text('No children linked yet'), findsOneWidget);
    await tester.tap(find.text('Link a child'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NOPE');
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No student has that Studafy ID'), findsOne);

    await tester.enterText(find.byType(TextField), 'STU-42');
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request link to Omar'));
    await tester.pumpAndSettle();
    expect(fake.requested, ['student-42']);
    expect(find.text('Waiting for the school'), findsOneWidget);
  });

  testWidgets('approving proves a recent sign-in first', (tester) async {
    final fake = _Fake([_verified])
      ..approvals = [
        PurchaseApprovalRequest(
          id: 'approval-1',
          studentId: 'student-1',
          studentName: 'Layla',
          featureKey: 'student_notebook',
          status: 'requested',
          expiresAt: DateTime(2030),
        ),
      ];
    var reauthCalls = 0;
    await tester.pumpWidget(
      _app(
        fake,
        reauth: () async {
          reauthCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting for your approval'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(reauthCalls, 1);
    expect(fake.decisions, [('approval-1', true)]);
  });

  testWidgets('a stale sign-in blocks the decision and says what to do', (
    tester,
  ) async {
    final fake = _Fake([_verified])
      ..approvals = [
        PurchaseApprovalRequest(
          id: 'approval-1',
          studentId: 'student-1',
          studentName: 'Layla',
          featureKey: 'student_notebook',
          status: 'requested',
          expiresAt: DateTime(2030),
        ),
      ];
    await tester.pumpWidget(
      _app(
        fake,
        reauth: () async =>
            throw const Failure('REAUTH_REQUIRED', 'REAUTH_REQUIRED'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(fake.decisions, isEmpty);
    expect(find.textContaining('sign in again'), findsOneWidget);
  });

  testWidgets('the home screen is translated in Arabic', (tester) async {
    await tester.pumpWidget(
      _app(_Fake([_verified]), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(find.text('عائلتي'), findsOneWidget);
    expect(find.text('مرتبط'), findsOneWidget);
  });
}
