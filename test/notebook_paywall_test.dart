import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:studafy/app/student_notebook_subscription_page.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';
import 'package:studafy/features/notebook/domain/notebook_subscription_repository.dart';

class Subscription extends Fake implements NotebookSubscriptionRepository {
  NotebookSubscription status = const NotebookSubscription();
  final List<VoidCallback> listeners = [];
  @override
  Future<NotebookSubscription> notebookStatus() async => status;
  @override
  void addEntitlementListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeEntitlementListener(VoidCallback listener) =>
      listeners.remove(listener);
}

void main() {
  for (final locale in ['en', 'ar']) {
    testWidgets('Notebook mounts content only with verified access ($locale)', (
      tester,
    ) async {
      final subscription = Subscription();
      var mountedContent = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: StudentNotebookSubscriptionPage(
            subscription: subscription,
            contentBuilder: (_) {
              mountedContent++;
              return const Text('protected lessons');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mountedContent, 0);
      expect(find.text('protected lessons'), findsNothing);
      subscription.status = NotebookSubscription(
        active: true,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      subscription.listeners.single();
      await tester.pumpAndSettle();
      expect(find.text('protected lessons'), findsOneWidget);
      subscription.status = const NotebookSubscription();
      subscription.listeners.single();
      await tester.pumpAndSettle();
      expect(find.text('protected lessons'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
