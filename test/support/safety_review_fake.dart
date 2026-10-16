import 'package:studafy/features/safety_review/domain/safety_review.dart';

/// A safety-review server in memory: who holds a grant, whether the session
/// has stepped up, and which step should fail next. Every call is recorded.
class FakeSafetyReviewRepository implements SafetyReviewRepository {
  FakeSafetyReviewRepository({
    List<SafetyReviewSummary>? reports,
    this.singleReviewer = true,
  }) : reports = reports ?? [sampleSummary()];

  List<SafetyReviewSummary> reports;
  bool singleReviewer;

  /// Refuses the next queue read.
  SafetyReviewError? queueError;

  /// The account has a verified authenticator.
  bool enrolled = true;

  /// The code the authenticator shows now.
  String validCode = '123456';

  /// The session has presented a second factor.
  bool aal2 = false;

  /// Report ids an active grant covers.
  final Set<String> granted = {};

  SafetyReviewError? grantError;
  SafetyReviewError? resolveError;

  /// Refusals for the next report reads, in order.
  final List<SafetyReviewError> openErrors = [];

  final List<String> calls = [];

  SafetyReviewReport content = sampleReport();

  @override
  Future<SafetyReviewQueue> openReports() async {
    calls.add('queue');
    final error = queueError;
    if (error != null) {
      queueError = null;
      throw SafetyReviewException(error);
    }
    return SafetyReviewQueue(
      reports: [
        for (final report in reports)
          SafetyReviewSummary(
            id: report.id,
            schoolId: report.schoolId,
            kind: report.kind,
            priority: report.priority,
            status: report.status,
            filedAt: report.filedAt,
            grantActive: report.grantActive || granted.contains(report.id),
          ),
      ],
      singleReviewer: singleReviewer,
    );
  }

  @override
  Future<bool> secondFactorEnrolled() async {
    calls.add('enrolled?');
    return enrolled;
  }

  @override
  Future<void> presentSecondFactor(String code) async {
    calls.add('code:$code');
    if (!enrolled) {
      throw const SafetyReviewException(SafetyReviewError.notEnrolled);
    }
    if (code != validCode) {
      throw const SafetyReviewException(SafetyReviewError.wrongCode);
    }
    aal2 = true;
  }

  @override
  Future<void> obtainGrant({
    required SafetyReviewSummary report,
    required String reason,
  }) async {
    calls.add('grant:${report.id}:$reason');
    if (!aal2) {
      throw const SafetyReviewException(SafetyReviewError.stepUpRequired);
    }
    final error = grantError;
    if (error != null) throw SafetyReviewException(error);
    granted.add(report.id);
  }

  @override
  Future<SafetyReviewReport> openReport(String reportId) async {
    calls.add('open:$reportId');
    if (openErrors.isNotEmpty) {
      throw SafetyReviewException(openErrors.removeAt(0));
    }
    if (!aal2) {
      throw const SafetyReviewException(SafetyReviewError.stepUpRequired);
    }
    final grantedNow =
        granted.contains(reportId) ||
        reports.any((report) => report.id == reportId && report.grantActive);
    if (!grantedNow) {
      throw const SafetyReviewException(SafetyReviewError.noGrant);
    }
    return content;
  }

  @override
  Future<SafetyReviewReport> resolve({
    required SafetyReviewReport report,
    required SafetyReviewOutcome outcome,
    required String note,
  }) async {
    calls.add('resolve:${outcome.wire}:$note');
    final error = resolveError;
    if (error != null) throw SafetyReviewException(error);
    reports = [
      for (final summary in reports)
        if (summary.id != report.id) summary,
    ];
    return report;
  }
}

const sampleReportId = '22222222-2222-4222-8222-222222222222';

SafetyReviewSummary sampleSummary({
  String id = sampleReportId,
  SafetyReviewKind kind = SafetyReviewKind.message,
  SafetyReviewPriority priority = SafetyReviewPriority.high,
  bool grantActive = false,
  DateTime? filedAt,
}) => SafetyReviewSummary(
  id: id,
  schoolId: '11111111-1111-4111-8111-111111111111',
  kind: kind,
  priority: priority,
  status: 'queued',
  filedAt: filedAt ?? DateTime(2026, 10, 16, 9),
  grantActive: grantActive,
);

SafetyReviewReport sampleReport({String status = 'queued'}) =>
    SafetyReviewReport(
      id: sampleReportId,
      schoolId: '11111111-1111-4111-8111-111111111111',
      kind: SafetyReviewKind.message,
      priority: SafetyReviewPriority.high,
      status: status,
      details: 'He keeps messaging me after I asked him to stop',
      snapshot: const {'messageBody': 'the reported message text'},
      evidence: [
        SafetyReviewEvidence(
          kind: 'note',
          addedAt: DateTime(2026, 10, 16, 9, 5),
          note: 'screenshot shared by the reporter',
        ),
      ],
      events: [
        SafetyReviewEvent(event: 'submitted', at: DateTime(2026, 10, 16, 9)),
      ],
      filedAt: DateTime(2026, 10, 16, 9),
      version: 2,
    );
