import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family_insights/application/family_insights_interactor.dart';
import 'package:studafy/features/family_insights/domain/family_insights.dart';
import 'package:studafy/features/family_insights/presentation/family_insights_page.dart';

import '../../support/localized_app.dart';

/// Family+ is paid, and it makes statements about somebody's child. The tests
/// that matter are the ones about what it will not show.
void main() {
  Widget page(FamilyInsightsRepository repository, {Locale? locale}) =>
      localizedApp(
        locale: locale,
        home: FamilyInsightsPage(
          insights: FamilyInsightsInteractor(
            repository: repository,
            telemetry: const NoopTelemetry(),
          ),
          studentId: 'student-1',
        ),
      );

  testWidgets('a parent without a subscription sees the offer, not the data', (
    tester,
  ) async {
    // The server refuses; the client must not invent a partial view from
    // whatever it happens to have cached.
    await tester.pumpWidget(page(_Refused()));
    await tester.pumpAndSettle();

    expect(find.text('Insights are not available'), findsOneWidget);
    expect(find.textContaining('Family+ is needed'), findsOneWidget);
    expect(find.text('Maths'), findsNothing);
  });

  testWidgets('a subscribed parent sees the signals with their evidence', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Served(_insights())));
    await tester.pumpAndSettle();

    expect(find.text('Kid Student'), findsOneWidget);
    expect(find.text('Maths marks are going down'), findsOneWidget);
    // The numbers behind the claim are on screen, so a parent can check it
    // against the marks they can already see.
    expect(find.text('Typical recent mark'), findsOneWidget);
    // Once in the signal's evidence and once in the subject table - the same
    // number reached two ways, which is the point of showing the workings.
    expect(find.text('52%'), findsNWidgets(2));
  });

  testWidgets('the sample size is always stated', (tester) async {
    await tester.pumpWidget(page(_Served(_insights())));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Based on a small number of records'),
      findsOneWidget,
    );
  });

  testWidgets('no marks yet reads as a dash, never as zero per cent', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(_Served(_insights(average: null, graded: 0, signals: const []))),
    );
    await tester.pumpAndSettle();

    // "0%" would tell a parent their child scored nothing.
    expect(find.text('0%'), findsNothing);
    expect(find.text('—'), findsWidgets);
    expect(find.text('No marks yet'), findsWidgets);
  });

  testWidgets('nothing to report says so rather than showing an empty page', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(_Served(_insights(average: null, graded: 0, signals: const []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing to report yet'), findsOneWidget);
  });

  testWidgets('the richer view: focus, chart, each class, missing work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(_Served(_rich())));
    await tester.pumpAndSettle();

    expect(find.text('WHAT TO FOCUS ON'), findsOne);
    expect(find.text('A test in Maths was missed'), findsOne);
    // The server's English label is replaced by the app's own wording.
    expect(find.text('Tests missed'), findsOne);
    expect(find.text('MARKS OVER TIME'), findsOne);
    expect(find.text('CLASS BY CLASS'), findsOne);
    expect(find.text('Weakest'), findsOne);
    expect(find.text('Strongest'), findsOne);
    expect(find.textContaining('Attendance 80%'), findsOne);
    expect(find.text('MISSING WORK'), findsOne);
    expect(find.text('Essay'), findsOne);
    expect(find.text('LATEST MARKS'), findsOne);
    // A missed paper exam is "Missed", never 0%.
    expect(find.text('Missed'), findsOne);
    expect(find.textContaining('Paper'), findsWidgets);
    expect(find.text('Up 6 points compared with earlier'), findsOne);
  });

  testWidgets('the richer view reads in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(page(_Served(_rich()), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('حسب الصف'), findsOne);
    expect(find.text('الأضعف'), findsOne);
    expect(find.text('اختبارات فائتة'), findsWidgets);
  });

  testWidgets('reads in Arabic', (tester) async {
    await tester.pumpWidget(
      page(_Served(_insights()), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(
      directionOf(tester, find.byType(FamilyInsightsPage)),
      TextDirection.rtl,
    );
    expect(find.text('العائلة+'), findsWidgets);
  });
}

FamilyInsights _insights({
  double? average = 61,
  int graded = 6,
  List<InsightSignal>? signals,
}) => FamilyInsights(
  studentName: 'Kid Student',
  gradedCount: graded,
  averagePercent: average,
  subjects: const [
    SubjectBreakdown(subject: 'Maths', averagePercent: 52, gradedCount: 3),
  ],
  attendance: const AttendanceSummary(
    present: 18,
    late: 1,
    absent: 2,
    excused: 1,
    ratePercent: 90.5,
  ),
  homework: const HomeworkSummary(
    due: 8,
    onTime: 6,
    late: 1,
    missing: 1,
    onTimePercent: 75,
  ),
  upcoming: const [],
  wellbeing: const [],
  signals:
      signals ??
      const [
        InsightSignal(
          kind: InsightKind.gradeTrendDown,
          subject: 'Maths',
          strength: InsightStrength.low,
          evidence: [
            InsightEvidenceItem(
              label: 'Typical recent mark',
              value: '52%',
              recordCount: 3,
            ),
            InsightEvidenceItem(
              label: 'Typical earlier mark',
              value: '80%',
              recordCount: 3,
            ),
          ],
        ),
      ],
);

FamilyInsights _rich() => FamilyInsights(
  studentName: 'Kid Student',
  gradedCount: 8,
  averagePercent: 71,
  subjects: const [],
  attendance: const AttendanceSummary(
    present: 16,
    late: 0,
    absent: 4,
    excused: 0,
    ratePercent: 80,
  ),
  homework: const HomeworkSummary(
    due: 4,
    onTime: 3,
    late: 0,
    missing: 1,
    onTimePercent: 75,
  ),
  upcoming: const [],
  wellbeing: const [],
  averageChange: 6,
  missedAssessments: 1,
  signals: const [
    InsightSignal(
      kind: InsightKind.missedAssessments,
      subject: 'Maths',
      strength: InsightStrength.high,
      evidence: [
        InsightEvidenceItem(
          label: 'Tests missed (server wording)',
          value: '1',
          recordCount: 1,
          code: InsightEvidenceCode.missedAssessments,
        ),
      ],
    ),
  ],
  classes: const [
    ClassInsight(
      classroomId: 'm',
      className: 'Maths',
      averagePercent: 55,
      gradedCount: 4,
      latestPercent: 50,
      trend: ClassTrend.down,
      trendPoints: -8,
      missedAssessments: 1,
      attendanceRatePercent: 80,
      absences: 4,
      homeworkDue: 2,
      homeworkMissing: 1,
      homeworkLate: 0,
      homeworkOnTimePercent: 50,
      standing: ClassStanding.weakest,
    ),
    ClassInsight(
      classroomId: 'a',
      className: 'Art',
      averagePercent: 90,
      gradedCount: 4,
      latestPercent: 92,
      trend: ClassTrend.steady,
      trendPoints: 1,
      missedAssessments: 0,
      attendanceRatePercent: null,
      absences: 0,
      homeworkDue: 2,
      homeworkMissing: 0,
      homeworkLate: 0,
      homeworkOnTimePercent: 100,
      standing: ClassStanding.strongest,
    ),
  ],
  timeline: [
    InsightTimelinePoint(
      start: DateTime.utc(2026, 7),
      averagePercent: 65,
      gradedCount: 3,
    ),
    InsightTimelinePoint(
      start: DateTime.utc(2026, 8),
      averagePercent: 72,
      gradedCount: 3,
    ),
    InsightTimelinePoint(
      start: DateTime.utc(2026, 9),
      averagePercent: 78,
      gradedCount: 2,
    ),
  ],
  recentMarks: [
    RecentMark(
      title: 'Paper exam 1',
      className: 'Maths',
      percent: null,
      paper: true,
      at: DateTime.utc(2026, 9, 20),
    ),
    RecentMark(
      title: 'Quiz 2',
      className: 'Art',
      percent: 92,
      paper: false,
      at: DateTime.utc(2026, 9, 18),
    ),
  ],
  missingWork: [
    MissingWorkItem(
      assignmentId: 'w1',
      title: 'Essay',
      className: 'Maths',
      dueAt: DateTime.utc(2026, 9, 19),
    ),
  ],
);

class _Served implements FamilyInsightsRepository {
  _Served(this.value);

  final FamilyInsights value;

  @override
  Future<FamilyInsights> forStudent(String studentId) async => value;
}

class _Refused implements FamilyInsightsRepository {
  @override
  Future<FamilyInsights> forStudent(String studentId) async =>
      throw Failure.forbidden;
}
