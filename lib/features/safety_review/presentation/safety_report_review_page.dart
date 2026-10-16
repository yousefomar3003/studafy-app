import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/safety_review_interactor.dart';
import '../domain/safety_review.dart';
import 'safety_review_labels.dart';

/// Where the review of one report stands.
enum _Step {
  /// Asking the server (opening the report, or getting access).
  working,

  /// Why the operator is opening it; recorded with the grant.
  reason,

  /// The authenticator code that steps the session up to AAL2.
  code,

  /// No authenticator yet: set one up in Account -> Security first.
  notEnrolled,

  /// The report, and the decision.
  report,

  /// A step did not go through; [_error] says which.
  failed,
}

/// Opens one safety report for review and records the decision (DL-063).
///
/// Without an active grant it asks why, then for the authenticator code,
/// then requests a 60-minute grant scoped to this report, approves it
/// (single-reviewer mode) and starts it - all on the server, all audited.
/// Pops with true once a decision is recorded.
class SafetyReportReviewPage extends StatefulWidget {
  const SafetyReportReviewPage({
    super.key,
    required this.review,
    required this.report,
    required this.singleReviewer,
    required this.onOpenSecurity,
  });

  final SafetyReviewInteractor review;
  final SafetyReviewSummary report;

  /// Whether this operator may approve their own grant (the queue says).
  final bool singleReviewer;
  final Future<void> Function(BuildContext context) onOpenSecurity;

  @override
  State<SafetyReportReviewPage> createState() => _SafetyReportReviewPageState();
}

class _SafetyReportReviewPageState extends State<SafetyReportReviewPage> {
  final _reason = TextEditingController();
  final _code = TextEditingController();
  final _note = TextEditingController();

  _Step _step = _Step.working;
  SafetyReviewError? _error;
  SafetyReviewReport? _opened;

  /// A grant already covers the report: the code only steps the session up.
  bool _granted = false;
  String? _reasonError;
  String? _codeError;
  String? _noteError;
  SafetyReviewOutcome? _outcome;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _granted = widget.report.grantActive;
    _start();
  }

  @override
  void dispose() {
    _reason.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  void _show(_Step step, {SafetyReviewError? error}) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _error = error;
    });
  }

  /// Opens the report when a grant covers it; otherwise starts asking for
  /// one - or says plainly that someone else has to approve it.
  void _start() {
    if (_granted) {
      _openReport();
    } else if (!widget.singleReviewer) {
      _show(_Step.failed, error: SafetyReviewError.secondApproverRequired);
    } else {
      _show(_Step.reason);
    }
  }

  Future<void> _openReport() async {
    _show(_Step.working);
    try {
      final report = await widget.review.open(widget.report.id);
      if (!mounted) return;
      setState(() {
        _opened = report;
        _step = _Step.report;
        _error = null;
      });
    } on SafetyReviewException catch (failure) {
      switch (failure.error) {
        case SafetyReviewError.stepUpRequired:
          _show(_Step.code);
        case SafetyReviewError.noGrant:
          _granted = false;
          _show(_Step.failed, error: SafetyReviewError.noGrant);
        default:
          _show(_Step.failed, error: failure.error);
      }
    }
  }

  Future<void> _submitReason() async {
    final l10n = AppL10n.of(context);
    if (!SafetyReviewInteractor.validText(_reason.text)) {
      setState(() => _reasonError = l10n.safetyReviewTextTooShort);
      return;
    }
    setState(() => _reasonError = null);
    await _checkEnrolment();
  }

  /// The code step needs an authenticator; without one, say where to set
  /// it up rather than asking for a code that cannot exist.
  Future<void> _checkEnrolment() async {
    _show(_Step.working);
    try {
      final enrolled = await widget.review.secondFactorEnrolled();
      _show(enrolled ? _Step.code : _Step.notEnrolled);
    } on SafetyReviewException catch (failure) {
      _show(_Step.failed, error: failure.error);
    }
  }

  Future<void> _submitCode() async {
    final l10n = AppL10n.of(context);
    if (!SafetyReviewInteractor.validCode(_code.text)) {
      setState(() => _codeError = l10n.safetyReviewCodeDigits);
      return;
    }
    final code = _code.text.trim();
    setState(() => _codeError = null);
    _show(_Step.working);
    try {
      final report = _granted
          ? await widget.review.stepUpAndOpen(
              reportId: widget.report.id,
              code: code,
            )
          : await widget.review.unlock(
              report: widget.report,
              reason: _reason.text,
              code: code,
            );
      if (!mounted) return;
      _code.clear();
      setState(() {
        _granted = true;
        _opened = report;
        _step = _Step.report;
        _error = null;
      });
    } on SafetyReviewException catch (failure) {
      if (!mounted) return;
      _code.clear();
      switch (failure.error) {
        case SafetyReviewError.wrongCode:
          setState(() {
            _codeError = l10n.safetyReviewWrongCode;
            _step = _Step.code;
          });
        case SafetyReviewError.notEnrolled:
          _show(_Step.notEnrolled);
        default:
          _show(_Step.failed, error: failure.error);
      }
    }
  }

  Future<void> _openSecurity() async {
    await widget.onOpenSecurity(context);
    if (!mounted) return;
    // Back from Account -> Security: carry on if an authenticator is set up.
    await _checkEnrolment();
  }

  Future<void> _record() async {
    final l10n = AppL10n.of(context);
    final report = _opened;
    final outcome = _outcome;
    if (report == null || outcome == null) return;
    if (!SafetyReviewInteractor.validText(_note.text)) {
      setState(() => _noteError = l10n.safetyReviewTextTooShort);
      return;
    }
    setState(() => _noteError = null);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.safetyReviewConfirmTitle),
        content: Text(
          l10n.safetyReviewConfirmBody(safetyOutcomeLabel(l10n, outcome)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.safetyReviewCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.safetyReviewRecord),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.review.resolve(
        report: report,
        outcome: outcome,
        note: _note.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on SafetyReviewException catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (failure.error == SafetyReviewError.noGrant) _granted = false;
      if (failure.error == SafetyReviewError.stepUpRequired) {
        _show(_Step.code);
        return;
      }
      _show(_Step.failed, error: failure.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(
        title: Text(l10n.safetyReviewReportId(widget.report.shortId)),
      ),
      body: SafeArea(
        child: switch (_step) {
          _Step.working => Center(
            child: Semantics(
              liveRegion: true,
              label: l10n.safetyReviewWorking,
              child: const CircularProgressIndicator(),
            ),
          ),
          _Step.reason => _reasonStep(l10n),
          _Step.code => _codeStep(l10n),
          _Step.notEnrolled => _Message(
            icon: Icons.shield_outlined,
            title: l10n.safetyReviewNotEnrolledTitle,
            body: l10n.safetyReviewNotEnrolledBody,
            actionLabel: l10n.safetyReviewOpenSecurity,
            onAction: _openSecurity,
          ),
          _Step.report => _reportView(l10n, _opened!),
          _Step.failed => _failure(l10n, _error!),
        },
      ),
    );
  }

  Widget _failure(AppL10n l10n, SafetyReviewError error) {
    final text = safetyErrorText(l10n, error);
    return switch (error) {
      SafetyReviewError.noGrant => _Message(
        icon: Icons.timer_off_outlined,
        title: text.title,
        body: text.body,
        actionLabel: widget.singleReviewer ? l10n.safetyReviewAskAgain : null,
        onAction: widget.singleReviewer ? () => _show(_Step.reason) : null,
      ),
      SafetyReviewError.secondApproverRequired => _Message(
        icon: Icons.group_outlined,
        title: text.title,
        body: text.body,
      ),
      SafetyReviewError.changed => _Message(
        icon: Icons.sync_problem_rounded,
        title: text.title,
        body: text.body,
        actionLabel: l10n.safetyReviewReload,
        onAction: _start,
      ),
      _ => _Message(
        icon: Icons.wifi_off_rounded,
        title: text.title,
        body: text.body,
        actionLabel: l10n.safetyReviewTryAgain,
        onAction: _start,
      ),
    };
  }

  Widget _reasonStep(AppL10n l10n) => ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 40),
    children: [
      _Header(
        kind: widget.report.kind,
        priority: widget.report.priority,
        status: widget.report.status,
      ),
      const SizedBox(height: 20),
      Semantics(
        header: true,
        child: Text(
          l10n.safetyReviewReasonTitle,
          style: const TextStyle(
            color: studafyInk,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.safetyReviewReasonBody,
        style: const TextStyle(color: studafyInk, height: 1.4),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _reason,
        minLines: 2,
        maxLines: 5,
        maxLength: SafetyReviewInteractor.maxText,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.safetyReviewReasonLabel,
          hintText: l10n.safetyReviewReasonHint,
          errorText: _reasonError,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _submitReason,
        child: Text(l10n.safetyReviewContinue),
      ),
    ],
  );

  Widget _codeStep(AppL10n l10n) => ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 40),
    children: [
      const Icon(Icons.verified_user_outlined, color: studafyNavy, size: 40),
      const SizedBox(height: 12),
      Semantics(
        header: true,
        child: Text(
          l10n.safetyReviewCodeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: studafyInk,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        l10n.safetyReviewCodeBody,
        textAlign: TextAlign.center,
        style: const TextStyle(color: studafyInk, height: 1.4),
      ),
      const SizedBox(height: 20),
      // Digits read left to right in both languages.
      Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 6),
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _submitCode(),
          decoration: InputDecoration(
            labelText: l10n.safetyReviewCodeLabel,
            errorText: _codeError,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _submitCode,
        child: Text(l10n.safetyReviewOpenReport),
      ),
    ],
  );

  Widget _reportView(AppL10n l10n, SafetyReviewReport report) => ListView(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 40),
    children: [
      _Header(
        kind: report.kind,
        priority: report.priority,
        status: report.status,
        filedAt: report.filedAt,
      ),
      if (report.reporterId == null)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 12),
          child: Text(
            l10n.safetyReviewReporterMasked,
            style: const TextStyle(color: studafyMuted, fontSize: 13),
          ),
        ),
      _Section(
        title: l10n.safetyReviewDetailsHeading,
        child: UserContentText(
          report.details,
          style: const TextStyle(color: studafyInk, height: 1.45),
        ),
      ),
      _Section(
        title: l10n.safetyReviewSnapshotHeading,
        child: report.snapshot.isEmpty
            ? Text(
                l10n.safetyReviewNothingCaptured,
                style: const TextStyle(color: studafyMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in report.snapshot.entries)
                    _Field(
                      label: safetySnapshotLabel(l10n, entry.key),
                      value: entry.value,
                    ),
                ],
              ),
      ),
      _Section(
        title: l10n.safetyReviewEvidenceHeading,
        child: report.evidence.isEmpty
            ? Text(
                l10n.safetyReviewNoEvidence,
                style: const TextStyle(color: studafyMuted),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in report.evidence)
                    _Field(
                      label:
                          '${safetyEvidenceLabel(l10n, item.kind)} · '
                          '${studafyDateTime(context, item.addedAt)}',
                      value:
                          item.note ??
                          item.messageId ??
                          item.attachmentFileId ??
                          '',
                    ),
                ],
              ),
      ),
      if (report.events.isNotEmpty)
        _Section(
          title: l10n.safetyReviewHistoryHeading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final event in report.events)
                _Field(
                  label:
                      '${safetyEventLabel(l10n, event.event)} · '
                      '${studafyDateTime(context, event.at)}',
                  value: [
                    if (event.resolution != null)
                      safetyResolutionLabel(l10n, event.resolution!),
                    ?event.note,
                  ].join(' · '),
                ),
            ],
          ),
        ),
      if (report.resolved && report.resolution != null)
        _Section(
          title: l10n.safetyReviewDecisionHeading,
          child: Text(
            l10n.safetyReviewResolvedAs(
              safetyResolutionLabel(l10n, report.resolution!),
            ),
            style: const TextStyle(color: studafyInk),
          ),
        )
      else if (!report.decidable)
        _Section(
          title: l10n.safetyReviewDecisionHeading,
          child: Text(
            l10n.safetyReviewNotDecidable,
            style: const TextStyle(color: studafyInk, height: 1.4),
          ),
        )
      else
        _decision(l10n),
    ],
  );

  Widget _decision(AppL10n l10n) => _Section(
    title: l10n.safetyReviewDecisionHeading,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<SafetyReviewOutcome>(
          groupValue: _outcome,
          onChanged: (value) {
            if (_saving) return;
            setState(() => _outcome = value);
          },
          child: Column(
            children: [
              for (final outcome in SafetyReviewOutcome.values)
                RadioListTile<SafetyReviewOutcome>(
                  value: outcome,
                  contentPadding: EdgeInsets.zero,
                  title: Text(safetyOutcomeLabel(l10n, outcome)),
                  subtitle: Text(safetyOutcomeDetail(l10n, outcome)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          enabled: !_saving,
          minLines: 2,
          maxLines: 6,
          maxLength: SafetyReviewInteractor.maxText,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.safetyReviewNoteLabel,
            hintText: l10n.safetyReviewNoteHint,
            hintMaxLines: 3,
            errorText: _noteError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _outcome == null || _saving ? null : _record,
          child: _saving
              ? Semantics(
                  label: l10n.safetyReviewRecord,
                  child: const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Text(l10n.safetyReviewRecord),
        ),
      ],
    ),
  );
}

/// The report's kind, priority and status, in words.
class _Header extends StatelessWidget {
  const _Header({
    required this.kind,
    required this.priority,
    required this.status,
    this.filedAt,
  });

  final SafetyReviewKind kind;
  final SafetyReviewPriority priority;
  final String status;
  final DateTime? filedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final filed = filedAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(
          icon: safetyKindIcon(kind),
          color: safetyPriorityColor(priority),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  safetyKindLabel(l10n, kind),
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (filed != null) ...[
                const SizedBox(height: 2),
                Text(
                  studafyDateTime(context, filed),
                  style: const TextStyle(color: studafyMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  StatusPill(
                    label: safetyPriorityLabel(l10n, priority),
                    icon: safetyPriorityIcon(priority),
                    color: safetyPriorityColor(priority),
                  ),
                  StatusPill(
                    label: safetyStatusLabel(l10n, status),
                    icon: Icons.flag_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled card on the report.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        FeatureCard(padding: const EdgeInsets.all(16), child: child),
      ],
    ),
  );
}

/// One captured field: what it is, then the value as it was written.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: studafyMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 2),
          UserContentText(
            value,
            style: const TextStyle(color: studafyInk, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

/// A state with a title, an explanation and at most one way forward.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: StudafyEmptyState(
      icon: icon,
      title: title,
      message: body,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
