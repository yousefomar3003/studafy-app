import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_components.dart';
import 'package:studafy/features/study/domain/study.dart';
import 'package:studafy/features/study/presentation/study_plan_copy.dart';
import 'package:studafy/features/study/presentation/study_plan_explainer.dart';
import 'package:studafy/features/study/presentation/study_plan_home_card.dart';
import 'package:studafy/features/study/presentation/study_plans_page.dart';
import 'package:studafy/features/study/presentation/upgrade_prompt.dart';

import '../../support/accessibility.dart';
import '../../support/localized_app.dart';

/// Studafy Plus and Max as a landing page (2026-11-04): what each plan does,
/// with a worked example drawn with the real notebook and quiz, before the
/// price - and, as App Store 3.1.2 needs, the store's price, Subscribe, the
/// renewal terms and Terms and Privacy still on the same screen. Also the
/// plan card on Today and the example in the upgrade prompt.

StudyPlan _plan(
  StudyPlanTier tier, {
  double used = .1,
  Set<String>? available,
}) {
  final total = tier == StudyPlanTier.free
      ? studyAllowanceFreeWeekly
      : tier == StudyPlanTier.plus
      ? studyAllowancePlusMonthly
      : studyAllowanceMaxMonthly;
  final spent = (total * used).round();
  return StudyPlan(
    tier: tier,
    allowance: AiAllowance(
      weekly: tier == StudyPlanTier.free,
      total: total,
      used: spent,
      remaining: total - spent,
      resetsAt: DateTime(2026, 11, 9),
    ),
    available:
        available ?? const {'ask', 'whiteboard', 'notes', 'quiz', 'flashcards'},
    aiEnabled: true,
    aiAccess: 'ok',
  );
}

class _Study implements StudyRepository {
  _Study(this.current);

  StudyPlan current;

  @override
  Future<StudyPlan> plan() async => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Store implements StudyPlanSubscriptionRepository {
  _Store({this.store = SubscriptionStore.playStore, this.current});

  SubscriptionStore? store;
  StudyPlanSubscription? current;
  final _listeners = <VoidCallback>[];

  @override
  SubscriptionStore? get purchaseStore => store;

  @override
  Future<StudyPlanSubscription?> subscription() async => current;

  @override
  Future<StudyPlanOffer> offer(StudyPlanTier tier) async => StudyPlanOffer(
    tier: tier,
    price: tier == StudyPlanTier.max ? r'$5.99' : r'$3.99',
    monthly: true,
    storeAvailable: true,
  );

  @override
  Future<void> purchase(StudyPlanTier tier) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  void addEntitlementListener(VoidCallback listener) =>
      _listeners.add(listener);

  @override
  void removeEntitlementListener(VoidCallback listener) =>
      _listeners.remove(listener);
}

StudyPlanSubscription _plus({bool paidByMe = true}) => StudyPlanSubscription(
  tier: StudyPlanTier.plus,
  renewal: RenewalStatus.renewing,
  endsAt: DateTime.utc(2026, 12, 3, 12),
  store: SubscriptionStore.playStore,
  storeProductId: 'studafy_plus_monthly',
  paidByMe: paidByMe,
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  StudyPlan plan, {
  _Store? store,
  Locale? locale,
  StudyPlanTier? focus,
  Size size = const Size(1000, 7000),
}) async {
  _size(tester, size);
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      home: StudyPlansPage(
        study: _Study(plan),
        subscriptions: store ?? _Store(),
        termsUrl: 'https://legal.example.com/terms',
        privacyUrl: 'https://legal.example.com/privacy',
        focus: focus,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder.first).dy;

const _disclosure =
    'Auto-renewing monthly subscriptions. Payment is charged to your Apple '
    'or Google account. If a trial applies, billing starts when it ends. '
    'Cancel in store settings at least 24 hours before renewal to avoid the '
    'next charge. Deleting the app does not cancel a subscription.';

void main() {
  setUp(StudyPlanHomeCard.showAgain);

  group('the plans page', () {
    testWidgets('a free student sees the promise, both worked examples, what '
        'each plan includes and why to trust it - then the prices', (
      tester,
    ) async {
      await _open(tester, _plan(StudyPlanTier.free));

      // The promise.
      expect(find.text('Get more from your notes and lessons'), findsOne);
      expect(
        find.text(
          'Studafy Plus turns a photo of the board into tidy notes. Studafy '
          'Max makes quizzes and flashcards from your notes and lessons.',
        ),
        findsOne,
      );

      // Plus, worked: a photo of the board into a tidy note, labelled.
      expect(find.byType(StudyPlusExample), findsOne);
      expect(find.text('Example'), findsNWidgets(2));
      expect(find.text('Photo of the board'), findsOne);
      expect(find.text('From a photo'), findsOne);
      expect(find.text('Photosynthesis'), findsOne);
      expect(
        find.text('Plants make their own food, glucose, using light'),
        findsOne,
      );
      expect(find.text('They give off oxygen'), findsOne);
      expect(
        find.text('Study notes and notebooks made from your lessons'),
        findsOne,
      );
      // The allowance as the server sets it: 3,000,000 a month against
      // 40,000 a week - compared, never counted.
      expect(
        find.text(
          "A monthly AI allowance, 75 times the size of Free's weekly one",
        ),
        findsOne,
      );

      // Max, worked: a checked quiz question and a flashcard that turns.
      expect(find.byType(StudyMaxExample), findsOne);
      expect(
        find.text('Which gas do plants take in to make their food?'),
        findsOne,
      );
      expect(find.text('Oxygen'), findsOne);
      expect(find.text('Carbon dioxide'), findsOne);
      expect(find.text('Nitrogen'), findsOne);
      expect(find.text('Correct'), findsOne);
      expect(
        find.text('Plants take in carbon dioxide and give off oxygen.'),
        findsOne,
      );
      expect(find.text('What do plants need for photosynthesis?'), findsOne);
      await tester.tap(find.text('What do plants need for photosynthesis?'));
      await tester.pumpAndSettle();
      expect(find.text('Light, water and carbon dioxide.'), findsOne);
      expect(
        find.text('Everything in Plus, with twice its monthly AI allowance'),
        findsOne,
      );

      // Trust.
      expect(
        find.text(
          'Names Studafy knows are replaced before anything is sent to the '
          'AI. Photos are sent as they are, so keep names and faces out of '
          'them.',
        ),
        findsOne,
      );
      expect(
        find.text(
          'AI can be wrong. Check what it makes, and never hand it in as '
          'your own work.',
        ),
        findsOne,
      );
      expect(
        find.text('No ads. Your data is never sold or used to train AI.'),
        findsOne,
      );

      // Compliance: the store's prices, Subscribe, the renewal terms, who
      // takes the payment, Terms and Privacy - all on this screen.
      expect(find.text(r'$3.99 / month'), findsOne);
      expect(find.text(r'$5.99 / month'), findsOne);
      expect(find.text('Subscribe to Studafy Plus'), findsOne);
      expect(find.text('Subscribe to Studafy Max'), findsOne);
      expect(find.text(_disclosure), findsOne);
      expect(
        find.text(
          'Payment is taken by Google Play from the Google account on this '
          'phone.',
        ),
        findsOne,
      );
      expect(find.text('Terms of use'), findsOne);
      expect(find.text('Privacy policy'), findsOne);
      // Restoring stays on the profile, under Subscription.
      expect(find.text('Restore purchases'), findsNothing);

      // The value comes before the price.
      final price = _top(tester, find.text(r'$3.99 / month'));
      expect(
        _top(tester, find.text('Get more from your notes and lessons')),
        lessThan(_top(tester, find.byType(StudyPlusExample))),
      );
      expect(_top(tester, find.byType(StudyPlusExample)), lessThan(price));
      expect(_top(tester, find.byType(StudyMaxExample)), lessThan(price));
      expect(_top(tester, find.text('Good to know')), lessThan(price));

      // No counts, no "unlimited", and no trial unless the store offers one
      // (only the renewal terms mention one, as they always have).
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('40,000'), findsNothing);
      expect(find.textContaining('nlimited'), findsNothing);
      expect(find.textContaining('trial'), findsOne);
      expect(find.textContaining('free month'), findsNothing);
    });

    testWidgets('a Plus student sees only what Max adds, with the upgrade, '
        'the store subscription and the terms', (tester) async {
      await _open(
        tester,
        _plan(StudyPlanTier.plus),
        store: _Store(current: _plus()),
      );
      expect(find.byType(StudyPlusExample), findsNothing);
      expect(find.byType(StudyMaxExample), findsOne);
      expect(find.text('Upgrade to Studafy Max'), findsOne);
      expect(find.text('Manage subscription'), findsOne);
      expect(find.text('Cancel subscription'), findsOne);
      expect(find.text(_disclosure), findsOne);
      expect(find.text('Terms of use'), findsOne);
      expect(find.text('Privacy policy'), findsOne);
      expect(
        _top(tester, find.byType(StudyMaxExample)),
        lessThan(_top(tester, find.text(r'$5.99 / month'))),
      );
    });

    testWidgets('a plan a parent pays for still says so, and only they can '
        'change it', (tester) async {
      await _open(
        tester,
        _plan(StudyPlanTier.plus),
        store: _Store(current: _plus(paidByMe: false)),
      );
      expect(find.textContaining('A parent pays for this plan'), findsOne);
      expect(find.text('Manage subscription'), findsNothing);
      expect(find.text('Cancel subscription'), findsNothing);
      expect(find.text(_disclosure), findsOne);
    });

    testWidgets('a Max student is sold nothing: no promise, no examples', (
      tester,
    ) async {
      await _open(tester, _plan(StudyPlanTier.max));
      expect(find.text('Get more from your notes and lessons'), findsNothing);
      expect(find.byType(StudyPlusExample), findsNothing);
      expect(find.byType(StudyMaxExample), findsNothing);
      expect(find.text('Good to know'), findsNothing);
      expect(find.text('Your plan'), findsOne);
      expect(find.text(_disclosure), findsOne);
    });

    testWidgets('without a store the plans are described, not sold', (
      tester,
    ) async {
      await _open(
        tester,
        _plan(StudyPlanTier.free),
        store: _Store(store: null),
      );
      expect(find.byType(StudyPlusExample), findsOne);
      expect(find.textContaining('bought in the Studafy app'), findsOne);
      expect(find.text('Subscribe to Studafy Plus'), findsNothing);
    });

    testWidgets('opened for Max, it starts at the Max example', (tester) async {
      await _open(
        tester,
        _plan(StudyPlanTier.free),
        focus: StudyPlanTier.max,
        size: const Size(400, 800),
      );
      final heading = find.text('Studafy Max: quizzes and flashcards');
      expect(heading, findsOne);
      final top = _top(tester, heading);
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(200));
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('the page is accessible on a phone: ${locale.languageCode}', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _open(
          tester,
          _plan(StudyPlanTier.free),
          locale: locale,
          size: const Size(400, 7000),
        );
        expect(tester.takeException(), isNull);
        if (locale.languageCode == 'ar') {
          expect(find.text('استفد أكثر من ملاحظاتك ودروسك'), findsOne);
          expect(find.text('مثال'), findsNWidgets(2));
          expect(find.text('صورة السبورة'), findsOne);
          expect(
            Directionality.of(tester.element(find.byType(StudyMaxExample))),
            TextDirection.rtl,
          );
          expect(find.textContaining(r'$3.99'), findsOne);
        }
        // Contrast in English only: on CI's Linux test font some Arabic
        // words render too thin to sample.
        await expectAccessible(tester, contrast: locale.languageCode == 'en');
        semantics.dispose();
      });
    }

    test('the allowances are the ones the server sets', () {
      // The latest definition of private.ai_plan_limits().
      final sql = File(
        'supabase/migrations/'
        '202610070001_grounded_material_and_token_allowances.sql',
      ).readAsStringSync();
      final definition = sql.substring(
        sql.indexOf('create or replace function private.ai_plan_limits'),
      );
      int allowance(String plan) {
        final at = definition.indexOf("when '$plan'");
        final match = RegExp(r"'tokenAllowance', (\d+)")
            .firstMatch(definition.substring(at));
        return int.parse(match!.group(1)!);
      }

      final free = RegExp(
        r"else jsonb_build_object\(\s*'tokenAllowance', (\d+), 'period', 'week'",
      ).firstMatch(definition);
      expect(int.parse(free!.group(1)!), studyAllowanceFreeWeekly);
      expect(allowance('plus'), studyAllowancePlusMonthly);
      expect(allowance('max'), studyAllowanceMaxMonthly);
      // What the page says: Plus's month is 75 times Free's week, and
      // Max's month is twice Plus's.
      expect(studyAllowancePlusMonthly ~/ studyAllowanceFreeWeekly, 75);
      expect(studyAllowancePlusMonthly % studyAllowanceFreeWeekly, 0);
      expect(studyAllowanceMaxMonthly, 2 * studyAllowancePlusMonthly);
      // No later migration redefines the limits.
      final later = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.compareTo(
                      'supabase/migrations/202610070001_grounded_material_and_token_allowances.sql',
                    ) >
                    0 &&
                file.readAsStringSync().contains(
                  'function private.ai_plan_limits',
                ),
          );
      expect(later, isEmpty);
    });
  });

  group('the plan card on Today', () {
    Future<_Study> card(
      WidgetTester tester,
      StudyPlan plan, {
      _Store? store,
      bool noStore = false,
      List<StudyPlanTier>? opened,
      Locale? locale,
    }) async {
      _size(tester, const Size(400, 900));
      final study = _Study(plan);
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: Scaffold(
            body: ListView(
              children: [
                StudyPlanHomeCard(
                  study: study,
                  subscriptions: noStore ? null : store ?? _Store(),
                  onOpen: (focus) async => opened?.add(focus),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return study;
    }

    testWidgets('a free student is offered Plus or Max, opening at Plus', (
      tester,
    ) async {
      final opened = <StudyPlanTier>[];
      await card(tester, _plan(StudyPlanTier.free), opened: opened);
      expect(find.text('Do more with Studafy Plus or Max'), findsOne);
      expect(
        find.text(
          'Plus turns a photo of the board into tidy notes. Max adds '
          'quizzes and flashcards.',
        ),
        findsOne,
      );
      await tester.tap(find.text('See plans'));
      await tester.pumpAndSettle();
      expect(opened, [StudyPlanTier.plus]);
    });

    testWidgets('a Plus student is offered Max', (tester) async {
      final opened = <StudyPlanTier>[];
      await card(tester, _plan(StudyPlanTier.plus), opened: opened);
      expect(find.text('Test yourself with Studafy Max'), findsOne);
      await tester.tap(find.text('See plans'));
      await tester.pumpAndSettle();
      expect(opened, [StudyPlanTier.max]);
    });

    testWidgets('with most of the allowance used it says so', (tester) async {
      await card(tester, _plan(StudyPlanTier.free, used: .8));
      expect(
        find.text(
          "You've used most of this week's AI. Studafy Plus gives you a "
          'monthly allowance and notes from photos.',
        ),
        findsOne,
      );
    });

    testWidgets('hidden on Max', (tester) async {
      await card(tester, _plan(StudyPlanTier.max));
      expect(find.byType(PlanOfferCard), findsNothing);
      expect(find.text('See plans'), findsNothing);
    });

    testWidgets('hidden where nothing is sold: no billing, or no store', (
      tester,
    ) async {
      await card(tester, _plan(StudyPlanTier.free), noStore: true);
      expect(find.text('See plans'), findsNothing);
      await card(tester, _plan(StudyPlanTier.free), store: _Store(store: null));
      expect(find.text('See plans'), findsNothing);
    });

    testWidgets('hidden when a parent pays for the plan', (tester) async {
      await card(
        tester,
        _plan(StudyPlanTier.plus),
        store: _Store(current: _plus(paidByMe: false)),
      );
      expect(find.text('See plans'), findsNothing);
    });

    testWidgets('hidden with the AI tools off, or the next plan\'s tool off', (
      tester,
    ) async {
      await card(tester, _plan(StudyPlanTier.free, available: const {}));
      expect(find.text('See plans'), findsNothing);
      await card(
        tester,
        _plan(StudyPlanTier.plus, available: const {'ask', 'whiteboard'}),
      );
      expect(find.text('See plans'), findsNothing);
    });

    testWidgets('Hide puts it away until the app closes', (tester) async {
      await card(tester, _plan(StudyPlanTier.free));
      await tester.tap(find.byTooltip('Hide'));
      await tester.pumpAndSettle();
      expect(find.text('See plans'), findsNothing);
      await card(tester, _plan(StudyPlanTier.plus));
      expect(find.text('See plans'), findsNothing);
    });

    testWidgets('reads in Arabic, plan names left to right', (tester) async {
      await card(tester, _plan(StudyPlanTier.plus), locale: const Locale('ar'));
      expect(find.text('اختبر نفسك مع \u2066Studafy Max\u2069'), findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('the upgrade prompt', () {
    Future<void> prompt(
      WidgetTester tester,
      StudyPlanTier tier,
      UpgradeReason reason, {
      StudyPlanTier? needs,
    }) async {
      await tester.pumpWidget(
        localizedApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showUpgradePrompt(
                    context,
                    reason: reason,
                    plan: _plan(tier, used: 1),
                    needs: needs,
                    onUpgrade: () {},
                  ),
                  child: const Text('limit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('limit'));
      await tester.pumpAndSettle();
    }

    testWidgets('a locked Plus feature shows the Plus example, Upgrade in '
        'view', (tester) async {
      await prompt(
        tester,
        StudyPlanTier.free,
        UpgradeReason.feature,
        needs: StudyPlanTier.plus,
      );
      expect(find.byType(StudyPlusExample), findsOne);
      expect(find.byType(StudyMaxExample), findsNothing);
      // The buttons stay in view below the example.
      final upgrade = find.text('Upgrade');
      expect(tester.getBottomLeft(upgrade).dy, lessThanOrEqualTo(600));
    });

    testWidgets('Plus out of AI is shown the Max example', (tester) async {
      await prompt(tester, StudyPlanTier.plus, UpgradeReason.tokensUsed);
      expect(find.byType(StudyMaxExample), findsOne);
      expect(find.byType(StudyPlusExample), findsNothing);
    });
  });
}
