import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/insight_engine.dart';

void main() {
  const engine = InsightEngine();
  final now = DateTime.utc(2026, 9, 8, 12);

  test('excused attendance is visible but excluded from the rate', () {
    final result = engine.attendance([
      AttendanceObservation(AttendanceState.present, now),
      AttendanceObservation(AttendanceState.absent, now),
      AttendanceObservation(AttendanceState.excused, now),
    ], now: now);

    expect(result.value, 50);
    expect(result.evidence.first.recordCount, 2);
    expect(result.evidence.last.value, contains('1 excluded'));
  });

  test('completion excludes work that is not due yet', () {
    final result = engine.completion([
      CompletionObservation(
        CompletionState.onTime,
        now.subtract(const Duration(days: 1)),
      ),
      CompletionObservation(
        CompletionState.missing,
        now.add(const Duration(days: 1)),
      ),
    ], now: now);

    expect(result.value, 100);
    expect(result.evidence.single.recordCount, 1);
  });

  test(
    'school category weights are normalized across available categories',
    () {
      final result = engine.gradeMastery([
        GradeObservation(
          earned: 50,
          available: 100,
          recordedAt: now,
          category: 'exam',
          categoryWeight: 70,
        ),
        GradeObservation(
          earned: 100,
          available: 100,
          recordedAt: now,
          category: 'homework',
          categoryWeight: 30,
        ),
      ], now: now);

      expect(result.value, 65);
      expect(result.confidence, InsightConfidence.insufficient);
    },
  );

  test('one weak record never generates needs-attention', () {
    final needsAttention = engine.needsAttention(
      grades: [GradeObservation(earned: 2, available: 10, recordedAt: now)],
      completion: const [],
      attendance: const [],
      now: now,
    );

    expect(needsAttention, isFalse);
  });

  test('two recent missing items generate needs-attention', () {
    final needsAttention = engine.needsAttention(
      grades: const [],
      completion: [
        CompletionObservation(
          CompletionState.missing,
          now.subtract(const Duration(days: 2)),
        ),
        CompletionObservation(
          CompletionState.missing,
          now.subtract(const Duration(days: 7)),
        ),
      ],
      attendance: const [],
      now: now,
    );

    expect(needsAttention, isTrue);
  });
}
