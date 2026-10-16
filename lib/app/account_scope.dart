import 'package:flutter/widgets.dart';

import '../core/studafy_domain.dart';
import '../features/account/application/account_interactor.dart';
import '../features/safety_review/application/safety_review_interactor.dart';

/// Provides the account interactor to the deletion screen (AUTH-030).
///
/// The legacy role shells have no dependency injection of their own, so this
/// mirrors the existing repository scopes rather than letting a widget build
/// its own adapter.
class AccountScope extends InheritedWidget {
  const AccountScope({
    super.key,
    required this.account,
    this.safetyReview,
    required super.child,
  });

  final AccountInteractor account;

  /// The platform operator's safety-report review, opened from the account
  /// screen (DL-063). Null in builds with no server; the account screen
  /// shows it only to an account the server marks as a platform operator.
  final SafetyReviewInteractor? safetyReview;

  static AccountInteractor of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    if (scope == null) {
      throw StateError(
        'AccountScope is missing: the account slice must be composed by the '
        'app root, never constructed inside a widget.',
      );
    }
    return scope.account;
  }

  /// The account slice, or null where none is composed (some widget tests).
  static AccountInteractor? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.account;

  /// The safety-report review, or null where none is composed.
  static SafetyReviewInteractor? safetyReviewOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.safetyReview;

  @override
  bool updateShouldNotify(AccountScope oldWidget) =>
      account != oldWidget.account || safetyReview != oldWidget.safetyReview;
}

/// The signed-in account's email address.
///
/// The legacy account screens carried hard-coded sample addresses, which would
/// have shown one person's email on another person's deletion confirmation.
/// The authenticated profile is the only correct source; [fallback] covers
/// synthetic builds, which have no authenticated profile at all.
String accountEmail(BuildContext context, {String fallback = ''}) {
  final email = ActiveContextController.instance.profile?.email;
  if (email != null && email.isNotEmpty) return email;
  return fallback;
}
