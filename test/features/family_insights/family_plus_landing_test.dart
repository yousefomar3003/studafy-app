import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_components.dart';
import 'package:studafy/features/family_insights/domain/parent_subscription_repository.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_explainer.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_gate.dart';
import 'package:studafy/features/family_insights/presentation/family_plus_prompts.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';

/// Family+ as a landing page (2026-11-04): what it shows for a child, drawn
/// with the real insight cards and labelled Example, how it works, what each
/// plan covers and why to trust it - before the plans, with the store's
/// prices, its own trial wording, the renewal terms, Manage and Terms and
/// Privacy still on the same screen. Also the Today card and the line on a
/// child's marks.

class _Store implements ParentSubscriptionRepository {
  _Store({
    this.plan = FamilyPlusStatus.none,
    Set<String>? active,
    this.sells = true,
    this.trial = true,
  }) : active = active ?? {};

  FamilyPlusStatus plan;
  final Set<String> active;
  final bool sells;
  final bool trial;
  final _listeners = <EntitlementChanged>[];

  void notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  @override
  bool get sellsFamilyPlus => sells;

  @override
  Future<SubscriptionEntitlement> entitlement({
    String? beneficiaryStudentId,
  }) async => SubscriptionEntitlement(
    active: active.contains(beneficiaryStudentId),
    source: 'test',
  );

  @override
  Future<FamilyPlusStatus> familyPlan() async => plan;

  @override
  Future<PaywallOffer> familyOffer(FamilyPlusPlan plan) async => PaywallOffer(
    featureKey: plan.featureKey,
    storeProductId: 'studafy_${plan.featureKey}_monthly',
    storeAvailable: true,
    price: plan == FamilyPlusPlan.upTo4 ? r'$2.99' : r'$4.99',
    currencyCode: 'USD',
    periodLabel: 'month',
    hasTrial: trial,
    trialLengthLabel: trial ? '30 days' : '',
  );

  @override
  Future<void> purchaseFamilyPlan(FamilyPlusPlan plan) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void addEntitlementListener(EntitlementChanged listener) =>
      _listeners.add(listener);

  @override
  void removeEntitlementListener(EntitlementChanged listener) =>
      _listeners.remove(listener);
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _gate(
  WidgetTester tester,
  _Store store, {
  Locale? locale,
  Size size = const Size(1000, 7000),
}) async {
  _size(tester, size);
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      home: FamilyPlusGate(
        subscriptions: store,
        studentId: 'child-1',
        childName: locale?.languageCode == 'ar' ? 'سارة' : 'Sara',
        insights: const Scaffold(body: Text('INSIGHTS')),
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
  setUp(() {
    FamilyPlusHomeCard.showAgain();
    FamilyPlusNudge.showAgain();
  });

  group('the Family+ page', () {
    testWidgets('a parent without Family+ sees the promise, a worked example '
        'for one child, how it works, what it covers and why to trust it - '
        'then the plans', (tester) async {
      await _gate(tester, _Store());

      // The promise, about their own child.
      expect(find.text('See how Sara is really doing'), findsOne);
      expect(
        find.text(
          'Family+ turns the marks, attendance and work you can already see '
          'into trends and what to focus on this week.',
        ),
        findsOne,
      );

      // The worked example, labelled, drawn with the real insight cards.
      expect(find.byType(FamilyPlusExampleCard), findsOne);
      expect(find.text('Example'), findsOne);
      expect(find.text('A sample child, not real records.'), findsOne);
      expect(find.text('What to focus on'), findsOne);
      expect(find.text('Science is their weakest subject right now'), findsOne);
      expect(find.text('Maths'), findsOne);
      expect(find.text('Strongest'), findsOne);
      expect(find.text('Weakest'), findsOne);
      expect(
        find.textContaining('Up 8 points compared with earlier'),
        findsOne,
      );
      expect(find.textContaining('Attendance 96%'), findsOne);
      expect(find.textContaining('2 missing'), findsOne);

      // How it works.
      for (final step in [
        'Link your child with their Studafy ID. They approve it on their own '
            'device.',
        'Family+ brings together the marks, attendance and work you can '
            'already see.',
        'See their trends and what to focus on this week, class by class.',
      ]) {
        expect(find.text(step), findsOne);
      }

      // What it includes, and what each size covers.
      expect(
        find.text('What to focus on this week, most urgent first'),
        findsOne,
      );
      expect(
        find.text(
          'One plan covers up to 4 or up to 8 linked children, earliest '
          'linked first.',
        ),
        findsOne,
      );

      // Trust, as the privacy policy says it.
      expect(
        find.text(
          "Uses no AI. Every insight is worked out from the school's own "
          'records, with the records behind it shown.',
        ),
        findsOne,
      );
      expect(
        find.text(
          'Compares a child only with their own earlier record, never with '
          'other children.',
        ),
        findsOne,
      );
      expect(
        find.text('Shows only what you can already see, summarised.'),
        findsOne,
      );

      // Compliance: the store's prices and its own trial wording, the
      // buttons, the renewal terms, Manage, Terms and Privacy.
      expect(find.text(r'$2.99 / month'), findsOne);
      expect(find.text(r'$4.99 / month'), findsOne);
      expect(
        find.text(r'If eligible, free for 30 days, then $2.99 / month'),
        findsOne,
      );
      expect(find.text('Start free trial'), findsNWidgets(2));
      expect(find.text(_disclosure), findsOne);
      expect(find.text('Manage or cancel'), findsOne);
      expect(find.text('Terms of use'), findsOne);
      expect(find.text('Privacy policy'), findsOne);
      expect(
        find.text(
          'Your children are covered in the order you linked them. A child '
          'you link later is included straight away while the plan has room.',
        ),
        findsOne,
      );
      // Restoring stays on the profile.
      expect(find.text('Restore purchases'), findsNothing);

      // The value comes before the price.
      final price = _top(tester, find.text(r'$2.99 / month'));
      expect(_top(tester, find.byType(FamilyPlusExampleCard)), lessThan(price));
      expect(_top(tester, find.text('How it works')), lessThan(price));
      expect(_top(tester, find.text('Fair and private')), lessThan(price));
      expect(
        _top(tester, find.text('See how Sara is really doing')),
        lessThan(_top(tester, find.byType(FamilyPlusExampleCard))),
      );
    });

    testWidgets('no trial is promised unless the store offers one', (
      tester,
    ) async {
      await _gate(tester, _Store(trial: false));
      expect(find.textContaining('free for'), findsNothing);
      expect(find.text('Start free trial'), findsNothing);
      expect(find.text('Subscribe for up to 4 children'), findsOne);
    });

    testWidgets('with a plan, where the parent stands comes first, and no '
        'example', (tester) async {
      _size(tester, const Size(1000, 4000));
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: FamilyPlusOffer(
              subscriptions: _Store(
                plan: const FamilyPlusStatus(
                  plan: FamilyPlusPlan.upTo4,
                  coveredStudentIds: ['child-1'],
                ),
              ),
              studentId: 'child-1',
              childName: 'Sara',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanSummaryCard), findsOne);
      expect(find.byType(FamilyPlusExampleCard), findsNothing);
      expect(find.text('See how Sara is really doing'), findsNothing);
      expect(find.text('Upgrade to up to 8 children'), findsOne);
      expect(find.text('Manage or cancel'), findsOne);
      expect(find.text(_disclosure), findsOne);
      expect(
        find.text('What to focus on this week, most urgent first'),
        findsOne,
      );
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('the page is accessible on a phone: ${locale.languageCode}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _gate(
          tester,
          _Store(),
          locale: locale,
          size: const Size(400, 7000),
        );
        expect(tester.takeException(), isNull);
        if (locale.languageCode == 'ar') {
          expect(find.text('تابِع مستوى سارة الحقيقي'), findsOne);
          expect(find.text('مثال'), findsOne);
          expect(find.text('العلوم'), findsOne);
          expect(
            Directionality.of(
              tester.element(find.byType(FamilyPlusExampleCard)),
            ),
            TextDirection.rtl,
          );
          expect(find.textContaining(r'$2.99'), findsWidgets);
        }
        await expectAccessible(tester, contrast: locale.languageCode == 'en');
        semantics.dispose();
      });
    }
  });

  group('the Family+ card on Today', () {
    Future<List<String>> card(
      WidgetTester tester,
      ParentSubscriptionRepository? store, {
      List<String> children = const ['child-1', 'child-2'],
      Locale? locale,
    }) async {
      final opened = <String>[];
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: Scaffold(
            body: ListView(
              children: [
                FamilyPlusHomeCard(
                  subscriptions: store,
                  studentIds: children,
                  onOpen: () => opened.add('family+'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('a parent with a linked child and no Family+ is offered it', (
      tester,
    ) async {
      final opened = await card(tester, _Store());
      expect(
        find.text(
          'Trends, missing work and what to focus on this week, for each of '
          'your children.',
        ),
        findsOne,
      );
      await tester.tap(find.text('See Family+'));
      expect(opened, ['family+']);
    });

    testWidgets('hidden once Family+ is bought', (tester) async {
      final store = _Store();
      await card(tester, store);
      expect(find.text('See Family+'), findsOne);
      store.plan = const FamilyPlusStatus(
        plan: FamilyPlusPlan.upTo4,
        coveredStudentIds: ['child-1', 'child-2'],
      );
      store.notify();
      await tester.pumpAndSettle();
      expect(find.text('See Family+'), findsNothing);
    });

    testWidgets('hidden when a child is unlocked another way', (tester) async {
      await card(tester, _Store(active: {'child-2'}));
      expect(find.text('See Family+'), findsNothing);
    });

    testWidgets('hidden with no linked child, or where it is not sold', (
      tester,
    ) async {
      await card(tester, _Store(), children: const []);
      expect(find.text('See Family+'), findsNothing);
      await card(tester, _Store(sells: false));
      expect(find.text('See Family+'), findsNothing);
      await card(tester, null);
      expect(find.text('See Family+'), findsNothing);
    });

    testWidgets('Hide puts it away until the app closes', (tester) async {
      await card(tester, _Store());
      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('See Family+'), findsNothing);
    });

    testWidgets('reads in Arabic', (tester) async {
      await card(tester, _Store(), locale: const Locale('ar'));
      expect(find.text('اطّلع على \u2066Family+\u2069'), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('the line on a child\'s marks', () {
    Future<List<String>> nudge(
      WidgetTester tester,
      _Store store, {
      String studentId = 'child-1',
    }) async {
      final opened = <String>[];
      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: Column(
              children: [
                FamilyPlusNudge(
                  subscriptions: store,
                  studentId: studentId,
                  childName: studentId == 'child-1' ? 'Sara' : 'Omar',
                  onOpen: () => opened.add(studentId),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('without Family+ for the child it says what it would show', (
      tester,
    ) async {
      final opened = await nudge(tester, _Store());
      expect(
        find.text('See trends and what to focus on for Sara with Family+'),
        findsOne,
      );
      await tester.tap(find.text('See Family+'));
      expect(opened, ['child-1']);
    });

    testWidgets('nothing for a child who has Family+', (tester) async {
      await nudge(tester, _Store(active: {'child-1'}));
      expect(find.textContaining('with Family+'), findsNothing);
    });

    testWidgets('nothing where Family+ is not sold', (tester) async {
      await nudge(tester, _Store(sells: false));
      expect(find.textContaining('with Family+'), findsNothing);
    });

    testWidgets('hidden for that child until the app closes', (tester) async {
      await nudge(tester, _Store());
      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      expect(find.textContaining('with Family+'), findsNothing);
      await nudge(tester, _Store());
      expect(find.textContaining('with Family+'), findsNothing);
      // Another child still sees theirs.
      await nudge(tester, _Store(), studentId: 'child-2');
      expect(
        find.text('See trends and what to focus on for Omar with Family+'),
        findsOne,
      );
    });
  });
}
