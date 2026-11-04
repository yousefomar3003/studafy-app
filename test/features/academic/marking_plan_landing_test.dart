import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_components.dart';
import 'package:studafy/features/academic/data/preview_marking_repository.dart';
import 'package:studafy/features/academic/domain/marking.dart';
import 'package:studafy/features/academic/presentation/marking_plan_explainer.dart';
import 'package:studafy/features/academic/presentation/marking_plan_page.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';

/// The Studafy AI Marking page as a landing page (2026-11-04): what it does
/// and a worked example before the price - and, as App Store 3.1.2 needs,
/// the store's price, the renewal terms, Terms and Privacy and Restore
/// purchases still on the same screen.

MarkingPlan _plan({
  bool active = false,
  bool granted = false,
  bool available = true,
}) => MarkingPlan(
  active: active,
  granted: granted,
  teacher: true,
  available: available,
  used: 1_000_000,
  total: 7_000_000,
  resetsAt: DateTime.utc(2026, 12),
);

class _Store implements MarkingPlanStore {
  @override
  bool get sellsMarkingPlan => true;

  @override
  Future<MarkingPlanOffer> markingOffer() async => const MarkingPlanOffer(
    storeAvailable: true,
    price: r'$7.99',
    currencyCode: 'USD',
    periodLabel: 'month',
  );

  @override
  Future<void> purchaseMarkingPlan() async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void addEntitlementListener(void Function() listener) {}

  @override
  void removeEntitlementListener(void Function() listener) {}
}

Future<void> _open(
  WidgetTester tester,
  MarkingPlan plan, {
  Locale? locale,
  Size size = const Size(1000, 6000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      home: MarkingPlanPage(
        services: MarkingServices(
          repository: PreviewMarkingRepository(plan: plan),
          plans: _Store(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

const _disclosure =
    'Auto-renewing monthly subscription, paid through your app store '
    'account. It renews unless cancelled at least 24 hours before the end '
    'of the period; cancel any time in your store subscription settings. '
    'Studafy never sees your card details.';

void main() {
  testWidgets('a teacher without the plan sees what it does, a worked '
      'example, what is included and why to trust it - then the price', (
    tester,
  ) async {
    await _open(tester, _plan());

    // The promise.
    expect(find.text('Mark written answers in minutes'), findsOneWidget);
    expect(
      find.text(
        'AI suggests a mark for each answer, compared with your own '
        'reference. You decide every mark.',
      ),
      findsOneWidget,
    );

    // How it works, in three steps.
    expect(find.text('How it works'), findsOneWidget);
    for (final step in [
      'Write what a good answer contains: a model answer or key points, and '
          'what each is worth.',
      'Ask for suggested marks for the work waiting to be marked.',
      'Review each suggestion, adjust it if you need to, and save.',
    ]) {
      expect(find.text(step), findsOneWidget);
    }

    // The worked example, labelled, drawn with the real review.
    expect(find.byType(MarkingExampleCard), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Why do green plants need sunlight?'), findsOneWidget);
    expect(find.text('Oxygen is given off (worth 1)'), findsOneWidget);
    expect(find.text('3 of 4'), findsOneWidget);
    expect(find.text('Met'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Does not say that oxygen is given off'), findsOneWidget);
    expect(
      find.text(
        'Clear explanation of how the plant makes its food. Add what it '
        'gives off: oxygen.',
      ),
      findsOneWidget,
    );
    // A sample: nothing on it can be used or dismissed.
    expect(find.text('Use suggestion'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);

    // What is included, with the allowance as a conservative figure.
    expect(
      find.text('Suggested marks for written answers in online tests.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Suggested marks for handed-in work: typed text, PDF, Word, '
        'PowerPoint and photos of handwriting.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Enough for about 2,500 written answers a month. Photos of '
        'handwriting use more of it.',
      ),
      findsOneWidget,
    );

    // Trust.
    expect(
      find.text(
        'You decide every mark. AI never marks work on its own, and nothing '
        'is saved until you save it.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Names are replaced before anything is sent to the AI (Together AI).',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Students' work is not used to train any AI model."),
      findsOneWidget,
    );

    // Compliance: the store's price, the subscribe button, the renewal
    // terms, Terms and Privacy, Manage and Restore - all on this screen.
    expect(find.text(r'$7.99 / month'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Manage or cancel'), findsOneWidget);

    // The value comes before the price.
    final price = _top(tester, find.text(r'$7.99 / month'));
    expect(_top(tester, find.text('How it works')), lessThan(price));
    expect(_top(tester, find.byType(MarkingExampleCard)), lessThan(price));
    expect(_top(tester, find.text('You stay in charge')), lessThan(price));
    expect(
      _top(tester, find.text('Mark written answers in minutes')),
      lessThan(_top(tester, find.text('How it works'))),
    );
    // No trial is offered or promised.
    expect(find.textContaining('trial'), findsNothing);
    expect(find.textContaining('free'), findsNothing);
  });

  testWidgets('a teacher with the plan sees it and this month\'s usage '
      'first, then the explainer, and no price', (tester) async {
    await _open(tester, _plan(active: true));
    expect(find.byType(PlanSummaryCard), findsOneWidget);
    expect(find.byType(MarkingAllowance), findsOneWidget);
    expect(find.text('Mark written answers in minutes'), findsNothing);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text(r'$7.99 / month'), findsNothing);
    expect(
      _top(tester, find.byType(MarkingAllowance)),
      lessThan(_top(tester, find.text('How it works'))),
    );
    expect(find.byType(MarkingExampleCard), findsOneWidget);
    // Still able to manage, restore, and read the terms.
    expect(find.text('Manage or cancel'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text(_disclosure), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('a plan Studafy gave shows its allowance, with nothing to '
      'buy or manage', (tester) async {
    await _open(tester, _plan(active: true, granted: true));
    expect(find.text('Given by Studafy, nothing to pay'), findsOneWidget);
    expect(find.byType(MarkingAllowance), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the landing page is accessible on a phone: '
        '${locale.languageCode}', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _plan(), locale: locale, size: const Size(400, 6000));
      expect(tester.takeException(), isNull);
      if (locale.languageCode == 'ar') {
        expect(find.text('صحّح الإجابات المكتوبة في دقائق'), findsOneWidget);
        expect(find.text('مثال'), findsOneWidget);
        expect(find.text('يمتص الكلوروفيل في الأوراق الضوء'), findsWidgets);
        expect(
          Directionality.of(tester.element(find.byType(MarkingExampleCard))),
          TextDirection.rtl,
        );
        expect(find.textContaining(r'$7.99'), findsOneWidget);
      }
      // Contrast in English only: on CI's Linux test font some Arabic words
      // render too thin to sample.
      await expectAccessible(tester, contrast: locale.languageCode == 'en');
      semantics.dispose();
    });
  }
}
