part of '../../../parent_features.dart';

class _StudentInsight {
  const _StudentInsight({
    required this.attendance,
    required this.grades,
    required this.submissions,
    required this.engagement,
    required this.availableSignals,
    required this.attendanceTotal,
    required this.present,
    required this.absent,
    required this.tardy,
    required this.gradedCount,
    required this.assigned,
    required this.submitted,
    required this.behaviourTotal,
    required this.positive,
    required this.concerns,
  });
  final double? attendance, grades, submissions, engagement;
  final int availableSignals;
  final num attendanceTotal,
      present,
      absent,
      tardy,
      gradedCount,
      assigned,
      submitted,
      behaviourTotal,
      positive,
      concerns;

  factory _StudentInsight.from(Map<String, num> data) {
    final attendanceTotal = data['attendance_total'] ?? 0,
        assigned = data['assigned'] ?? 0,
        graded = data['graded_count'] ?? 0,
        behaviour = data['behaviour_total'] ?? 0;
    final attendance = attendanceTotal > 0
        ? ((data['present'] ?? 0) / attendanceTotal * 100)
              .clamp(0, 100)
              .toDouble()
        : null;
    final grades = graded > 0
        ? (data['grade_average'] ?? 0).clamp(0, 100).toDouble()
        : null;
    final submissions = assigned > 0
        ? ((data['submitted'] ?? 0) / assigned * 100).clamp(0, 100).toDouble()
        : null;
    final engagement = behaviour > 0
        ? (50 +
                  (((data['positive'] ?? 0) - (data['concerns'] ?? 0)) /
                      behaviour *
                      50))
              .clamp(0, 100)
              .toDouble()
        : null;
    final available = [
      attendance,
      grades,
      submissions,
      engagement,
    ].where((item) => item != null).toList();
    return _StudentInsight(
      attendance: attendance,
      grades: grades,
      submissions: submissions,
      engagement: engagement,
      availableSignals: available.length,
      attendanceTotal: attendanceTotal,
      present: data['present'] ?? 0,
      absent: data['absent'] ?? 0,
      tardy: data['tardy'] ?? 0,
      gradedCount: graded,
      assigned: assigned,
      submitted: data['submitted'] ?? 0,
      behaviourTotal: behaviour,
      positive: data['positive'] ?? 0,
      concerns: data['concerns'] ?? 0,
    );
  }
}

class _InsightHero extends StatelessWidget {
  const _InsightHero({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) {
    final label = insight.availableSignals < 2
        ? 'Not enough evidence yet'
        : '${insight.availableSignals} source categories available';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, Color(0xFF4B3FB5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30241D73),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 88,
            height: 88,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.query_stats_rounded, color: _cyan, size: 42),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evidence snapshot',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'No hidden child score, ranking, diagnosis, or prediction. Open each signal to see its source and sample size.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataQualityCard extends StatelessWidget {
  const _DataQualityCard({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) {
    final ratio = insight.availableSignals / 4;
    final label = insight.availableSignals == 4
        ? 'Complete'
        : insight.availableSignals >= 2
        ? 'Partial'
        : 'Limited';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: Color(0xFF1687A0),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Data confidence',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1687A0),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFFE8EAF3),
            color: const Color(0xFF20A6BF),
          ),
          const SizedBox(height: 8),
          Text(
            '${insight.availableSignals} of 4 source categories contain records. Missing categories are shown as missing and never guessed.',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.weight,
    required this.detail,
    required this.sample,
  });
  final IconData icon;
  final String title, weight, detail, sample;
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    weight,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Text(
              value == null ? 'No data' : '${value!.round()}%',
              style: TextStyle(
                color: value == null ? _muted : color,
                fontSize: value == null ? 13 : 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: value == null ? 0 : value! / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: const Color(0xFFEDEEF5),
          color: color,
        ),
        const SizedBox(height: 9),
        Text(
          detail,
          style: const TextStyle(color: Color(0xFF606780), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(sample, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.insight, required this.firstName});
  final _StudentInsight insight;
  final String firstName;
  @override
  Widget build(BuildContext context) {
    final metrics = <(String, double?)>[
      ('attendance routine', insight.attendance),
      ('assessment understanding', insight.grades),
      ('assignment completion', insight.submissions),
      ('classroom engagement', insight.engagement),
    ];
    final available = metrics.where((item) => item.$2 != null).toList()
      ..sort((a, b) => a.$2!.compareTo(b.$2!));
    final focus = available.isEmpty ? null : available.first;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0DEAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes_rounded, color: Color(0xFFB87500)),
              SizedBox(width: 8),
              Text(
                'Most useful next step',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            focus == null
                ? 'More school records are needed before suggesting a focus.'
                : '${focus.$1[0].toUpperCase()}${focus.$1.substring(1)} is currently $firstName’s lowest available signal (${focus.$2!.round()}%). Start there, while preserving strengths in other areas.',
            style: const TextStyle(
              color: Color(0xFF625B48),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discuss context with the child and teacher before acting on a score.',
            style: TextStyle(color: Color(0xFFA29573), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.insight});
  final _StudentInsight insight;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
    leading: const Icon(Icons.calculate_outlined, color: _navy),
    title: const Text(
      'How this is calculated',
      style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
    ),
    children: const [
      Text(
        'Assessment mastery 35% + attendance consistency 30% + submission reliability 25% + classroom engagement 10%. Assessment scores are normalized by maximum points. Attendance uses recorded present days. Submission reliability uses assigned versus submitted work. Engagement balances positive and concern observations around a neutral midpoint. Missing categories are excluded and weights are rebalanced.',
        style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
      ),
      SizedBox(height: 8),
      Text(
        'The pulse is descriptive, not predictive. It should never be used alone for discipline, placement, safeguarding, or clinical decisions.',
        style: TextStyle(
          color: Color(0xFFB42318),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
