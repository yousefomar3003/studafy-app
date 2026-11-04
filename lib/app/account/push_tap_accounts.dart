import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/accounts/domain/device_account.dart';
import '../../features/notifications/domain/notification_taps.dart';
import '../ai_consent_binding.dart';
import '../app_dependencies.dart';
import 'account_switching.dart';
import 'device_account_switcher.dart';

/// A tapped push for an account on this phone that is not the current one
/// (DL-082): switch to that account, and leave the tap for its shell, which
/// opens it as that account. A tap for an account that is no longer on the
/// phone is ignored - nothing opens, and nobody else's notification is shown.
///
/// [switchTo] makes the account current and opens its home; on failure the
/// account that was current stays, and the tap is dropped so it is not
/// tried again and again.
Future<void> openTapForAccount(
  NotificationTap tap, {
  required NotificationTaps taps,
  required DeviceAccountSwitcher switcher,
  required Future<void> Function(DeviceAccount account) switchTo,
}) async {
  final recipient = tap.recipientId;
  if (recipient == null) return;
  await switcher.ready;
  final account = switcher.accounts
      .where((candidate) => candidate.userId == recipient)
      .firstOrNull;
  if (account == null) return;
  // Waiting for the incoming shell, which opens it as the recipient.
  taps.defer(tap);
  if (switcher.switching) return;
  try {
    await switchTo(account);
  } on Object {
    // Handled below like any switch that did not land.
  }
  if (switcher.context.profile?.id != recipient &&
      identical(taps.pending, tap)) {
    taps.consume();
  }
}

/// Everything that opens over whatever screen [navigatorKey] shows, outside
/// any one screen: the AI notice (ADR-0043), and the account switch for a
/// tapped push meant for another account on the phone.
void attachNavigatorBindings(
  AppDependencies deps,
  GlobalKey<NavigatorState> navigatorKey,
) {
  attachAiConsentGate(deps.aiConsent, navigatorKey);
  attachPushTapAccounts(
    taps: deps.notifications.taps,
    switcher: deps.deviceAccounts,
    navigatorKey: navigatorKey,
  );
}

/// Lets taps for the phone's other accounts switch to them, through the
/// app's own account switch (its progress dialog and failure messages).
void attachPushTapAccounts({
  required NotificationTaps? taps,
  required DeviceAccountSwitcher? switcher,
  required GlobalKey<NavigatorState> navigatorKey,
}) {
  if (taps == null || switcher == null) return;
  taps.anotherAccount = (tap) => openTapForAccount(
    tap,
    taps: taps,
    switcher: switcher,
    switchTo: (account) async {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      await switchAccount(context, switcher, account);
    },
  );
}
