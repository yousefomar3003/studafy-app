import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import 'support/localized_app.dart';
import 'support/session_repository_fake.dart';

/// MOB-070 (ADR-0028): the screens translated in this change render Arabic
/// and lay out right-to-left, and leave no English behind.
///
/// Asserting the English is *absent* is the part that matters: a screen that
/// finds its Arabic string but still shows an English button is exactly the
/// half-translated state this work exists to remove.
void main() {
  testWidgets('role selection', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: RolePage(session: _session()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('كيف ستستخدم ستودافاي؟'), findsOneWidget);
    expect(find.text('معلم'), findsOneWidget);
    expect(find.text('ولي أمر'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
    expect(find.text('Teacher'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(directionOf(tester, find.byType(Scaffold)), TextDirection.rtl);
  });

  testWidgets('academic workspace', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('ar'),
        home: AcademicOverviewPage(repository: PreviewAcademicRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مساحة العمل الدراسية'), findsOneWidget);
    // Feed tabs used to render the raw enum name, so they read "assignments"
    // in both languages.
    expect(find.text('الواجبات'), findsOneWidget);
    expect(find.text('الدرجات'), findsOneWidget);
    expect(find.text('assignments'), findsNothing);
    expect(find.text('Academic workspace'), findsNothing);
    expect(directionOf(tester, find.byType(Scaffold)), TextDirection.rtl);
  });

  testWidgets('English stays English', (tester) async {
    // The mirror case, so a test that passes by translating everything
    // unconditionally would fail here.
    await tester.pumpWidget(
      localizedApp(
        locale: const Locale('en'),
        home: RolePage(session: _session()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How will you use Studafy?'), findsOneWidget);
    expect(find.text('كيف ستستخدم ستودافاي؟'), findsNothing);
    expect(directionOf(tester, find.byType(Scaffold)), TextDirection.ltr);
  });
}

/// The role screen only needs an interactor to exist; nothing here signs in.
SessionInteractor _session() => SessionInteractor(
  repository: _Repository(),
  context: ActiveContextController.instance,
  telemetry: const NoopTelemetry(),
  runtimePolicy: const RuntimePolicy(StudafyEnvironment.synthetic),
);

class _Repository extends FakeSessionRepositoryBase {
  @override
  bool get hasCurrentSession => false;

  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<void> recordTermsConsent({required String locale}) async {}
}
