import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/family_insights_interactor.dart';
import '../domain/family_insights.dart';

/// Family+ : what a parent is paying for.
///
/// Ordered by what can still be acted on. Work due this week comes before a
/// term's trend, because one is changeable tonight and the other is context.
///
/// Every claim shows the records behind it. That is not decoration: a parent
/// who cannot check a statement about their child has to take it on faith,
/// and a paid product making unfalsifiable claims about somebody's child is
/// exactly what this must not be.
class FamilyInsightsPage extends StatefulWidget {
  const FamilyInsightsPage({
    super.key,
    required this.insights,
    required this.studentId,
    this.actions = const [],
  });

  final FamilyInsightsInteractor insights;
  final String studentId;
  final List<Widget> actions;

  @override
  State<FamilyInsightsPage> createState() => _FamilyInsightsPageState();
}

class _FamilyInsightsPageState extends State<FamilyInsightsPage> {
  late Future<FamilyInsights?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(FamilyInsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentId != widget.studentId) {
      setState(() => _future = _load());
    }
  }

  Future<FamilyInsights?> _load() async {
    final result = await widget.insights.forStudent(widget.studentId);
    return result.fold(onSuccess: (value) => value, onFailure: (_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(l10n.insightsTitle),
        actions: widget.actions,
      ),
      body: FutureBuilder<FamilyInsights?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: StudafyStatusCard(
                  icon: Icons.insights_outlined,
                  title: l10n.insightsUnavailableTitle,
                  message: l10n.insightsUnavailableBody,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Headline(data: data),
                const SizedBox(height: 20),
                if (data.signals.isEmpty)
                  StudafyStatusCard(
                    icon: Icons.hourglass_empty_rounded,
                    title: l10n.insightsNothingYetTitle,
                    message: l10n.insightsNothingYetBody,
                  ),
                for (final signal in data.signals) ...[
                  _SignalCard(signal: signal),
                  const SizedBox(height: 12),
                ],
                if (data.subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionTitle(l10n.insightsBySubject),
                  const SizedBox(height: 8),
                  _SubjectTable(subjects: data.subjects),
                ],
                if (data.upcoming.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(l10n.insightsComingUp),
                  const SizedBox(height: 8),
                  for (final work in data.upcoming)
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(work.title),
                      subtitle: Text(
                        l10n.insightsDueOn(_shortDate(work.dueAt)),
                      ),
                    ),
                ],
                if (data.wellbeing.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(l10n.insightsFromSchool),
                  const SizedBox(height: 8),
                  for (final note in data.wellbeing)
                    ListTile(
                      leading: const Icon(Icons.favorite_outline),
                      title: Text(note.title),
                      subtitle: Text(_shortDate(note.createdAt)),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

String _shortDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}'
    '-${value.day.toString().padLeft(2, '0')}';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: studafyMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

class _Headline extends StatelessWidget {
  const _Headline({required this.data});

  final FamilyInsights data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.studentName,
            style: const TextStyle(
              color: studafyInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.insightsAverage,
                  // Null rather than a zero: no marks yet is not zero marks.
                  value: data.averagePercent == null
                      ? '—'
                      : '${data.averagePercent!.round()}%',
                  detail: l10n.insightsFromMarks(data.gradedCount),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.insightsAttendance,
                  value: data.attendance.ratePercent == null
                      ? '—'
                      : '${data.attendance.ratePercent!.round()}%',
                  detail: l10n.insightsAbsences(data.attendance.absent),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.insightsOnTime,
                  value: data.homework.onTimePercent == null
                      ? '—'
                      : '${data.homework.onTimePercent!.round()}%',
                  detail: l10n.insightsOfTasks(data.homework.due),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: studafyInk,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(label, style: const TextStyle(color: studafyInk, fontSize: 12)),
      Text(detail, style: const TextStyle(color: studafyMuted, fontSize: 11)),
    ],
  );
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final InsightSignal signal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final tint = switch (signal.kind) {
      InsightKind.gradeTrendDown ||
      InsightKind.homeworkSlipping ||
      InsightKind.dueSoonUnstarted => const Color(0xFFB3261E),
      InsightKind.gradeTrendUp || InsightKind.recovery => studafyCyan,
      _ => studafyNavy,
    };
    return FeatureCard(
      tint: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(signal.kind), color: tint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _headline(l10n, signal),
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in signal.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(color: studafyMuted, fontSize: 13),
                    ),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      color: studafyInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          // The sample size is stated, not implied. A parent can weigh the
          // claim instead of taking it on trust.
          Text(
            _strengthLabel(l10n, signal.strength),
            style: const TextStyle(color: studafyMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static IconData _icon(InsightKind kind) => switch (kind) {
    InsightKind.gradeTrendDown => Icons.trending_down_rounded,
    InsightKind.gradeTrendUp ||
    InsightKind.recovery => Icons.trending_up_rounded,
    InsightKind.dueSoonUnstarted => Icons.pending_actions_rounded,
    InsightKind.attendancePattern => Icons.event_busy_outlined,
    InsightKind.homeworkReliability ||
    InsightKind.homeworkSlipping => Icons.assignment_turned_in_outlined,
    InsightKind.subjectFocus => Icons.center_focus_strong_outlined,
  };

  static String _headline(AppL10n l10n, InsightSignal signal) {
    final subject = signal.subject ?? '';
    return switch (signal.kind) {
      InsightKind.subjectFocus => l10n.insightSubjectFocus(subject),
      InsightKind.gradeTrendDown => l10n.insightTrendDown(subject),
      InsightKind.gradeTrendUp => l10n.insightTrendUp(subject),
      InsightKind.recovery => l10n.insightRecovery(subject),
      InsightKind.homeworkReliability => l10n.insightHomework,
      InsightKind.homeworkSlipping => l10n.insightHomeworkSlipping,
      InsightKind.attendancePattern => l10n.insightAttendancePattern,
      InsightKind.dueSoonUnstarted => l10n.insightDueSoon,
    };
  }

  static String _strengthLabel(AppL10n l10n, InsightStrength strength) =>
      switch (strength) {
        InsightStrength.insufficient => l10n.insightStrengthInsufficient,
        InsightStrength.low => l10n.insightStrengthLow,
        InsightStrength.medium => l10n.insightStrengthMedium,
        InsightStrength.high => l10n.insightStrengthHigh,
      };
}

class _SubjectTable extends StatelessWidget {
  const _SubjectTable({required this.subjects});

  final List<SubjectBreakdown> subjects;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Card(
      child: Column(
        children: [
          for (final subject in subjects)
            ListTile(
              title: Text(subject.subject),
              subtitle: Text(l10n.insightsFromMarks(subject.gradedCount)),
              trailing: Text(
                '${subject.averagePercent.round()}%',
                style: const TextStyle(
                  color: studafyInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
