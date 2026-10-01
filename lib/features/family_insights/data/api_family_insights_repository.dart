import '../../../data/contracts/v1_client.generated.dart';
import '../domain/family_insights.dart';

/// Reads Family+ from the one endpoint that serves the whole tab.
///
/// No arithmetic here: the server derives the signals so the thresholds that
/// decide what may be claimed about a child live in one tested place rather
/// than in every client that ships.
class ApiFamilyInsightsRepository implements FamilyInsightsRepository {
  ApiFamilyInsightsRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<FamilyInsights> forStudent(String studentId) async {
    final r = await _client.getFamilyInsights(studentId: studentId);
    return FamilyInsights(
      studentName: r.studentName,
      gradedCount: r.gradedCount,
      averagePercent: r.averagePercent?.toDouble(),
      subjects: [
        for (final s in r.subjects)
          SubjectBreakdown(
            subject: s.subject,
            averagePercent: s.averagePercent.toDouble(),
            gradedCount: s.gradedCount,
          ),
      ],
      attendance: AttendanceSummary(
        present: r.attendance.present,
        late: r.attendance.late,
        absent: r.attendance.absent,
        excused: r.attendance.excused,
        ratePercent: r.attendance.ratePercent?.toDouble(),
      ),
      homework: HomeworkSummary(
        due: r.homework.due,
        onTime: r.homework.onTime,
        late: r.homework.late,
        missing: r.homework.missing,
        onTimePercent: r.homework.onTimePercent?.toDouble(),
      ),
      upcoming: [
        for (final u in r.upcoming)
          UpcomingWork(
            assignmentId: u.assignmentId,
            title: u.title,
            dueAt: DateTime.parse(u.dueAt),
          ),
      ],
      wellbeing: [
        for (final w in r.wellbeing)
          SharedWellbeingNote(
            id: w.id,
            title: w.title,
            createdAt: DateTime.parse(w.createdAt),
          ),
      ],
      signals: [
        for (final s in r.signals)
          InsightSignal(
            kind: _kind(s.kind),
            subject: s.subject,
            strength: _strength(s.confidence),
            evidence: [
              for (final e in s.evidence)
                InsightEvidenceItem(
                  label: e.label,
                  value: e.value,
                  recordCount: e.recordCount,
                  code: _code(e.code),
                  weekday: e.weekday,
                ),
            ],
          ),
      ],
      averageChange: r.averageChange?.toDouble(),
      missedAssessments: r.missedAssessments ?? 0,
      classes: [
        for (final c in r.classes ?? const <V1ClassInsightDto>[])
          ClassInsight(
            classroomId: c.classroomId,
            className: c.className,
            averagePercent: c.averagePercent?.toDouble(),
            gradedCount: c.gradedCount,
            latestPercent: c.latestPercent?.toDouble(),
            trend: switch (c.trend) {
              'up' => ClassTrend.up,
              'down' => ClassTrend.down,
              'steady' => ClassTrend.steady,
              _ => ClassTrend.insufficient,
            },
            trendPoints: c.trendPoints?.toDouble(),
            missedAssessments: c.missedAssessments,
            attendanceRatePercent: c.attendanceRatePercent?.toDouble(),
            absences: c.absences,
            homeworkDue: c.homeworkDue,
            homeworkMissing: c.homeworkMissing,
            homeworkLate: c.homeworkLate,
            homeworkOnTimePercent: c.homeworkOnTimePercent?.toDouble(),
            standing: switch (c.standing) {
              'strongest' => ClassStanding.strongest,
              'weakest' => ClassStanding.weakest,
              _ => null,
            },
          ),
      ],
      timeline: [
        for (final t in r.timeline ?? const <V1InsightTimelinePointDto>[])
          InsightTimelinePoint(
            start: DateTime.parse(t.start),
            averagePercent: t.averagePercent.toDouble(),
            gradedCount: t.gradedCount,
          ),
      ],
      recentMarks: [
        for (final m in r.recentMarks ?? const <V1RecentMarkDto>[])
          RecentMark(
            title: m.title,
            className: m.className,
            percent: m.mark == 'absent' ? null : m.percent?.toDouble(),
            paper: m.paper,
            at: DateTime.parse(m.at),
          ),
      ],
      missingWork: [
        for (final w in r.missingWork ?? const <V1MissingWorkDto>[])
          MissingWorkItem(
            assignmentId: w.assignmentId,
            title: w.title,
            className: w.className,
            dueAt: DateTime.parse(w.dueAt),
          ),
      ],
    );
  }

  static InsightEvidenceCode _code(String? value) => switch (value) {
    'class_average' => InsightEvidenceCode.classAverage,
    'overall_average' => InsightEvidenceCode.overallAverage,
    'recent_typical' => InsightEvidenceCode.recentTypical,
    'earlier_typical' => InsightEvidenceCode.earlierTypical,
    'change' => InsightEvidenceCode.change,
    'on_time' => InsightEvidenceCode.onTime,
    'late' => InsightEvidenceCode.late,
    'not_handed_in' => InsightEvidenceCode.notHandedIn,
    'weekday_absences' => InsightEvidenceCode.weekdayAbsences,
    'absences_total' => InsightEvidenceCode.absencesTotal,
    'due_soon' => InsightEvidenceCode.dueSoon,
    'missed_assessments' => InsightEvidenceCode.missedAssessments,
    'attendance_rate' => InsightEvidenceCode.attendanceRate,
    'sessions_counted' => InsightEvidenceCode.sessionsCounted,
    'past_due' => InsightEvidenceCode.pastDue,
    _ => InsightEvidenceCode.unknown,
  };

  // An unrecognised kind from a newer server renders as its evidence alone
  // rather than crashing a paying parent's screen.
  static InsightKind _kind(String value) => switch (value) {
    'subject_focus' => InsightKind.subjectFocus,
    'grade_trend_up' => InsightKind.gradeTrendUp,
    'grade_trend_down' => InsightKind.gradeTrendDown,
    'homework_reliability' => InsightKind.homeworkReliability,
    'homework_slipping' => InsightKind.homeworkSlipping,
    'attendance_pattern' => InsightKind.attendancePattern,
    'due_soon_unstarted' => InsightKind.dueSoonUnstarted,
    'missing_work' => InsightKind.missingWork,
    'missed_assessments' => InsightKind.missedAssessments,
    'attendance_low' => InsightKind.attendanceLow,
    'strength' => InsightKind.strength,
    _ => InsightKind.recovery,
  };

  static InsightStrength _strength(String value) => switch (value) {
    'high' => InsightStrength.high,
    'medium' => InsightStrength.medium,
    'low' => InsightStrength.low,
    _ => InsightStrength.insufficient,
  };
}
