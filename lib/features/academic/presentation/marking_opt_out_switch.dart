import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/feedback.dart';
import '../../../core/studafy_components.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/marking.dart';

/// A student's choice about suggested marks (ADR-0046), on their account.
///
/// On by default. Off, their work is never sent to the AI: their teachers
/// mark it by hand, as they always could. Only a student has it; the
/// server refuses the choice from anyone else.
class MarkingOptOutSwitch extends StatefulWidget {
  const MarkingOptOutSwitch({super.key, required this.preference, this.wrap});

  final MarkingPreferenceRepository preference;

  /// Puts the row in its group, so the group is not shown without it.
  final Widget Function(Widget row)? wrap;

  @override
  State<MarkingOptOutSwitch> createState() => _MarkingOptOutSwitchState();
}

class _MarkingOptOutSwitchState extends State<MarkingOptOutSwitch> {
  bool? _optedOut;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final optedOut = await widget.preference.optedOut();
      if (mounted) setState(() => _optedOut = optedOut);
    } on Object {
      // Nothing to show: the switch stays away rather than guess.
    }
  }

  Future<void> _toggle(bool allowed) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppL10n.of(context).markingOptOutFailed;
    setState(() => _busy = true);
    try {
      final optedOut = await widget.preference.setOptedOut(!allowed);
      if (mounted) setState(() => _optedOut = optedOut);
    } on Object {
      messenger.showMessage(failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final optedOut = _optedOut;
    if (optedOut == null) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    final row = SettingsSwitchRow(
      icon: Icons.rate_review_outlined,
      title: l10n.markingOptOutSwitch,
      subtitle: optedOut ? l10n.markingOptOutOff : l10n.markingOptOutOn,
      switchKey: const ValueKey('marking-opt-out-switch'),
      value: !optedOut,
      onChanged: _busy ? null : _toggle,
    );
    return widget.wrap?.call(row) ?? row;
  }
}
