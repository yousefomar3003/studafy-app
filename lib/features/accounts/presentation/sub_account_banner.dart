import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';

/// Across the top of every screen while a parent is in a child's account,
/// so it is never mistaken for their own - and one tap takes them back.
class SubAccountBanner extends StatelessWidget {
  const SubAccountBanner({
    super.key,
    required this.parentName,
    required this.onSwitch,
  });

  final String? parentName;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = parentName;
    // A quiet line in the page's own colour (owner, 2026-11-02: the cyan
    // bar took too much of the screen), not a coloured bar: still on every
    // screen, still one tap back to the parent.
    return Material(
      color: studafyCanvas,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: studafyHairline)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
            child: Row(
              children: [
                const Icon(
                  Icons.supervisor_account_rounded,
                  size: 15,
                  color: studafyMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name == null || name.isEmpty
                        ? l10n.accountsSubAccount
                        : l10n.accountsSubAccountOf(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: studafyMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSwitch,
                  style: TextButton.styleFrom(
                    foregroundColor: studafyNavy,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(48, 32),
                  ),
                  child: Text(l10n.accountsSwitch),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
