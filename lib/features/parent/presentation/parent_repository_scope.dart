import 'package:flutter/widgets.dart';

import '../domain/parent_repository.dart';
import '../domain/parent_subscription_repository.dart';

typedef SignOutCallback = Future<void> Function();

/// Injects the parent port above the app Navigator, including pushed routes.
class ParentRepositoryScope extends InheritedWidget {
  const ParentRepositoryScope({
    super.key,
    required this.repository,
    required this.subscription,
    required this.signOut,
    required this.isRemote,
    required super.child,
  });

  final ParentRepository repository;
  final ParentSubscriptionRepository subscription;
  final SignOutCallback signOut;
  final bool isRemote;

  static ParentRepositoryScope of(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<ParentRepositoryScope>();
    if (scope == null) {
      throw StateError('ParentRepositoryScope is missing.');
    }
    return scope;
  }

  static ParentRepository read(BuildContext context) => of(context).repository;

  @override
  bool updateShouldNotify(ParentRepositoryScope oldWidget) =>
      repository != oldWidget.repository ||
      subscription != oldWidget.subscription ||
      signOut != oldWidget.signOut ||
      isRemote != oldWidget.isRemote;
}
