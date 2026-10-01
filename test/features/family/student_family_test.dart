import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/data/preview_family_repository.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/features/family/presentation/student_family_page.dart';

import '../../support/localized_app.dart';

/// An older server answering with one record per teacher's school.
class _TwoRecords extends _Repository {
  @override
  Future<StudentFamily> studentFamily() async => StudentFamily(
    identities: const [
      StudentIdentity(id: 'a', studafyId: 'SJ-01F922B050', name: 'Sara'),
      StudentIdentity(id: 'b', studafyId: 'SJ-5D6BE979D9', name: 'Sara'),
    ],
    requests: const [],
  );
}

class _Repository extends PreviewFamilyRepository {
  final decisions = <(String, String)>[];
  @override
  Future<void> decideGuardian(String id, String decision) async {
    decisions.add((id, decision));
    await super.decideGuardian(id, decision);
  }
}

Widget _app(_Repository repository, String locale) => localizedApp(
  locale: Locale(locale),
  home: FamilyScope(
    interactor: FamilyInteractor(
      family: repository,
      approvals: repository,
      confirmRecentAuth: () async {},
      telemetry: const NoopTelemetry(),
    ),
    child: const StudentFamilyPage(),
  ),
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

  testWidgets('a student is shown one Studafy ID, never two', (tester) async {
    await tester.pumpWidget(_app(_TwoRecords(), 'en'));
    await tester.pumpAndSettle();
    expect(find.text('MY STUDAFY ID'), findsOneWidget);
    expect(find.text('SJ-01F922B050'), findsOneWidget);
    expect(find.text('SJ-5D6BE979D9'), findsNothing);
  });
}
