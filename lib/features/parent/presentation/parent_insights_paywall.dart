part of '../../../parent_features.dart';

class _InsightsPaywall extends StatefulWidget {
  const _InsightsPaywall({required this.onPurchase, required this.onRestore});
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  State<_InsightsPaywall> createState() => _InsightsPaywallState();
}

class _InsightsPaywallState extends State<_InsightsPaywall> {
  PaywallOffer? _offer;
  bool _loadingOffer = true;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    PaywallOffer? offer;
    try {
      offer = await ParentRepositoryScope.of(context).subscription
          .insightsOffer();
    } catch (_) {
      offer = null;
    }
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _loadingOffer = false;
    });
  }

  /// Checkout opens only on store-verified terms behind reachable policy
  /// documents. Both stores treat a purchase button over unconfirmed pricing,
  /// or over a dead terms link, as a review failure.
  bool get _canCheckout =>
      _offer?.canPurchase == true &&
      _validPolicyUrl(_termsUrl) &&
      _validPolicyUrl(_privacyUrl);

  String get _priceLine {
    // While the catalogue and store product query are in flight nothing is
    // known yet: say so rather than claiming subscriptions are unavailable.
    if (_loadingOffer) return 'Checking store pricing';
    final offer = _offer;
    if (offer == null || !offer.canPurchase) {
      return 'Subscriptions are currently unavailable';
    }
    final period = offer.periodLabel.isEmpty ? 'month' : offer.periodLabel;
    return '${offer.price} / $period';
  }

  String get _trialLine {
    final offer = _offer;
    if (offer == null ||
        !offer.canPurchase ||
        !offer.hasTrial ||
        offer.trialLengthLabel.isEmpty) {
      return '';
    }
    final period = offer.periodLabel.isEmpty ? 'month' : offer.periodLabel;
    // The price after the free trial is the store's recurring price.
    return 'If eligible, free for ${offer.trialLengthLabel}, then ${offer.price} / $period';
  }

  Widget _policyLink(String label, String url) {
    // Same test that gates checkout: a misconfigured build define must render
    // as plain text, never as a tappable link to a non-HTTPS destination.
    if (!_validPolicyUrl(url)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      );
    }
    return TextButton(
      onPressed: () => _launchPolicy(url),
      style: TextButton.styleFrom(
        foregroundColor: _navy,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _disclosureRow(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      style: const TextStyle(color: _muted, fontSize: 11.5, height: 1.3),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_navy, Color(0xFF4B3FB5)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PremiumTag(),
            SizedBox(height: 14),
            Text(
              'Understand the pattern, then take one useful action.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Insights+ explains mastery, attendance patterns, workload conflicts, momentum, and what evidence produced each recommendation.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.fact_check_outlined, color: _navy),
              title: Text('Evidence and sample size on every insight'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.calendar_month_outlined, color: _navy),
              title: Text('Weekly family action plan'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.calculate_outlined, color: _navy),
              title: Text('“What mark is needed?” scenarios'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent Insights+',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'Auto-renewing subscription',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const Divider(height: 20),
            _disclosureRow(
              '$_priceLine · renews automatically until cancelled',
            ),
            if (_trialLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EAFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _disclosureRow(_trialLine),
                    _disclosureRow(
                      'Your app store payment method is charged when the free trial ends.',
                    ),
                    _disclosureRow(
                      'Cancel at least 24 hours before the trial ends to avoid charge.',
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            _disclosureRow(
              "Cancel any time in your device's subscription settings.",
            ),
            _disclosureRow(
              'Payment is handled by your app store (Apple or Google). Studafy never receives or stores your card details.',
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _policyLink('Terms of Use', _termsUrl),
                const SizedBox(width: 6),
                _policyLink('Privacy Policy', _privacyUrl),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _canCheckout ? widget.onPurchase : null,
        child: Text(
          _canCheckout
              ? 'Start Insights+'
              : _loadingOffer
              ? 'Checking store pricing'
              : 'Subscriptions currently unavailable',
        ),
      ),
      if (_canCheckout) ...[
        const SizedBox(height: 4),
        const Text(
          _priceLineInButton,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      ],
      TextButton(
        onPressed: widget.onRestore,
        child: const Text('Restore purchase'),
      ),
      const Text(
        'Grades, attendance, messages, alerts, and official school records remain free.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );
}

bool _validPolicyUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

const _priceLineInButton = 'Prices and periods are confirmed in your store';

class _ParentPremiumBrief extends StatelessWidget {
  const _ParentPremiumBrief({required this.insight, required this.firstName});
  final _StudentInsight insight;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final missing = (insight.assigned - insight.submitted)
        .clamp(0, 999)
        .toInt();
    final items =
        <({IconData icon, Color color, String title, String detail})>[];
    if (missing > 0) {
      items.add((
        icon: Icons.assignment_late_outlined,
        color: const Color(0xFFE07A12),
        title: '$missing unfinished ${missing == 1 ? 'item' : 'items'}',
        detail:
            'Ask $firstName which task is blocked, then agree on one completion time.',
      ));
    }
    if (insight.attendance != null && insight.attendance! < 95) {
      items.add((
        icon: Icons.event_busy_outlined,
        color: const Color(0xFFD94C4C),
        title: 'Attendance needs attention',
        detail:
            '${insight.absent.toInt()} absence(s) and ${insight.tardy.toInt()} late arrival(s) are recorded. Review dates with the school.',
      ));
    }
    if (insight.grades != null && insight.grades! < 75) {
      items.add((
        icon: Icons.school_outlined,
        color: _navy,
        title: 'Assessment support recommended',
        detail:
            'Current normalized assessment average is ${insight.grades!.round()}%. Open Academics to identify the lowest class before contacting its teacher.',
      ));
    }
    if (items.isEmpty) {
      items.add((
        icon: Icons.verified_rounded,
        color: const Color(0xFF15966A),
        title: 'No urgent intervention detected',
        detail:
            'Keep the routine steady and recognize $firstName’s consistency this week.',
      ));
    }
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E6F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parent action brief',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _PremiumTag(),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'The highest-value actions generated from current school records.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < items.take(3).length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: items[i].color.withValues(alpha: .11),
                  child: Icon(items[i].icon, color: items[i].color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].detail,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != items.take(3).length - 1) const Divider(height: 22),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => Padding(
                      padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This week’s family plan',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final item in items.take(3))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: item.color.withValues(
                                  alpha: .1,
                                ),
                                child: Icon(item.icon, color: item.color),
                              ),
                              title: Text(item.title),
                              subtitle: Text(item.detail),
                            ),
                        ],
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 17),
                  label: const Text('Weekly plan'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ParentMessagesPage(),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Ask teacher'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EAFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'PLUS',
      style: TextStyle(
        color: Color(0xFF6D35D5),
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
