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
                ),
            ],
          ),
      ],
    );
  }

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
    _ => InsightKind.recovery,
  };

  static InsightStrength _strength(String value) => switch (value) {
    'high' => InsightStrength.high,
    'medium' => InsightStrength.medium,
    'low' => InsightStrength.low,
    _ => InsightStrength.insufficient,
  };
}
