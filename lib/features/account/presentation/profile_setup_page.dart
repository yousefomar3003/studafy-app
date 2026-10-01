import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/profile_setup.dart';

/// First sign-in: the name to be known by, and gender - asked once.
///
/// The name offered is whatever the sign-in produced, often the start of an
/// email address, for the person to correct. Gender always has "prefer not to
/// say", and is shown to nobody but the person themselves.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.repository,
    required this.suggestedName,
    required this.onDone,
  });

  final ProfileSetupRepository repository;
  final String suggestedName;

  /// Called with the saved profile once setup is finished.
  final void Function(ProfileSetup saved) onDone;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final _name = TextEditingController(text: widget.suggestedName);
  Gender? _gender;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppL10n.of(context);
    final name = _name.text.trim();
    final gender = _gender;
    final problem = name.isEmpty
        ? l10n.setupNameRequired
        : gender == null
        ? l10n.setupGenderRequired
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.completeSetup(
        displayName: name,
        gender: gender!,
      );
      if (mounted) widget.onDone(saved);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.setupFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Center(child: StudafyLogo(size: 48)),
                const SizedBox(height: 20),
                Text(
                  l10n.setupTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.setupIntro,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.setupNameLabel,
                    helperText: l10n.setupNameHelp,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.setupGenderLabel, style: theme.textTheme.titleSmall),
                Text(l10n.setupGenderPrivate, style: theme.textTheme.bodySmall),
                RadioGroup<Gender>(
                  groupValue: _gender,
                  onChanged: (value) {
                    if (!_saving) setState(() => _gender = value);
                  },
                  child: Column(
                    children: [
                      for (final (gender, label) in [
                        (Gender.male, l10n.setupGenderMale),
                        (Gender.female, l10n.setupGenderFemale),
                        (Gender.preferNotToSay, l10n.setupGenderPreferNot),
                      ])
                        RadioListTile<Gender>(
                          value: gender,
                          title: Text(label),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? l10n.setupSaving : l10n.setupContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
