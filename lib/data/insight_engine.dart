import '../core/studafy_domain.dart';

class GradeObservation {
  const GradeObservation({
    required this.earned,
    required this.available,
    required this.recordedAt,
    this.category,
    this.categoryWeight,
  });

  final double earned;
  final double available;
  final DateTime recordedAt;
  final String? category;
  final double? categoryWeight;
}

enum AttendanceState { present, absent, late, excused }

class AttendanceObservation {
  const AttendanceObservation(this.state, this.recordedAt);
  final AttendanceState state;
  final DateTime recordedAt;
}

enum CompletionState { onTime, late, missing, excused }

class CompletionObservation {
  const CompletionObservation(this.state, this.dueAt);
  final CompletionState state;
  final DateTime dueAt;
}

class InsightEngine {
  const InsightEngine();

  InsightMetric gradeMastery(
    List<GradeObservation> records, {
    required DateTime now,
  }) {
    final usable = records.where((r) => r.available > 0).toList();
    final earned = usable.fold<double>(0, (sum, row) => sum + row.earned);
    final available = usable.fold<double>(0, (sum, row) => sum + row.available);
    final value = _weightedGradePercent(usable);
    final recentStart = now.subtract(const Duration(days: 28));
    final previousStart = now.subtract(const Duration(days: 56));
    final recent = usable
        .where((r) => !r.recordedAt.isBefore(recentStart))
        .toList();
    final previous = usable
        .where(
          (r) =>
              r.recordedAt.isBefore(recentStart) &&
              !r.recordedAt.isBefore(previousStart),
        )
        .toList();
    final rawChange = _pointsPercent(recent) - _pointsPercent(previous);
    final comparableCount = recent.length + previous.length;
    final shrinkage = comparableCount / (comparableCount + 5);
    final change = previous.isEmpty ? null : rawChange * shrinkage;

    return InsightMetric(
      id: 'grade-mastery',
      title: 'Published grade mastery',
      value: value,
      change: change,
      confidence: _confidence(usable.length),
      evidence: [
        InsightEvidence(
          label: 'Published results',
          value: '${_trim(earned)} / ${_trim(available)} points',
          recordCount: usable.length,
          sourceRoute: '/grades',
        ),
      ],
      updatedAt: now,
      explanation: change == null
          ? 'More history is needed before a momentum comparison is shown.'
          : 'Momentum compares the latest four instructional weeks with the previous four and reduces the effect of small samples.',
    );
  }

  InsightMetric attendance(
    List<AttendanceObservation> records, {
    required DateTime now,
  }) {
    final eligible = records
        .where((row) => row.state != AttendanceState.excused)
        .toList();
    final present = eligible
        .where((row) => row.state == AttendanceState.present)
        .length;
    final late = eligible
        .where((row) => row.state == AttendanceState.late)
        .length;
    final absent = eligible
        .where((row) => row.state == AttendanceState.absent)
        .length;
    final value = eligible.isEmpty ? 0.0 : present / eligible.length * 100;
    return InsightMetric(
      id: 'attendance',
      title: 'Attendance',
      value: value,
      confidence: _confidence(eligible.length),
      evidence: [
        InsightEvidence(
          label: 'Eligible sessions',
          value: '$present present · $late late · $absent absent',
          recordCount: eligible.length,
          sourceRoute: '/attendance',
        ),
        InsightEvidence(
          label: 'Excused sessions',
          value: '${records.length - eligible.length} excluded from rate',
          recordCount: records.length - eligible.length,
        ),
      ],
      updatedAt: now,
      explanation: 'Excused absences are displayed but are not counted against attendance. Lateness is reported separately.',
    );
  }

  InsightMetric completion(
    List<CompletionObservation> records, {
    required DateTime now,
  }) {
    final due = records.where((row) => !row.dueAt.isAfter(now)).toList();
    final eligible = due
        .where((row) => row.state != CompletionState.excused)
        .toList();
    int count(CompletionState state) =>
        eligible.where((row) => row.state == state).length;
    final onTime = count(CompletionState.onTime);
    final late = count(CompletionState.late);
    final missing = count(CompletionState.missing);
    final value = eligible.isEmpty ? 0.0 : onTime / eligible.length * 100;
    return InsightMetric(
      id: 'completion',
      title: 'On-time completion',
      value: value,
      confidence: _confidence(eligible.length),
      evidence: [
        InsightEvidence(
          label: 'Due work',
          value: '$onTime on time · $late late · $missing missing',
          recordCount: eligible.length,
          sourceRoute: '/work',
        ),
      ],
      updatedAt: now,
      explanation: 'Only work whose deadline has passed is included. Excused work remains visible but is excluded.',
    );
  }

  bool needsAttention({
    required List<GradeObservation> grades,
    required List<CompletionObservation> completion,
    required List<AttendanceObservation> attendance,
    required DateTime now,
    double masteryThreshold = 60,
  }) {
    final recentMissing = completion.where((row) {
      return row.state == CompletionState.missing &&
          row.dueAt.isAfter(now.subtract(const Duration(days: 14))) &&
          !row.dueAt.isAfter(now);
    }).length;
    final recentAbsences = attendance.where((row) {
      return row.state == AttendanceState.absent &&
          row.recordedAt.isAfter(now.subtract(const Duration(days: 14)));
    }).length;
    final gradePercent = _pointsPercent(grades);
    return recentMissing >= 2 ||
        recentAbsences >= 2 ||
        (grades.length >= 3 && gradePercent < masteryThreshold);
  }

  double _pointsPercent(List<GradeObservation> values) {
    final usable = values.where((row) => row.available > 0);
    final earned = usable.fold<double>(0, (sum, row) => sum + row.earned);
    final available = usable.fold<double>(0, (sum, row) => sum + row.available);
    return available == 0 ? 0 : earned / available * 100;
  }

  double _weightedGradePercent(List<GradeObservation> values) {
    final usable = values.where((row) => row.available > 0).toList();
    if (usable.isEmpty) return 0;
    final hasPolicy = usable.any(
      (row) => row.category != null && row.categoryWeight != null,
    );
    if (!hasPolicy) return _pointsPercent(usable);

    final groups = <String, List<GradeObservation>>{};
    for (final row in usable) {
      groups.putIfAbsent(row.category ?? 'unweighted', () => []).add(row);
    }
    var weightedTotal = 0.0;
    var availableWeight = 0.0;
    for (final entry in groups.entries) {
      final rows = entry.value;
      final weight = rows
          .map((row) => row.categoryWeight)
          .whereType<double>()
          .firstOrNull;
      if (weight == null || weight <= 0) continue;
      weightedTotal += _pointsPercent(rows) * weight;
      availableWeight += weight;
    }
    return availableWeight == 0
        ? _pointsPercent(usable)
        : weightedTotal / availableWeight;
  }

  InsightConfidence _confidence(int count) => switch (count) {
    < 3 => InsightConfidence.insufficient,
    < 6 => InsightConfidence.low,
    < 12 => InsightConfidence.medium,
    _ => InsightConfidence.high,
  };

  String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
