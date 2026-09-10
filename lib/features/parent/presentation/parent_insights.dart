part of '../../../parent_features.dart';

class ParentInsightsPage extends StatefulWidget {
  const ParentInsightsPage({super.key});
  @override
  State<ParentInsightsPage> createState() => _ParentInsightsPageState();
}

class _ParentInsightsPageState extends State<ParentInsightsPage> {
  List<Map<String, Object?>> children = [];
  int selectedChild = 0;
  String period = 'Current term';
  SubscriptionEntitlement? entitlement;
  bool entitlementLoading = true;

  Map<String, Object?>? get child =>
      children.isEmpty ? null : children[selectedChild];

  DateTime? get periodStart {
    final now = DateTime.now();
    return switch (period) {
      'Last 30 days' => now.subtract(const Duration(days: 30)),
      'School year' => DateTime(now.month >= 8 ? now.year : now.year - 1, 8, 1),
      _ => DateTime(
        now.month >= 1 && now.month <= 6 ? now.year : now.year - 1,
        1,
        1,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    ActiveContextController.instance.addListener(_contextChanged);
    _load();
  }

  void _contextChanged() {
    if (!mounted || children.isEmpty) return;
    final next = _activeChildIndex(children, selectedChild);
    if (next != selectedChild) setState(() => selectedChild = next);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final dependencies = ParentRepositoryScope.of(context);
    final rows = await dependencies.repository.linkedChildren();
    SubscriptionEntitlement? access;
    if (dependencies.isRemote) {
      try {
        access = await dependencies.subscription.entitlement();
      } catch (_) {
        access = const SubscriptionEntitlement(
          active: false,
          source: 'unavailable',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      children = rows;
      selectedChild = _activeChildIndex(rows, selectedChild);
      entitlement = access;
      entitlementLoading = false;
    });
  }

  Future<void> _purchase() async {
    try {
      await ParentRepositoryScope.of(context).subscription
          .purchaseInsightsMonthly();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete the purchase in the store. Access appears after server verification.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  Future<void> _restore() async {
    try {
      await ParentRepositoryScope.of(context).subscription.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Bad state: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        _AcademicsHeader(
          title: 'Insights',
          children: children,
          selected: selectedChild,
          onSelected: (value) {
            setState(() => selectedChild = value);
            _rememberChild(children[value]);
          },
        ),
        if (child == null)
          const Expanded(
            child: Center(
              child: Text('Add a child from Home to view insights.'),
            ),
          )
        else if (entitlementLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (ParentRepositoryScope.of(context).isRemote &&
            !(entitlement?.active ?? false))
          Expanded(
            child: _InsightsPaywall(onPurchase: _purchase, onRestore: _restore),
          )
        else
          Expanded(
            child: FutureBuilder<Map<String, num>>(
              future: ParentRepositoryScope.read(context)
                  .insightMetricsForStudent(
                    child!['student_id'] as int,
                    since: periodStart,
                  ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final insight = _StudentInsight.from(snapshot.data!);
                final firstName = '${child!['student_name']}'.split(' ').first;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$firstName’s evidence-backed insights',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'A transparent summary of connected school data',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: period,
                            borderRadius: BorderRadius.circular(14),
                            items:
                                ['Last 30 days', 'Current term', 'School year']
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => period = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InsightHero(insight: insight),
                    const SizedBox(height: 14),
                    _ParentPremiumBrief(insight: insight, firstName: firstName),
                    const SizedBox(height: 14),
                    _DataQualityCard(insight: insight),
                    const SizedBox(height: 18),
                    const Text(
                      'DETAILED SIGNALS',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Attendance consistency',
                      value: insight.attendance,
                      color: const Color(0xFF15885D),
                      weight: 'Source: attendance records',
                      detail:
                          '${insight.present.toInt()} present · ${insight.absent.toInt()} absent · ${insight.tardy.toInt()} late',
                      sample:
                          '${insight.attendanceTotal.toInt()} recorded school days',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Assessment mastery',
                      value: insight.grades,
                      color: _navy,
                      weight: 'Source: published results',
                      detail: 'Average normalized against each assessment’s maximum score',
                      sample:
                          '${insight.gradedCount.toInt()} graded assessments',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Submission reliability',
                      value: insight.submissions,
                      color: const Color(0xFF1687A0),
                      weight: 'Source: due submissions',
                      detail:
                          '${insight.submitted.toInt()} submitted of ${insight.assigned.toInt()} assignments',
                      sample: '${insight.assigned.toInt()} assigned items',
                    ),
                    const SizedBox(height: 10),
                    _MetricCard(
                      icon: Icons.psychology_alt_outlined,
                      title: 'Classroom engagement',
                      value: insight.engagement,
                      color: const Color(0xFF7737EE),
                      weight: 'Source: teacher observations',
                      detail:
                          '${insight.positive.toInt()} positive observations · ${insight.concerns.toInt()} concerns',
                      sample:
                          '${insight.behaviourTotal.toInt()} teacher observations',
                    ),
                    const SizedBox(height: 18),
                    _PriorityCard(insight: insight, firstName: firstName),
                    const SizedBox(height: 14),
                    _MethodCard(insight: insight),
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _InsightsPaywall extends StatelessWidget {
  const _InsightsPaywall({required this.onPurchase, required this.onRestore});
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

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
      FilledButton(
        onPressed: onPurchase,
        child: const Text('Start Insights+ · monthly'),
      ),
      TextButton(onPressed: onRestore, child: const Text('Restore purchase')),
      const Text(
        'Grades, attendance, messages, alerts, and official school records remain free.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 11),
      ),
    ],
  );
}

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
