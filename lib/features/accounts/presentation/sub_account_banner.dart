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
    return Material(
      color: studafyCyan,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 4, 2),
          child: Row(
            children: [
              const Icon(
                Icons.supervisor_account_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name == null || name.isEmpty
                      ? l10n.accountsSubAccount
                      : l10n.accountsSubAccountOf(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSwitch,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(l10n.accountsSwitch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
