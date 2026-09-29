import 'package:flutter/material.dart';

import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'study_plan_copy.dart';

/// Offers a pause before a cancellation, where the store has one, and says
/// what each does to access and billing.
///
/// The App Store and Google Play do not let an app pause or cancel for the
/// subscriber, so both choices open the store's own subscriptions page; the
/// subscription stays exactly as it is until the subscriber confirms there.
Future<void> showCancelSubscriptionSheet(
  BuildContext context, {
  required StudyPlanSubscription subscription,
  required Uri manageUri,
  required Future<void> Function(Uri uri) openStore,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => CancelSubscriptionSheet(
    subscription: subscription,
    onOpenStore: () async {
      Navigator.of(sheet).pop();
      await openStore(manageUri);
    },
  ),
);

class CancelSubscriptionSheet extends StatelessWidget {
  const CancelSubscriptionSheet({
    super.key,
    required this.subscription,
    required this.onOpenStore,
  });

  final StudyPlanSubscription subscription;
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final plan = studyPlanCopy[subscription.tier]!.name;
    final ends = subscription.endsAt;
    final date = ends == null
        ? l10n.studyPlansEndOfPeriod
        : studafyShortDate(context, ends.toLocal());
    final store = subscription.store ?? SubscriptionStore.appStore;
    final canPause =
        store.canPause && subscription.renewal != RenewalStatus.paused;

    Widget option({
      required String title,
      required String body,
      required Widget action,
    }) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cancelSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            if (canPause)
              option(
                title: l10n.cancelPauseTitle,
                body: l10n.cancelPauseBody(plan, date),
                action: FilledButton.icon(
                  onPressed: onOpenStore,
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: Text(l10n.cancelPauseButton),
                ),
              ),
            option(
              title: l10n.studyPlansCancelSubscription,
              body: l10n.cancelCancelBody(plan, date),
              action: canPause
                  ? OutlinedButton(
                      onPressed: onOpenStore,
                      child: Text(l10n.cancelInStore(storeName(store))),
                    )
                  : FilledButton(
                      onPressed: onOpenStore,
                      child: Text(l10n.cancelInStore(storeName(store))),
                    ),
            ),
            Text(
              l10n.cancelStoreNote(storeName(store)),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelKeepPlan),
            ),
          ],
        ),
      ),
    );
  }
}
