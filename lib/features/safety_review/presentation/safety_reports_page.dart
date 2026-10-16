import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/safety_review_interactor.dart';
import '../domain/safety_review.dart';
import 'safety_report_review_page.dart';
import 'safety_review_labels.dart';

/// The platform operator's queue of open safety reports (DL-063).
///
/// Metadata only - kind, priority, age and the report's short id, the same
/// facts as the alert. A report's content opens on the next screen, and only
/// under a grant the operator asks for there. Reached from the account
/// screen, which shows the entry only when the server marks the account as
/// a platform operator.
class SafetyReportsPage extends StatefulWidget {
  const SafetyReportsPage({
    super.key,
    required this.review,
    required this.onOpenSecurity,
    this.now = DateTime.now,
  });

  final SafetyReviewInteractor review;

  /// Opens Account -> Security, where an authenticator is set up. Composed
  /// by the app layer, which owns that screen.
  final Future<void> Function(BuildContext context) onOpenSecurity;

  /// The clock the ages are measured against; fixed in tests.
  final DateTime Function() now;

  @override
  State<SafetyReportsPage> createState() => _SafetyReportsPageState();
}

class _SafetyReportsPageState extends State<SafetyReportsPage> {
  SafetyReviewQueue? _queue;
  SafetyReviewError? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _queue == null;
      _error = null;
    });
    try {
      final queue = await widget.review.queue();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _loading = false;
      });
    } on SafetyReviewException catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.error;
        _loading = false;
      });
    }
  }

  Future<void> _open(SafetyReviewSummary report) async {
    final queue = _queue;
    if (queue == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final recorded = AppL10n.of(context).safetyReviewRecorded;
    final decided = await Navigator.of(context).pushOnce<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SafetyReportReviewPage(
          review: widget.review,
          report: report,
          singleReviewer: queue.singleReviewer,
          onOpenSecurity: widget.onOpenSecurity,
        ),
      ),
    );
    if (!mounted) return;
    if (decided == true) messenger.showMessage(recorded);
    // Whatever happened there - a grant started, a decision recorded - the
    // queue is read again.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final queue = _queue;
    final error = _error;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(title: Text(l10n.safetyReviewTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 40),
                children: [
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: StudafyEmptyState(
                        icon: error == SafetyReviewError.notOperator
                            ? Icons.lock_outline_rounded
                            : Icons.wifi_off_rounded,
                        title: error == SafetyReviewError.notOperator
                            ? l10n.safetyReviewNotOperator
                            : l10n.safetyReviewLoadFailed,
                        message: error == SafetyReviewError.notOperator
                            ? null
                            : l10n.safetyReviewUnavailable,
                        actionLabel: l10n.safetyReviewTryAgain,
                        onAction: _load,
                      ),
                    )
                  else if (queue != null) ...[
                    if (!queue.singleReviewer)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 12),
                        child: _Notice(
                          text: l10n.safetyReviewSecondApproverBanner,
                        ),
                      ),
                    if (queue.reports.isEmpty)
                      StudafyEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: l10n.safetyReviewEmptyTitle,
                        message: l10n.safetyReviewEmptyBody,
                      )
                    else
                      SettingsGroup(
                        footer: l10n.safetyReviewListFooter,
                        children: [
                          for (final report in queue.reports)
                            _ReportRow(
                              report: report,
                              now: widget.now(),
                              onTap: () => _open(report),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// One report in the queue, read out as one sentence.
class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.now,
    required this.onTap,
  });

  final SafetyReviewSummary report;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final kind = safetyKindLabel(l10n, report.kind);
    final priority = safetyPriorityLabel(l10n, report.priority);
    final age = safetyFiledAgo(l10n, report.filedAt, now);
    final id = l10n.safetyReviewReportId(report.shortId);
    final status = safetyStatusLabel(l10n, report.status);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
              child: Row(
                children: [
                  IconBadge(
                    icon: safetyKindIcon(report.kind),
                    color: safetyPriorityColor(report.priority),
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind,
                          style: const TextStyle(
                            color: studafyInk,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$id · $age · $status',
                          style: const TextStyle(
                            color: studafyMuted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            StatusPill(
                              label: priority,
                              icon: safetyPriorityIcon(report.priority),
                              color: safetyPriorityColor(report.priority),
                            ),
                            if (report.grantActive)
                              StatusPill(
                                label: l10n.safetyReviewAccessOpen,
                                icon: Icons.lock_open_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(forwardChevron(context), color: studafyMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain notice above the list, read out when it appears.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: studafyWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: studafyHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: studafyNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: studafyInk, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}
