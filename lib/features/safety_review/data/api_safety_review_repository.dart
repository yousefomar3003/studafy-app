import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/safety_review.dart';

/// Presents an authenticator code for the signed-in session, raising it to
/// AAL2. Throws [SafetyReviewException] ([SafetyReviewError.notEnrolled],
/// [SafetyReviewError.wrongCode] or [SafetyReviewError.unavailable]).
typedef SecondFactorVerifier = Future<void> Function(String code);

/// The review over `/internal/safety-review` and the moderation commands
/// (DL-063). Every answer is the server's: it decides who is an operator,
/// whether a grant covers a report, and audits each read and decision.
class ApiSafetyReviewRepository implements SafetyReviewRepository {
  ApiSafetyReviewRepository(this._api, {required SecondFactorVerifier verify})
    // Not an initializing formal: call sites read `verify:`, not `_verify:`.
    // ignore: prefer_initializing_formals
    : _verify = verify;

  final V1ApiClient _api;
  final SecondFactorVerifier _verify;

  /// Grants last an hour: long enough to read and decide, short enough that
  /// a forgotten one ends by itself (the runbook's default).
  static const grantMinutes = 60;

  @override
  Future<SafetyReviewQueue> openReports() => _guard(() async {
    final page = await _api.listSafetyReviewReports(pageSize: 100);
    return SafetyReviewQueue(
      singleReviewer: page.singleReviewer,
      reports: [
        for (final item in page.items)
          SafetyReviewSummary(
            id: item.id,
            schoolId: item.schoolId,
            kind: SafetyReviewKind.parse(item.kind),
            priority: SafetyReviewPriority.parse(item.priority),
            status: item.status,
            filedAt: _time(item.createdAt),
            grantActive: item.grantActive,
          ),
      ],
    );
  }, (error) => error.status == 403 ? SafetyReviewError.notOperator : null);

  @override
  Future<bool> secondFactorEnrolled() => _guard(
    () async => (await _api.getAuthContext()).mfaEnrolled,
    (_) => null,
  );

  @override
  Future<void> presentSecondFactor(String code) async {
    try {
      await _verify(code);
    } on SafetyReviewException {
      rethrow;
    } on Object {
      throw const SafetyReviewException(SafetyReviewError.unavailable);
    }
  }

  @override
  Future<void> obtainGrant({
    required SafetyReviewSummary report,
    required String reason,
  }) async {
    final requested = await _guard(
      () => _api.requestModerationAccess(
        V1RequestModerationAccessRequestDto(
          schoolId: report.schoolId,
          reason: reason,
          // The alert's report id is the ticket, as in the runbook.
          ticketRef: report.id,
          resourceScope: {
            'reportIds': [report.id],
          },
          // Single-reviewer mode (DL-063): this operator approves it.
          requiresSecondApprover: false,
          durationMinutes: grantMinutes,
        ),
      ),
      (error) => error.status == 403 ? SafetyReviewError.notOperator : null,
    );
    final approved = await _guard(
      () => _api.approveModerationAccess(
        V1ModerationAccessLifecycleRequestDto(
          expectedVersion: requested.version,
        ),
        moderationGrantId: requested.id,
      ),
      // Refused as approver: a second operator exists now, or the mode was
      // switched off. The grant waits for them.
      (error) => error.status == 403 || error.status == 404
          ? SafetyReviewError.secondApproverRequired
          : null,
    );
    await _guard(
      () => _api.startModerationAccess(
        V1ModerationAccessLifecycleRequestDto(
          expectedVersion: approved.version,
        ),
        moderationGrantId: approved.id,
      ),
      (error) => error.status == 409 ? SafetyReviewError.noGrant : null,
    );
  }

  @override
  Future<SafetyReviewReport> openReport(String reportId) => _guard(
    () async => _report(await _api.openSafetyReviewReport(reportId: reportId)),
    (error) => switch (error.status) {
      403 => SafetyReviewError.noGrant,
      404 => SafetyReviewError.changed,
      _ => null,
    },
  );

  @override
  Future<SafetyReviewReport> resolve({
    required SafetyReviewReport report,
    required SafetyReviewOutcome outcome,
    required String note,
  }) => _guard(
    () async {
      var version = report.version;
      // A report still waiting is triaged first, as the review script does:
      // resolving needs it under review.
      if (report.status == 'submitted' || report.status == 'queued') {
        final triaged = await _api.triageReport(
          V1ReportLifecycleRequestDto(
            expectedVersion: version,
            note: 'Opened for review in the app.',
          ),
          reportId: report.id,
        );
        version = triaged.version;
      }
      final resolved = await _api.resolveReport(
        V1ResolveReportRequestDto(
          expectedVersion: version,
          resolution: outcome.wire,
          note: note,
        ),
        reportId: report.id,
      );
      return _report(resolved);
    },
    (error) => switch (error.status) {
      // Refused by the decision: no active grant covers the report any more
      // (moderation denials read as absence).
      403 || 404 => SafetyReviewError.noGrant,
      409 => SafetyReviewError.changed,
      _ => null,
    },
  );

  /// Runs [call], turning every failure into a [SafetyReviewException]:
  /// [map] names the ones particular to the call; a session without a
  /// second factor, and anything unreadable, are the same everywhere.
  static Future<T> _guard<T>(
    Future<T> Function() call,
    SafetyReviewError? Function(V1ApiException error) map,
  ) async {
    try {
      return await call();
    } on SafetyReviewException {
      rethrow;
    } on V1ApiException catch (error) {
      if (error.isMfaRequired) {
        throw const SafetyReviewException(SafetyReviewError.stepUpRequired);
      }
      throw SafetyReviewException(map(error) ?? SafetyReviewError.unavailable);
    } on Object {
      throw const SafetyReviewException(SafetyReviewError.unavailable);
    }
  }

  static DateTime _time(String? value) =>
      DateTime.tryParse(value ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static SafetyReviewReport _report(V1ModerationReportDto dto) =>
      SafetyReviewReport(
        id: dto.id,
        schoolId: dto.schoolId,
        kind: SafetyReviewKind.parse(dto.kind),
        priority: SafetyReviewPriority.parse(dto.priority),
        status: dto.status,
        details: dto.details,
        snapshot: {
          for (final entry in dto.evidenceSnapshot.entries)
            if (entry.value != null) entry.key: '${entry.value}',
        },
        evidence: [
          for (final item in dto.evidence)
            SafetyReviewEvidence(
              kind: _text(item['kind']) ?? 'note',
              addedAt: _time(_text(item['createdAt'])),
              note: _text(item['note']),
              messageId: _text(item['messageId']),
              attachmentFileId: _text(item['attachmentFileId']),
            ),
        ],
        events: [
          for (final item in dto.events)
            SafetyReviewEvent(
              event: _text(item['event']) ?? '',
              at: _time(_text(item['at'])),
              note: _text(item['note']),
              resolution: _text(item['resolution']),
            ),
        ],
        filedAt: _time(dto.createdAt),
        version: dto.version,
        resolution: dto.resolution,
        reporterId: dto.reporterId,
      );
}
