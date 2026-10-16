import '../domain/safety_review.dart';

/// The operator's review steps (DL-063). Presentation calls this, never the
/// repository (ARC-011). It keeps no report content beyond the call that
/// returned it and sends nothing to telemetry.
class SafetyReviewInteractor {
  const SafetyReviewInteractor(this.repository);

  final SafetyReviewRepository repository;

  /// The grant's reason and the decision's note: 8 to 2000 characters, as
  /// the server takes them.
  static const minText = 8;
  static const maxText = 2000;

  static bool validText(String value) {
    final length = value.trim().length;
    return length >= minText && length <= maxText;
  }

  /// An authenticator code: six digits.
  static bool validCode(String value) =>
      RegExp(r'^[0-9]{6}$').hasMatch(value.trim());

  Future<SafetyReviewQueue> queue() => repository.openReports();

  Future<bool> secondFactorEnrolled() => repository.secondFactorEnrolled();

  /// Opens a report the operator already holds a grant for.
  Future<SafetyReviewReport> open(String reportId) =>
      repository.openReport(reportId);

  /// Steps the session up with [code], then opens the report: for an
  /// operator whose grant is live but whose session is not AAL2.
  Future<SafetyReviewReport> stepUpAndOpen({
    required String reportId,
    required String code,
  }) async {
    await repository.presentSecondFactor(code.trim());
    return repository.openReport(reportId);
  }

  /// Steps the session up with [code], obtains a grant for [report] with
  /// [reason], and opens it.
  Future<SafetyReviewReport> unlock({
    required SafetyReviewSummary report,
    required String reason,
    required String code,
  }) async {
    if (!validText(reason)) {
      throw ArgumentError.value(reason, 'reason', 'needs 8-2000 characters');
    }
    await repository.presentSecondFactor(code.trim());
    await repository.obtainGrant(report: report, reason: reason.trim());
    return repository.openReport(report.id);
  }

  Future<SafetyReviewReport> resolve({
    required SafetyReviewReport report,
    required SafetyReviewOutcome outcome,
    required String note,
  }) {
    if (!validText(note)) {
      throw ArgumentError.value(note, 'note', 'needs 8-2000 characters');
    }
    return repository.resolve(
      report: report,
      outcome: outcome,
      note: note.trim(),
    );
  }
}
