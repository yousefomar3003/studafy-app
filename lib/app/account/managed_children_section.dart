import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ai_consent.dart';
import '../../core/ai_consent_sheet.dart';
import '../../core/studafy_design.dart';
import '../../core/user_content_text.dart';
import '../../l10n/generated/app_l10n.dart';
import 'account_switching.dart';

/// On the parent's home: the child accounts this parent created. A new
/// child has no school yet, so they are not among the linked children until
/// they join a class - which the parent does by opening their account.
class ManagedChildrenSection extends StatefulWidget {
  const ManagedChildrenSection({super.key});

  @override
  State<ManagedChildrenSection> createState() => _ManagedChildrenSectionState();
}

class _ManagedChildrenSectionState extends State<ManagedChildrenSection> {
  bool _refreshed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final switcher = DeviceAccountsScope.maybeOf(context);
    if (!_refreshed && switcher != null && switcher.canCreateChild) {
      _refreshed = true;
      unawaited(switcher.refreshManagedChildren());
    }
  }

  @override
  Widget build(BuildContext context) {
    final switcher = DeviceAccountsScope.maybeOf(context);
    final parentId = switcher?.context.profile?.id;
    if (switcher == null || parentId == null) return const SizedBox.shrink();
    final children = [
      for (final account in switcher.accounts)
        if (account.managedBy == parentId) account,
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final aiConsent = AiConsentGate.instance.repository;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.famManagedTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.famManagedHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final child in children)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.child_care_rounded,
                      color: studafyCyan,
                    ),
                    title: UserContentText(child.displayName),
                    trailing: TextButton(
                      onPressed: switcher.switching
                          ? null
                          : () => switchAccount(context, switcher, child),
                      child: Text(l10n.famManagedOpen),
                    ),
                  ),
                  // The parent agrees to the AI study tools for a child
                  // account, from their own account (ADR-0043). Shown once
                  // the child is in a class.
                  if (aiConsent != null)
                    AiConsentSwitch(
                      key: ValueKey('ai-consent-${child.userId}'),
                      repository: aiConsent,
                      childId: child.userId,
                      childName: child.displayName,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
