import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/study_plans_page.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

// Synthetic store disclosure only. Never grants access or initiates payment.
class _Store extends Fake implements StudyPlanSubscriptionRepository {
  @override
  Future<StudyPlanOffer> offer(StudyPlanTier tier) async => StudyPlanOffer(
    tier: tier,
    price: tier == StudyPlanTier.max ? r'$5.99' : r'$3.99',
    monthly: true,
    storeAvailable: true,
    selfPurchaseEnabled: true,
    approval: 'requested',
  );
  // No store on a simulator test: the page shows the plans, never a
  // purchase sheet.
  @override
  SubscriptionStore? get purchaseStore => null;
  @override
  Future<StudyPlanSubscription?> subscription() async => null;
  @override
  void addEntitlementListener(VoidCallback listener) {}
  @override
  void removeEntitlementListener(VoidCallback listener) {}
}

class _Study extends Fake implements StudyRepository {
  @override
  Future<StudyPlan> plan() async => StudyPlan.free;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('the plans and their disclosures render in both languages', (
    tester,
  ) async {
    // Android screenshots need the surface turned into an image first.
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    for (final language in ['en', 'ar']) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: studafyTheme(),
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: StudyPlansPage(study: _Study(), subscriptions: _Store()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Studafy Plus'), findsOne);
      expect(find.text('Studafy Max'), findsOne);
      expect(find.textContaining(r'$5.99'), findsWidgets);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('study-plans-$language');
    }
  });
}
