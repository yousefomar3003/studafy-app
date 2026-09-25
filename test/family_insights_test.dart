import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/family_insights/application/family_insights_interactor.dart';
import 'package:studafy/features/family_insights/domain/family_insights.dart';
import 'package:studafy/features/family_insights/presentation/family_insights_page.dart';

import 'support/localized_app.dart';

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
