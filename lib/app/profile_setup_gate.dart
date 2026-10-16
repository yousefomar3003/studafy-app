import 'package:flutter/material.dart';

import '../core/studafy_domain.dart';
import '../features/account/domain/profile_setup.dart';
import '../features/account/presentation/profile_setup_page.dart';

/// Stands in front of every role's home until the signed-in person has
/// chosen their name and answered gender - once, at first sign-in.
///
/// Anything that stops the profile being read - offline, an older server -
/// lets them through: setup is a courtesy, never a lock.
class ProfileSetupGate extends StatefulWidget {
  const ProfileSetupGate({
    super.key,
    required this.repository,
    required this.child,
    this.activeContext,
  });

  final ProfileSetupRepository? repository;
  final Widget child;

  /// Tests supply their own; the app uses the shared controller.
  final ActiveContextController? activeContext;

  @override
  State<ProfileSetupGate> createState() => _ProfileSetupGateState();
}

class _ProfileSetupGateState extends State<ProfileSetupGate> {
  /// Accounts already known to be set up, across rebuilds and switches.
  static final Set<String> _settled = {};

  ActiveContextController get _context =>
      widget.activeContext ?? ActiveContextController.instance;

  ProfileSetup? _pending;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final repository = widget.repository;
    final userId = _context.profile?.id;
    if (repository == null || userId == null || _settled.contains(userId)) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    ProfileSetup? setup;
    try {
      setup = await repository.readSetup();
    } on Object {
      setup = null;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (setup == null || setup.complete) {
        _settled.add(userId);
      } else {
        _pending = setup;
      }
    });
  }

  void _finished(ProfileSetup saved) {
    final profile = _context.profile;
    if (profile != null) {
      _settled.add(profile.id);
      // The chosen name, everywhere at once: headers, the account screen and
      // the list of accounts on the device all read it from here.
      _context.hydrate(
        authenticatedProfile: UserProfile(
          id: profile.id,
          displayName: saved.displayName,
          email: profile.email,
          memberships: profile.memberships,
          accountKind: profile.accountKind,
          platformOperator: profile.platformOperator,
        ),
        activeMembership: _context.membership,
        student: _context.selectedStudent,
        termId: _context.activeTermId,
        signedInAs: _context.signedInAs,
      );
    }
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pending = _pending;
    final repository = widget.repository;
    if (pending != null && repository != null) {
      return ProfileSetupPage(
        repository: repository,
        suggestedName: pending.displayName,
        onDone: _finished,
      );
    }
    return widget.child;
  }
}
