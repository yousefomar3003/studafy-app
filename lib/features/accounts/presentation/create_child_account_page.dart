import 'package:flutter/material.dart';

import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/device_account.dart';

/// A parent creates a student account for a child who has no email or phone.
///
/// The parent accepts the terms for the child here, explicitly: the box has
/// to be ticked, and the server records it against the published policy.
class CreateChildAccountPage extends StatefulWidget {
  const CreateChildAccountPage({
    super.key,
    required this.create,
    required this.onSwitch,
  });

  /// Creates the account; throws [ManagedChildException] when refused.
  final Future<ManagedChild> Function(String displayName) create;

  /// Switches to the new account. The page is closed first.
  final void Function(ManagedChild child) onSwitch;

  @override
  State<CreateChildAccountPage> createState() => _CreateChildAccountPageState();
}

class _CreateChildAccountPageState extends State<CreateChildAccountPage> {
  final _name = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _error;
  ManagedChild? _created;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _consent && _name.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    if (!_ready) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final child = await widget.create(_name.text.trim());
      if (mounted) setState(() => _created = child);
    } on ManagedChildException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.refusal) {
            ManagedChildRefusal.limitReached => l10n.childAccountLimit,
            ManagedChildRefusal.unavailable => l10n.childAccountUnavailable,
            ManagedChildRefusal.failed => l10n.childAccountFailed,
          },
        );
      }
    } on Object {
      if (mounted) setState(() => _error = l10n.childAccountFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final created = _created;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.childAccountTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: created != null
              ? [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: UserContentText(
                      l10n.childAccountCreated(created.displayName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.childAccountNextStep, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSwitch(created);
                    },
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(l10n.childAccountOpenNow(created.displayName)),
                  ),
                ]
              : [
                  Text(l10n.childAccountIntro),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.childAccountName,
                      helperText: l10n.childAccountNameHelp,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _consent = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.childAccountConsent),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _ready ? _submit : null,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.childAccountCreate),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
        ),
      ),
    );
  }
}
