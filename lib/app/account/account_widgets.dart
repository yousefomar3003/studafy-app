import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/feedback.dart';
import '../../core/studafy_design.dart';
import '../../core/studafy_domain.dart';
import '../../features/family/presentation/family_scope.dart';
import '../../l10n/generated/app_l10n.dart';

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// A small uppercase heading that groups the settings below it.
class AccountSectionLabel extends StatelessWidget {
  const AccountSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: studafyMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );
}

/// Who you are, at the top of your own profile.
///
/// The name and email come from the sign-in provider and the school and role
/// from the server, so nothing here is editable and nothing is invented: an
/// account with no school shows no school rather than a placeholder one.
class AccountProfileHeader extends StatelessWidget {
  const AccountProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.membership,
    required this.roleLabel,
  });

  final String name;
  final String email;
  final SchoolMembership? membership;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      // Directional so the gradient runs the same way the text does.
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [studafyNavy, Color(0xFF2F2A9E)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: .18),
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (membership != null && roleLabel != null) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(icon: Icons.badge_outlined, label: roleLabel!),
              _HeaderChip(
                icon: Icons.apartment_rounded,
                label: membership!.schoolName,
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// The student's own Studafy ID.
///
/// A parent cannot ask to be linked without it, and until now the only place
/// it appeared was inside the family screen - so a student being asked for it
/// by a parent had nowhere obvious to look. Shown only to students, because
/// it identifies one and nobody else needs to read it here.
class StudafyIdCard extends StatefulWidget {
  const StudafyIdCard({super.key});

  @override
  State<StudafyIdCard> createState() => _StudafyIdCardState();
}

class _StudafyIdCardState extends State<StudafyIdCard> {
  String? _id;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    // Absent in shells that install no family scope, and in widget tests
    // that pump this page alone. The card is an extra, so it disappears
    // rather than taking the profile down with it.
    final family = FamilyScope.maybeOf(context);
    if (family == null) return;
    final result = await family.studentFamily();
    if (!mounted) return;
    setState(() {
      _id = result.fold(
        onSuccess: (family) => family.identities.firstOrNull?.studafyId,
        // A missing id is not worth an error on a profile screen; the card
        // simply does not appear.
        onFailure: (_) => null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) return const SizedBox.shrink();
    return FeatureCard(
      tint: studafyCyan,
      child: Row(
        children: [
          const Icon(Icons.qr_code_rounded, color: studafyCyan),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppL10n.of(context).accountStudafyId,
                  style: const TextStyle(
                    color: studafyInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  id,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  AppL10n.of(context).accountStudafyIdDetail,
                  style: const TextStyle(color: studafyMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppL10n.of(context).accountStudafyIdCopy,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final copied = AppL10n.of(context).accountStudafyIdCopied;
              await Clipboard.setData(ClipboardData(text: id));
              messenger.showMessage(copied);
            },
          ),
        ],
      ),
    );
  }
}
