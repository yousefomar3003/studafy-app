import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
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
      setState(() {
        _future = _load();
      });
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
      appBar: AppBar(title: Text(l10n.insightsTitle), actions: widget.actions),
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
          return StudafyRefreshIndicator(
            onRefresh: () async => setState(() {
              _future = _load();
            }),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Headline(data: data),
                const SizedBox(height: 20),
                _SectionTitle(l10n.insightsFocusTitle),
                const SizedBox(height: 8),
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
                if (data.timeline.length >= 2) ...[
                  const SizedBox(height: 12),
                  _SectionTitle(l10n.insightsProgressTitle),
                  const SizedBox(height: 8),
                  _TimelineChart(points: data.timeline),
                ],
                if (data.classes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(l10n.insightsByClass),
                  const SizedBox(height: 8),
                  for (final line in data.classes) _ClassCard(line: line),
                ] else if (data.subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionTitle(l10n.insightsBySubject),
                  const SizedBox(height: 8),
                  _SubjectTable(subjects: data.subjects),
                ],
                if (data.missingWork.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(l10n.insightsMissingTitle),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final work in data.missingWork)
                          ListTile(
                            leading: const Icon(
                              Icons.assignment_late_outlined,
                              color: Color(0xFFB3261E),
                            ),
                            title: UserContentText(work.title),
                            subtitle: Text(
                              [
                                if (work.className != null) work.className!,
                                l10n.insightsDueOn(_shortDate(work.dueAt)),
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (data.recentMarks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle(l10n.insightsRecentTitle),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final mark in data.recentMarks)
                          _RecentMarkTile(mark: mark),
                      ],
                    ),
                  ),
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
              Expanded(
                child: _Stat(
                  label: l10n.insightsMissedTests,
                  value: '${data.missedAssessments}',
                  detail: l10n.insightsMissingCount(data.missingWork.length),
                ),
              ),
            ],
          ),
          if (data.averageChange case final change?) ...[
            const SizedBox(height: 12),
            _TrendLine(points: change),
          ],
        ],
      ),
    );
  }
}

/// "Up 6 points" / "Down 6 points" / "Steady": the child against their own
/// earlier marks.
class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.points});

  final double points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rounded = points.abs().round();
    final (icon, color, text) = points >= 5
        ? (
            Icons.trending_up_rounded,
            studafyCyan,
            l10n.insightsTrendUp(rounded),
          )
        : points <= -5
        ? (
            Icons.trending_down_rounded,
            const Color(0xFFB3261E),
            l10n.insightsTrendDown(rounded),
          )
        : (Icons.trending_flat_rounded, studafyMuted, l10n.insightsTrendSteady);
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Average mark per week or month as bars, oldest first. Drawn from plain
/// widgets: a dozen bars need no chart library, and they follow the
/// reading direction by themselves.
class _TimelineChart extends StatelessWidget {
  const _TimelineChart({required this.points});

  final List<InsightTimelinePoint> points;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthly =
        points.length < 2 ||
        points[1].start.difference(points[0].start).inDays > 8;
    String label(DateTime start) {
      try {
        return monthly
            ? DateFormat.MMM(locale).format(start)
            : DateFormat.Md(locale).format(start);
      } on Object {
        return '${start.month}/${start.day}';
      }
    }

    return FeatureCard(
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final point
                in points.length > 12
                    ? points.sublist(points.length - 12)
                    : points)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${point.averagePercent.round()}',
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height:
                            110 * (point.averagePercent.clamp(0, 100) / 100) +
                            2,
                        decoration: BoxDecoration(
                          color: studafyCyan,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label(point.start),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.line});

  final ClassInsight line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final standing = line.standing;
    final trend = switch (line.trend) {
      ClassTrend.up => l10n.insightsTrendUp(
        (line.trendPoints ?? 0).abs().round(),
      ),
      ClassTrend.down => l10n.insightsTrendDown(
        (line.trendPoints ?? 0).abs().round(),
      ),
      ClassTrend.steady => l10n.insightsTrendSteady,
      ClassTrend.insufficient => l10n.insightsTrendUnknown,
    };
    final facts = <String>[
      trend,
      if (line.attendanceRatePercent case final rate?)
        l10n.insightsClassAttendance(rate.round()),
      if (line.homeworkOnTimePercent case final rate?)
        l10n.insightsClassOnTime(rate.round()),
      if (line.homeworkMissing > 0)
        l10n.insightsMissingCount(line.homeworkMissing),
      if (line.missedAssessments > 0)
        l10n.insightsMissedCount(line.missedAssessments),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: UserContentText(
                    line.className,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (standing != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        standing == ClassStanding.strongest
                            ? l10n.insightsStrongest
                            : l10n.insightsWeakest,
                      ),
                    ),
                  ),
                Text(
                  line.averagePercent == null
                      ? '—'
                      : '${line.averagePercent!.round()}%',
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.insightsFromMarks(line.gradedCount),
              style: const TextStyle(color: studafyMuted, fontSize: 12),
            ),
            if (line.averagePercent != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (line.averagePercent! / 100).clamp(0, 1),
                  minHeight: 6,
                  color: line.standing == ClassStanding.weakest
                      ? const Color(0xFFB3261E)
                      : studafyCyan,
                  backgroundColor: studafyCanvas,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              facts.join(' · '),
              style: const TextStyle(color: studafyInk, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMarkTile extends StatelessWidget {
  const _RecentMarkTile({required this.mark});

  final RecentMark mark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final missed = mark.percent == null;
    return ListTile(
      leading: Icon(
        mark.paper ? Icons.description_outlined : Icons.laptop_outlined,
        color: studafyNavy,
      ),
      title: UserContentText(mark.title),
      subtitle: Text(
        [
          mark.className,
          if (mark.paper) l10n.insightsPaper,
          _shortDate(mark.at),
        ].join(' · '),
      ),
      trailing: Text(
        missed ? l10n.insightsMissed : '${mark.percent!.round()}%',
        style: TextStyle(
          color: missed ? const Color(0xFFB3261E) : studafyInk,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
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
      InsightKind.missingWork ||
      InsightKind.missedAssessments ||
      InsightKind.dueSoonUnstarted => const Color(0xFFB3261E),
      InsightKind.gradeTrendUp ||
      InsightKind.recovery ||
      InsightKind.strength => studafyCyan,
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
                      _evidenceLabel(context, signal, item),
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
    InsightKind.missingWork => Icons.assignment_late_outlined,
    InsightKind.missedAssessments => Icons.event_note_outlined,
    InsightKind.attendanceLow => Icons.person_off_outlined,
    InsightKind.strength => Icons.emoji_events_outlined,
  };

  /// The evidence line in the reader's language; the server's English label
  /// only for a code this build does not know.
  static String _evidenceLabel(
    BuildContext context,
    InsightSignal signal,
    InsightEvidenceItem item,
  ) {
    final l10n = AppL10n.of(context);
    return switch (item.code) {
      InsightEvidenceCode.classAverage when signal.subject != null =>
        l10n.insightEvClassAverage(signal.subject!),
      InsightEvidenceCode.overallAverage => l10n.insightEvOverallAverage,
      InsightEvidenceCode.recentTypical => l10n.insightEvRecentTypical,
      InsightEvidenceCode.earlierTypical => l10n.insightEvEarlierTypical,
      InsightEvidenceCode.change => l10n.insightEvChange,
      InsightEvidenceCode.onTime => l10n.insightEvOnTime,
      InsightEvidenceCode.late => l10n.insightEvLate,
      InsightEvidenceCode.notHandedIn => l10n.insightEvNotHandedIn,
      InsightEvidenceCode.weekdayAbsences when item.weekday != null =>
        l10n.insightEvWeekdayAbsences(_weekday(context, item.weekday!)),
      InsightEvidenceCode.absencesTotal => l10n.insightEvAbsencesTotal,
      InsightEvidenceCode.dueSoon => l10n.insightEvDueSoon,
      InsightEvidenceCode.missedAssessments => l10n.insightEvMissed,
      InsightEvidenceCode.attendanceRate => l10n.insightEvAttendanceRate,
      InsightEvidenceCode.sessionsCounted => l10n.insightEvSessions,
      InsightEvidenceCode.pastDue => l10n.insightEvPastDue,
      _ => item.label,
    };
  }

  /// 0 = Sunday. 7 January 2024 was a Sunday.
  static String _weekday(BuildContext context, int weekday) {
    final day = DateTime(2024, 1, 7 + weekday);
    try {
      return DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag())
          .format(day);
    } on Object {
      return DateFormat.EEEE('en').format(day);
    }
  }

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
      InsightKind.missingWork =>
        signal.subject == null
            ? l10n.insightMissingWork
            : l10n.insightMissingWorkIn(subject),
      InsightKind.missedAssessments =>
        signal.subject == null
            ? l10n.insightMissedTests
            : l10n.insightMissedTestsIn(subject),
      InsightKind.attendanceLow => l10n.insightAttendanceLow,
      InsightKind.strength => l10n.insightStrength(subject),
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
