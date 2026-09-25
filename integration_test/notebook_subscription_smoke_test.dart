import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/app/student_notebook_subscription_page.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/features/notebook/domain/notebook_subscription_repository.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

// Synthetic store disclosure only. Never grants access or initiates payment.
class _Preview extends Fake implements NotebookSubscriptionRepository {
  @override
  Future<NotebookSubscription> notebookStatus() async =>
      const NotebookSubscription(
        price: '\$2.49',
        currency: 'USD',
        monthly: true,
        oneMonthTrial: true,
        storeAvailable: true,
        selfPurchaseEnabled: true,
        approval: 'requested',
      );
  @override
  void addEntitlementListener(VoidCallback listener) {}
  @override
  void removeEntitlementListener(VoidCallback listener) {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Notebook monthly trial disclosures render on iPhone in both languages',
    (tester) async {
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
            home: StudentNotebookSubscriptionPage(
              subscription: _Preview(),
              contentBuilder: (_) => const Text('protected'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('protected'), findsNothing);
        expect(find.textContaining('\$2.49'), findsWidgets);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('notebook-paywall-$language');
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('notebook-disclosures-$language');
      }
    },
  );
}
