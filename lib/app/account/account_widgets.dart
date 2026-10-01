import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/feedback.dart';
import '../../core/profile_photo.dart';
import '../../core/studafy_components.dart';
import '../../core/studafy_design.dart';
import '../../core/studafy_domain.dart';
import '../../features/family/presentation/family_scope.dart';
import '../../l10n/generated/app_l10n.dart';

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
    this.userId,
    this.onPhotoTap,
  });

  /// Whose photo to show; the photo lives on this device only.
  final String? userId;

  /// Opens the photo choices. Null leaves the avatar as it is.
  final VoidCallback? onPhotoTap;

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
        colors: [studafyAbyss, studafyDeep, studafyTeal],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              button: onPhotoTap != null,
              label: AppL10n.of(context).profilePhotoChange,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPhotoTap,
                child: Stack(
                  children: [
                    ProfileAvatar(
                      userId: userId,
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: .18),
                      fallback: Text(
                        profileInitials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onPhotoTap != null)
                      const PositionedDirectional(
                        end: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 14,
                            color: studafyNavy,
                          ),
                        ),
                      ),
                  ],
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

/// The student's own Studafy ID, as a row on their profile.
///
/// A parent cannot ask to be linked without it, so it is the one identifier
/// a student's profile shows: labelled once, explained in a line, copied
/// with a tap. Shown only to students, because it identifies one and nobody
/// else needs to read it here.
class StudafyIdRow extends StatefulWidget {
  const StudafyIdRow({super.key});

  @override
  State<StudafyIdRow> createState() => _StudafyIdRowState();
}

class _StudafyIdRowState extends State<StudafyIdRow> {
  String? _id;
  bool _loading = true;
  bool _started = false;
  bool _available = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    // Absent in shells that install no family scope, and in widget tests
    // that pump this page alone. The row is an extra, so it disappears
    // rather than taking the profile down with it.
    final family = FamilyScope.maybeOf(context);
    if (family == null) {
      setState(() => _available = false);
      return;
    }
    final result = await family.studentFamily();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _id = result.fold(
        onSuccess: (family) => family.identities.firstOrNull?.studafyId,
        // A missing id is not worth an error on a profile screen; the row
        // says how to get one instead.
        onFailure: (_) => null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    final id = _id;
    return SettingsRow(
      icon: Icons.qr_code_rounded,
      title: l10n.accountStudafyId,
      subtitle: _loading
          ? '…'
          : id == null
          ? l10n.studentFamilyJoinAClassToActivate
          : '$id\n${l10n.accountStudafyIdDetail}',
      trailing: id == null
          ? null
          : Tooltip(
              message: l10n.accountStudafyIdCopy,
              child: const Icon(
                Icons.copy_rounded,
                color: studafyMuted,
                size: 20,
              ),
            ),
      onTap: id == null
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final copied = l10n.accountStudafyIdCopied;
              await Clipboard.setData(ClipboardData(text: id));
              messenger.showMessage(copied);
            },
    );
  }
}
