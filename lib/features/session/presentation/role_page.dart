import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../application/session_interactor.dart';
import 'login_page.dart';

/// Role chosen on the welcome screen; maps onto [StudafyRole] at login.
enum UserRole { teacher, student, parent }

class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class RolePage extends StatefulWidget {
  const RolePage({super.key, required this.session});
  final SessionInteractor session;
  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  UserRole? selected;
  @override
  Widget build(BuildContext c) => AuthFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudafyLogo(size: 36),
        const SizedBox(height: 44),
        Text(
          'How will you use Studafy?',
          style: Theme.of(c).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose your role to personalize your experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: studafyMuted),
        ),
        const SizedBox(height: 32),
        ...UserRole.values.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RoleTile(
              role: r,
              selected: selected == r,
              onTap: () => setState(() => selected = r),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: selected == null
              ? null
              : () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginPage(role: selected!, session: widget.session),
                  ),
                ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

class RoleTile extends StatelessWidget {
  const RoleTile({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) {
    final d = switch (role) {
      UserRole.teacher => (
        Icons.school_outlined,
        'Teacher',
        'Manage classes, attendance and learning',
      ),
      UserRole.student => (
        Icons.menu_book_outlined,
        'Student',
        'Learn, submit work and stay updated',
      ),
      UserRole.parent => (
        Icons.family_restroom_outlined,
        'Parent',
        'Follow progress and school updates',
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0EFFF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? studafyNavy : const Color(0xFFDCE0EE),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? studafyNavy : studafyCanvas,
              child: Icon(d.$1, color: selected ? Colors.white : studafyNavy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: studafyInk,
                    ),
                  ),
                  Text(
                    d.$3,
                    style: const TextStyle(color: studafyMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? studafyNavy : studafyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
