import 'dart:async';

import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/studafy_domain.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/presentation/join_class_page.dart';
import '../features/session/application/session_interactor.dart';
import 'class_join_link_guard.dart';

/// Opens the join screen when a tapped class link is waiting.
///
/// The link can land before a navigator exists — a cold start from a tap is
/// the normal case — so the token is held by [ClassJoinLinkGuard] and read
/// here once there is somewhere to show it.
class ClassJoinLinkListener extends StatefulWidget {
  const ClassJoinLinkListener({
    super.key,
    required this.guard,
    required this.classes,
    required this.session,
    required this.navigatorKey,
    required this.child,
  });

  final ClassJoinLinkGuard guard;
  final ClassListInteractor classes;
  final SessionInteractor session;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ClassJoinLinkListener> createState() => _ClassJoinLinkListenerState();
}

class _ClassJoinLinkListenerState extends State<ClassJoinLinkListener> {
  bool _opening = false;
  StreamSubscription<SessionStatus>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    widget.guard.pendingToken.addListener(_open);
    // Tapping a class link is, for many students, the first thing they ever
    // do with Studafy: they are handed a link and have no account yet. The
    // token is therefore held until they are signed in, and the join is
    // attempted then, rather than being spent on a request that would be
    // refused and losing the link with it.
    _sessionSubscription = widget.session.statusChanges.listen((_) => _open());
    // A cold start from a tapped link has already published its token by the
    // time this mounts, so the listener alone would never fire for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    widget.guard.pendingToken.removeListener(_open);
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening || widget.guard.pendingToken.value == null) return;
    // `onboarding` counts as signed in here, and has to: a student who taps a
    // link with a brand-new account has no membership yet, which is exactly
    // the state the link exists to resolve. Requiring `authenticated` would
    // deadlock the one person this whole flow was written for.
    const usable = {SessionStatus.authenticated, SessionStatus.onboarding};
    if (!usable.contains(widget.session.status)) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    final token = widget.guard.consume();
    if (token == null) return;
    _opening = true;
    // The app's language now, for the profile read after the join.
    final locale =
        Localizations.maybeLocaleOf(navigator.context)?.languageCode ?? 'en';
    try {
      final joined = await navigator.pushOnce<Object?>(
        MaterialPageRoute<Object?>(
          builder: (_) =>
              JoinClassPage(classes: widget.classes, initialToken: token),
        ),
      );
      if (joined == null) return;
      // The server made the membership; reading the profile again is how
      // the open student app learns of it and shows the class (ADR-0045).
      // Only a student account can join, so it is the student role.
      await widget.session.completeRemoteLogin(
        role: StudafyRole.student,
        consentAccepted: false,
        locale: locale,
      );
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
