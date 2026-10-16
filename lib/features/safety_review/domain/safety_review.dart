import 'package:flutter/foundation.dart';

/// The platform operator's safety-report review (DL-063).
///
/// Only an account the server marks as a platform operator ever reaches this
/// slice, and only through the server: every read and decision is checked
/// again by the database, which also audits it. Nothing here decides who may
/// see a report.

/// How urgent a report is, as the content rules assigned it.
enum SafetyReviewPriority {
  critical,
  high,
  medium,
  low;

  static SafetyReviewPriority parse(String value) => switch (value) {
    'critical' => critical,
    'high' => high,
    'medium' => medium,
    _ => low,
  };
}

/// What a report is about.
enum SafetyReviewKind {
  message,
  conversation,
  user;

  static SafetyReviewKind parse(String value) => switch (value) {
    'message' => message,
    'conversation' => conversation,
    _ => user,
  };
}

/// The decision recorded on a report (`public.report_resolution`).
enum SafetyReviewOutcome {
  upheld('upheld'),
  partial('partial'),
  notUpheld('not_upheld'),
  noAction('no_action');

  const SafetyReviewOutcome(this.wire);

  /// The value the server takes.
  final String wire;
}

/// One open report in the queue: metadata only, never its content.
@immutable
class SafetyReviewSummary {
  const SafetyReviewSummary({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.priority,
    required this.status,
    required this.filedAt,
    required this.grantActive,
  });

  final String id;

  /// The school a moderation grant is requested for. An opaque id, never a
  /// name.
  final String schoolId;
  final SafetyReviewKind kind;
  final SafetyReviewPriority priority;

  /// The server's status word (submitted, queued, under_review ...).
  final String status;
  final DateTime filedAt;

  /// This operator already holds an active grant covering the report.
  final bool grantActive;

  /// The first block of the id, as the report alert shows it.
  String get shortId => id.split('-').first;
}

/// The queue, as the server has it now.
@immutable
class SafetyReviewQueue {
  const SafetyReviewQueue({
    required this.reports,
    required this.singleReviewer,
  });

  final List<SafetyReviewSummary> reports;

  /// Single-reviewer mode applies: this operator may approve their own
  /// grant. False means a second operator has to approve every grant.
  final bool singleReviewer;
}

/// Something attached to a report: a message, a file or a reviewer's note.
@immutable
class SafetyReviewEvidence {
  const SafetyReviewEvidence({
    required this.kind,
    required this.addedAt,
    this.note,
    this.messageId,
    this.attachmentFileId,
  });

  /// message, attachment or note.
  final String kind;
  final DateTime addedAt;
  final String? note;
  final String? messageId;
  final String? attachmentFileId;
}

/// One step in a report's history.
@immutable
class SafetyReviewEvent {
  const SafetyReviewEvent({
    required this.event,
    required this.at,
    this.note,
    this.resolution,
  });

  final String event;
  final DateTime at;
  final String? note;
  final String? resolution;
}

/// A report opened for review under an active grant.
@immutable
class SafetyReviewReport {
  const SafetyReviewReport({
    required this.id,
    required this.schoolId,
    required this.kind,
    required this.priority,
    required this.status,
    required this.details,
    required this.snapshot,
    required this.evidence,
    required this.events,
    required this.filedAt,
    required this.version,
    this.resolution,
    this.reporterId,
  });

  final String id;
  final String schoolId;
  final SafetyReviewKind kind;
  final SafetyReviewPriority priority;
  final String status;

  /// The reporter's own words, shown verbatim.
  final String details;

  /// What was reported, captured when the report was filed: the message
  /// text, the conversation subject ... Shown verbatim.
  final Map<String, String> snapshot;
  final List<SafetyReviewEvidence> evidence;
  final List<SafetyReviewEvent> events;
  final DateTime filedAt;
  final int version;
  final String? resolution;

  /// Null until the report is escalated: the reporter stays masked.
  final String? reporterId;

  bool get resolved => status == 'resolved';

  /// A decision can be recorded: the report is waiting for one, not
  /// escalated or closed (escalation follows the runbook).
  bool get decidable =>
      const {'submitted', 'queued', 'under_review', 'on_hold'}.contains(status);
}

/// Why a review step did not go through, in the words a screen needs.
enum SafetyReviewError {
  /// The account has no authenticator set up, so it cannot step up.
  notEnrolled,

  /// The authenticator code was not accepted.
  wrongCode,

  /// The server wants a second factor on this session first.
  stepUpRequired,

  /// No active grant covers the report: never had one, it expired (grants
  /// last 60 minutes), or it was revoked.
  noGrant,

  /// The grant needs a second platform operator to approve it now.
  secondApproverRequired,

  /// The report changed since it was opened (someone else decided, or it
  /// was escalated).
  changed,

  /// The server does not take this account as a platform operator.
  notOperator,

  /// Anything else: offline, the server unavailable.
  unavailable,
}

class SafetyReviewException implements Exception {
  const SafetyReviewException(this.error);
  final SafetyReviewError error;

  @override
  String toString() => 'SafetyReviewException(${error.name})';
}

/// Port for the review. Every failure is a [SafetyReviewException].
abstract interface class SafetyReviewRepository {
  /// Every open report, metadata only.
  Future<SafetyReviewQueue> openReports();

  /// Whether this account has a verified authenticator (the server's word).
  Future<bool> secondFactorEnrolled();

  /// Presents an authenticator code, raising this session to AAL2.
  Future<void> presentSecondFactor(String code);

  /// Requests a 60-minute grant scoped to [report] without a second
  /// approver, approves it (single-reviewer mode) and starts it. Needs an
  /// AAL2 session.
  Future<void> obtainGrant({
    required SafetyReviewSummary report,
    required String reason,
  });

  /// Opens the report under an active grant. Audited by the server.
  Future<SafetyReviewReport> openReport(String reportId);

  /// Records the decision: triages the report first if it is still
  /// waiting, then resolves it. Audited by the server.
  Future<SafetyReviewReport> resolve({
    required SafetyReviewReport report,
    required SafetyReviewOutcome outcome,
    required String note,
  });
}
