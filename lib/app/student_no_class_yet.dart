import 'package:flutter/material.dart';

import '../core/device_settings.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_domain.dart';
import '../l10n/generated/app_l10n.dart';

/// The join-a-class step a new student sees once, right after signing up.
///
/// Joining is optional (ADR-0045): "Skip for now" opens the app, where the
/// AI Tutor and the Notebook work without a class, and a class can be
/// joined later from Today. The step is not shown again on this device.
class StudentNoClassYet extends StatelessWidget {
  const StudentNoClassYet({
    super.key,
    required this.onJoin,
    required this.actions,
    this.onSkip,
  });

  final Future<void> Function() onJoin;
  final List<Widget> actions;

  /// Goes on without a class. Null hides the choice.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 4),
          child: Row(
            children: [const StudafyLogo(size: 26), const Spacer(), ...actions],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FeatureCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const IconBadge(icon: Icons.group_add_rounded, size: 72),
                      const SizedBox(height: 20),
                      Text(
                        l10n.onboardingStudentTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.onboardingStudentBody,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: studafyMuted,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onJoin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.group_add_rounded),
                          label: Text(l10n.joinClassAction),
                        ),
                      ),
                      if (onSkip != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: onSkip,
                            style: TextButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: Text(l10n.onboardingStudentSkip),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.onboardingStudentOptional,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: studafyMuted,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether the join-a-class step after sign-up has been passed - a class
/// joined, or "Skip for now" - on this device, for the account signed in
/// (ADR-0045). Joining is optional, so the step is shown once, not at every
/// launch. With no [settings] it is remembered for this run only.
class StudentClassStep {
  StudentClassStep(this.settings);

  final DeviceSettingsStore? settings;
  bool done = false;

  /// Whether this device has been asked yet; until then nothing is shown,
  /// so a student who skipped does not see the step flash at every launch.
  bool known = false;

  String? get _key => switch (ActiveContextController.instance.profile?.id) {
    final id? => DeviceSettingKeys.studentClassStepDone(id),
    null => null,
  };

  Future<void> read() async {
    final store = settings;
    final key = _key;
    try {
      if (store != null && key != null && await store.read(key) != null) {
        done = true;
      }
    } on Object {
      // Unread, the step shows; skipping it again costs one tap.
    } finally {
      known = true;
    }
  }

  Future<void> pass() async {
    done = true;
    known = true;
    final store = settings;
    final key = _key;
    if (store == null || key == null) return;
    try {
      await store.write(key, '1');
    } on Object {
      // Remembered for this run; at worst the step is offered once more.
    }
  }
}
