import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_l10n.dart';
import 'ai_consent.dart';
import 'feedback.dart';
import 'studafy_components.dart';
import 'studafy_design.dart';

/// The AI notice (ADR-0043): what the AI study tools send, to whom, and what
/// they never send, in plain words. Shown before a student's first AI use,
/// and to a parent agreeing for a child account. True when they agreed and
/// the consent was recorded.
///
/// The words are `aiConsentNoticeBody` exactly: its SHA-256 in each language
/// is the published notice the server records consent against.
Future<bool> showAiConsentNotice(
  BuildContext context, {
  required AiConsentRepository repository,
  String? childId,
  String? childName,
}) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _AiConsentNotice(
      repository: repository,
      childId: childId,
      childName: childName,
    ),
  );
  return agreed ?? false;
}

/// A managed child account cannot agree for itself: says who can.
Future<void> showAiConsentGuardianNeeded(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppL10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.aiConsentTitle),
          content: Text(l10n.aiConsentGuardianNeeded),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).okButtonLabel,
              ),
            ),
          ],
        );
      },
    );

class _AiConsentNotice extends StatefulWidget {
  const _AiConsentNotice({
    required this.repository,
    this.childId,
    this.childName,
  });

  final AiConsentRepository repository;
  final String? childId;
  final String? childName;

  @override
  State<_AiConsentNotice> createState() => _AiConsentNoticeState();
}

class _AiConsentNoticeState extends State<_AiConsentNotice> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _agree() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final state = await widget.repository.give(
        locale: locale == 'ar' ? 'ar' : 'en',
        childId: widget.childId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(state.on || state.givenAt != null);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final childName = widget.childName;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.aiConsentTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (childName != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.aiConsentForChild(childName),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Text(
                l10n.aiConsentNoticeBody,
                key: const ValueKey('ai-consent-notice'),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              l10n.aiConsentSaveFailed,
              style: theme.textTheme.bodySmall?.copyWith(color: studafyDanger),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('ai-consent-agree'),
            onPressed: _saving ? null : _agree,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.aiConsentAgree),
          ),
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey('ai-consent-not-now'),
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.aiConsentNotNow),
          ),
        ],
      ),
    );
  }
}

/// The AI study tools switch: in a student's account settings, and on a
/// parent's home for each child account they manage ([childId]). Turning it
/// on shows the notice; turning it off withdraws the consent. Absent for an
/// account that cannot use the tools at all (a parent or teacher, or a
/// student with no class).
class AiConsentSwitch extends StatefulWidget {
  const AiConsentSwitch({
    super.key,
    required this.repository,
    this.childId,
    this.childName,
  });

  final AiConsentRepository repository;
  final String? childId;
  final String? childName;

  @override
  State<AiConsentSwitch> createState() => _AiConsentSwitchState();
}

class _AiConsentSwitchState extends State<AiConsentSwitch> {
  AiConsentState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final state = await widget.repository.state(childId: widget.childId);
      if (mounted) setState(() => _state = state);
    } on Object {
      // Nothing to show: the switch stays away rather than guess.
    }
  }

  Future<void> _toggle(bool on) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (on) {
        final agreed = await showAiConsentNotice(
          context,
          repository: widget.repository,
          childId: widget.childId,
          childName: widget.childName,
        );
        if (!agreed) return;
      } else {
        final sure = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.aiConsentWithdrawTitle),
            content: Text(l10n.aiConsentWithdrawBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              TextButton(
                key: const ValueKey('ai-consent-withdraw'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.aiConsentWithdrawAction),
              ),
            ],
          ),
        );
        if (sure != true) return;
        await widget.repository.withdraw(childId: widget.childId);
      }
    } on Object {
      messenger.showMessage(l10n.aiConsentSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null || !state.access.isStudentInClass) {
      return const SizedBox.shrink();
    }
    final l10n = AppL10n.of(context);
    final childName = widget.childName;
    // A child account's own switch can only turn the tools off: their
    // parent turns them on.
    final parentDecides =
        widget.childId == null &&
        state.access == AiAccess.guardianConsentRequired;
    return SettingsRow(
      icon: Icons.auto_awesome_rounded,
      title: childName == null
          ? l10n.aiConsentTitle
          : l10n.aiConsentChildSwitch(childName),
      subtitle: parentDecides
          ? l10n.aiConsentGuardianNeeded
          : state.on
          ? l10n.aiConsentSwitchOn
          : l10n.aiConsentSwitchOff,
      showChevron: false,
      trailing: Switch(
        key: ValueKey('ai-consent-switch-${widget.childId ?? 'self'}'),
        value: state.on,
        onChanged: _busy || (parentDecides && !state.on) ? null : _toggle,
      ),
    );
  }
}
