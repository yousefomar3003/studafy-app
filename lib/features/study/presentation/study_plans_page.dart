import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/studafy_design.dart';
import '../domain/study.dart';

/// The three plans, what each unlocks, and where the student stands.
///
/// Prices come from the store listing, in the student's own currency. When
/// the store cannot be reached the US list price is shown, labelled as such:
/// the store is always what confirms the price (App Review 3.1.2).
class StudyPlansPage extends StatefulWidget {
  const StudyPlansPage({
    super.key,
    required this.study,
    this.subscriptions,
    this.openLink,
  });

  final StudyRepository study;

  /// Null in builds with no store; plans are then described, not sold.
  final StudyPlanSubscriptionRepository? subscriptions;

  /// Opens a web page outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<StudyPlansPage> createState() => _StudyPlansPageState();
}

class _PlanCopy {
  const _PlanCopy(this.name, this.usPrice, this.features);
  final String name;
  final String usPrice;
  final List<(String, String)> features;
}

class _StudyPlansPageState extends State<StudyPlansPage> {
  StudyPlan? _plan;
  final Map<StudyPlanTier, StudyPlanOffer> _offers = {};
  bool _loading = true;
  bool _busy = false;
  String? _message;

  static const _terms = String.fromEnvironment('STUDAFY_TERMS_URL');
  static const _privacy = String.fromEnvironment('STUDAFY_PRIVACY_URL');

  static const _copy = {
    StudyPlanTier.free: _PlanCopy('Studafy Free', '', [
      ('Lessons from every class, by date', 'دروس كل صف مرتبة حسب التاريخ'),
      ('Your own notebook for each class', 'دفتر خاص بك لكل صف'),
      (
        '10 questions a day to the study helper',
        '10 أسئلة يوميًا للمساعد الدراسي',
      ),
    ]),
    StudyPlanTier.plus: _PlanCopy('Studafy Plus', r'US$3.99', [
      ('Everything in Free', 'كل ما في الخطة المجانية'),
      (
        'Snap the whiteboard - get real notebook notes',
        'صوّر السبورة واحصل على ملاحظات حقيقية في دفترك',
      ),
      ('40 questions a day', '40 سؤالًا يوميًا'),
    ]),
    StudyPlanTier.max: _PlanCopy('Studafy Max', r'US$5.99', [
      ('Everything in Plus', 'كل ما في Plus'),
      ('Quizzes made from your lessons', 'اختبارات من دروسك'),
      ('Flashcards made from your lessons', 'بطاقات مراجعة من دروسك'),
      ('60 questions a day', '60 سؤالًا يوميًا'),
    ]),
  };

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';
  String _t(String en, String ar) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    widget.subscriptions?.addEntitlementListener(_load);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    widget.subscriptions?.removeEntitlementListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    StudyPlan? plan;
    try {
      plan = await widget.study.plan();
    } on Object {
      plan = null;
    }
    final offers = <StudyPlanTier, StudyPlanOffer>{};
    final subscriptions = widget.subscriptions;
    if (subscriptions != null) {
      for (final tier in [StudyPlanTier.plus, StudyPlanTier.max]) {
        try {
          offers[tier] = await subscriptions.offer(tier);
        } on Object {
          // A store outage never hides the plans; the card says the store
          // could not be reached.
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _offers
        ..clear()
        ..addAll(offers);
      _loading = false;
    });
  }

  Future<void> _perform(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = done);
      await _load();
    } on Object {
      if (mounted) {
        setState(
          () => _message = _t(
            'That did not work. Please try again.',
            'لم تنجح العملية. حاول مرة أخرى.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  Future<void> _open(String value) async {
    if (!_validUrl(value)) return;
    final open =
        widget.openLink ??
        (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
    await open(Uri.parse(value));
  }

  String get _manageUrl => defaultTargetPlatform == TargetPlatform.iOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';

  Widget _usage(StudyPlan plan) {
    final theme = Theme.of(context);
    if (plan.tier == StudyPlanTier.free) {
      return Text(
        _t(
          'Questions today: ${plan.askToday} of ${plan.askPerDay}',
          'أسئلة اليوم: ${plan.askToday} من ${plan.askPerDay}',
        ),
      );
    }
    final renews = MaterialLocalizations.of(context)
        .formatMediumDate(plan.resetsAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(
            'AI used this month: ${(plan.allowanceUsed * 100).round()}%',
            'الاستخدام هذا الشهر: ${(plan.allowanceUsed * 100).round()}٪',
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: plan.allowanceUsed,
            minHeight: 8,
            color: plan.allowanceUsed >= 0.9 ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t('Renews $renews', 'يتجدد في $renews'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _planCard(StudyPlanTier tier) {
    final theme = Theme.of(context);
    final copy = _copy[tier]!;
    final current = (_plan?.tier ?? StudyPlanTier.free) == tier;
    final offer = _offers[tier];
    final subscriptions = widget.subscriptions;

    Widget? action;
    if (tier != StudyPlanTier.free && !current && subscriptions != null) {
      final links = _validUrl(_terms) && _validUrl(_privacy);
      if (offer == null) {
        action = Text(
          _t(
            'The store could not be reached. Try again later.',
            'تعذّر الوصول إلى المتجر. حاول لاحقًا.',
          ),
        );
      } else if (!offer.selfPurchaseEnabled) {
        action = Text(
          _t(
            'Buying is not enabled for your account yet.',
            'الشراء غير مفعّل لحسابك بعد.',
          ),
        );
      } else if (offer.approval != 'approved') {
        action = OutlinedButton.icon(
          onPressed: _busy || offer.approval == 'requested'
              ? null
              : () => _perform(
                  () => subscriptions.requestApproval(tier),
                  _t(
                    'We asked your parent to approve.',
                    'طلبنا موافقة ولي أمرك.',
                  ),
                ),
          icon: const Icon(Icons.family_restroom_rounded),
          label: Text(
            offer.approval == 'requested'
                ? _t('Waiting for a parent', 'بانتظار موافقة ولي الأمر')
                : _t('Ask a parent to approve', 'اطلب موافقة ولي الأمر'),
          ),
        );
      } else {
        action = FilledButton.icon(
          onPressed: _busy || !offer.canPurchase || !links
              ? null
              : () => _perform(
                  () => subscriptions.purchase(tier),
                  _t('Opening the store…', 'جارٍ فتح المتجر…'),
                ),
          icon: const Icon(Icons.lock_open_rounded),
          label: Text(
            offer.oneMonthTrial
                ? _t('Start a free month', 'ابدأ شهرًا مجانيًا')
                : _t('Subscribe to ${copy.name}', 'اشترك في ${copy.name}'),
          ),
        );
      }
    }

    final price = tier == StudyPlanTier.free
        ? _t('Free', 'مجانًا')
        : (offer != null && offer.storeAvailable && offer.price.isNotEmpty)
        ? _t('${offer.price} / month', '${offer.price} / شهريًا')
        : _t(
            '${copy.usPrice} / month in the US - the store shows your price',
            '${copy.usPrice} شهريًا في الولايات المتحدة - يعرض المتجر سعرك',
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: current
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    copy.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (current) Chip(label: Text(_t('Your plan', 'خطتك الحالية'))),
              ],
            ),
            Text(price, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final (en, ar) in copy.features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: studafyCyan,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_t(en, ar))),
                  ],
                ),
              ),
            if (current && tier != StudyPlanTier.free) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _open(_manageUrl),
                child: Text(_t('Manage or cancel', 'إدارة أو إلغاء')),
              ),
            ] else if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final subscriptions = widget.subscriptions;
    return Scaffold(
      appBar: AppBar(title: Text(_t('Plans', 'الخطط'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (plan != null)
                    Card(
                      margin: const EdgeInsets.only(bottom: 18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _usage(plan),
                      ),
                    ),
                  for (final tier in StudyPlanTier.values) _planCard(tier),
                  if (_busy) const LinearProgressIndicator(),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_message!),
                    ),
                  if (subscriptions != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _perform(
                              subscriptions.restorePurchases,
                              _t(
                                'Restoring purchases…',
                                'جارٍ استعادة المشتريات…',
                              ),
                            ),
                      child: Text(_t('Restore purchases', 'استعادة المشتريات')),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'Auto-renewing monthly subscriptions. Payment is charged to your Apple or Google account. If a trial applies, billing starts when it ends. Cancel in store settings at least 24 hours before renewal to avoid the next charge. Deleting the app does not cancel a subscription.',
                      'اشتراكات شهرية تتجدد تلقائيًا. يُحصَّل المبلغ من حسابك في Apple أو Google. إذا كانت هناك فترة تجربة، يبدأ الدفع عند انتهائها. ألغِ من إعدادات المتجر قبل التجديد بـ 24 ساعة على الأقل لتجنب الدفعة التالية. حذف التطبيق لا يلغي الاشتراك.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: _validUrl(_terms)
                            ? () => _open(_terms)
                            : null,
                        child: Text(_t('Terms of use', 'شروط الاستخدام')),
                      ),
                      TextButton(
                        onPressed: _validUrl(_privacy)
                            ? () => _open(_privacy)
                            : null,
                        child: Text(_t('Privacy policy', 'سياسة الخصوصية')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
