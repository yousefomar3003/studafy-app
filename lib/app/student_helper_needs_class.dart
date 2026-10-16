import 'package:flutter/material.dart';

import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../l10n/generated/app_l10n.dart';

/// The helper tab for a student who is in no class yet, while the AI study
/// tools are on.
///
/// The tools are for students in a class (ADR-0043) and the server refuses
/// them until then; the tab stays so the student learns what it is for and
/// how to get it, instead of it appearing only later.
class StudentHelperNeedsClass extends StatelessWidget {
  const StudentHelperNeedsClass({super.key, this.onJoin});

  /// Opens joining a class; null where this build cannot join one.
  final Future<void> Function()? onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final join = onJoin;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FeatureCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const IconBadge(icon: Icons.auto_awesome_rounded, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    l10n.studyHelperNeedsClassTitle,
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
                    l10n.studyHelperNeedsClassBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: studafyMuted, height: 1.45),
                  ),
                  if (join != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: join,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.group_add_rounded),
                        label: Text(l10n.joinClassAction),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
