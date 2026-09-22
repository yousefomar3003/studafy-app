import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/data/preview_family_repository.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/family/presentation/student_family_page.dart';

class _Repository extends PreviewFamilyRepository {
  final decisions = <(String, String)>[];
  @override
  Future<void> decideGuardian(String id, String decision) async {
    decisions.add((id, decision));
    await super.decideGuardian(id, decision);
  }
}

Widget _app(_Repository repository, String locale) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => FamilyScope(
    interactor: FamilyInteractor(
      family: repository,
      approvals: repository,
      confirmRecentAuth: () async {},
      telemetry: const NoopTelemetry(),
    ),
    child: child!,
  ),
  home: const StudentFamilyPage(),
);

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      'student consent requires confirmation and can be revoked ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        await tester.pumpWidget(_app(repository, language));
        await tester.pumpAndSettle();
        expect(find.text('STU-DEMO-1'), findsOneWidget);
        final approve = find.text(
          language == 'en' ? 'This is my parent' : 'هذا ولي أمري',
        );
        await tester.ensureVisible(approve);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        await tester.tap(find.text(language == 'en' ? 'Cancel' : 'إلغاء'));
        await tester.pumpAndSettle();
        expect(repository.decisions, isEmpty);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        await tester.tap(find.text(language == 'en' ? 'Confirm' : 'تأكيد'));
        await tester.pumpAndSettle();
        expect(repository.decisions, [('preview-parent-request', 'approve')]);
        final revoke = find.text(
          language == 'en' ? 'Remove access' : 'إزالة الوصول',
        );
        await tester.ensureVisible(revoke);
        await tester.tap(revoke);
        await tester.pumpAndSettle();
        await tester.tap(find.text(language == 'en' ? 'Confirm' : 'تأكيد'));
        await tester.pumpAndSettle();
        expect(repository.decisions.last, ('preview-parent-request', 'revoke'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
