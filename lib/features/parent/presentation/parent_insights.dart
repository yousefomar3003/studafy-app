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
  ParentSubscriptionRepository? _subscription;

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
    final scope = ParentRepositoryScope.of(context);
    if (scope.isRemote) {
      _subscription = scope.subscription;
      scope.subscription.addEntitlementListener(_entitlementChanged);
    }
    _load();
  }

  void _entitlementChanged() {
    if (mounted) _load();
  }

  void _contextChanged() {
    if (!mounted || children.isEmpty) return;
    final next = _activeChildIndex(children, selectedChild);
    if (next != selectedChild) setState(() => selectedChild = next);
  }

  @override
  void dispose() {
    ActiveContextController.instance.removeListener(_contextChanged);
    _subscription?.removeEntitlementListener(_entitlementChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final dependencies = ParentRepositoryScope.of(context);
    final rows = await dependencies.repository.linkedChildren();
    SubscriptionEntitlement? access;
    if (dependencies.isRemote) {
      final index = _activeChildIndex(rows, selectedChild);
      final serverId = rows.isEmpty ? null : rows[index]['serverId'];
      try {
        access = serverId is String
            ? await dependencies.subscription.entitlement(
                beneficiaryStudentId: serverId,
              )
            : const SubscriptionEntitlement(active: false, source: 'none');
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
      // The entitlement attaches to the selected child, so the store sheet
      // never opens without that child's server id: a purchase the server
      // cannot attribute would go unacknowledged and be auto-refunded.
      final beneficiary = child?['serverId'];
      if (beneficiary is! String || beneficiary.isEmpty) {
        throw StateError('Choose a linked child before subscribing');
      }
      await ParentRepositoryScope.of(context).subscription
          .purchaseInsightsMonthly(beneficiaryStudentId: beneficiary);
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
            // Access is per child: re-read it for the newly selected one.
            _load();
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
