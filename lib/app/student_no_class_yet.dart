import 'package:flutter/material.dart';

import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../l10n/generated/app_l10n.dart';

/// The student home before they are in any class.
///
/// Deliberately the whole screen rather than a banner over empty feeds: a
/// grades tab and an assignments tab that are both empty for the same reason
/// tell a new student nothing, and every one of them would have to explain
/// the same single next step.
class StudentNoClassYet extends StatelessWidget {
  const StudentNoClassYet({
    super.key,
    required this.onJoin,
    required this.actions,
  });

  final Future<void> Function() onJoin;
  final List<Widget> actions;

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
