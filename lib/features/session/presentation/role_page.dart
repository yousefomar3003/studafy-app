import 'package:flutter/material.dart';

import '../../../core/device_settings.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../application/session_interactor.dart';
import 'auth_frame.dart';
import 'intro_slides.dart';
import 'login_page.dart';

export 'auth_frame.dart' show AuthFrame;

/// Role chosen on the welcome screen; maps onto [StudafyRole] at login.
enum UserRole { teacher, student, parent }

class RolePage extends StatefulWidget {
  const RolePage({super.key, required this.session, this.settings});
  final SessionInteractor session;

  /// Remembers that the welcome slides were seen. Without it (tests, and
  /// any caller that does not pass one) the slides are not shown first.
  final DeviceSettingsStore? settings;

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  UserRole? selected;

  /// Null while the device setting is being read, so the role screen never
  /// flashes up before the slides on a first launch.
  bool? _showIntro;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    if (settings == null) {
      _showIntro = false;
    } else {
      settings.read(DeviceSettingKeys.introSeen).then((seen) {
        if (mounted) setState(() => _showIntro = seen == null);
      });
    }
  }

  void _finishIntro() {
    setState(() => _showIntro = false);
    widget.settings?.write(DeviceSettingKeys.introSeen, '1');
  }

  @override
  Widget build(BuildContext c) {
    final showIntro = _showIntro;
    if (showIntro == null) {
      return const Scaffold(
        backgroundColor: studafyAbyss,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: studafyOceanGradient),
          child: SizedBox.expand(),
        ),
      );
    }
    if (showIntro) return IntroSlides(onDone: _finishIntro);
    final l10n = AppL10n.of(c);
    return AuthFrame(
      header: const StudafyLogo(size: 38, onDark: true),
      footer: Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _showIntro = true),
          style: TextButton.styleFrom(foregroundColor: studafyFrost),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(l10n.roleWhatIsStudafy),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.rolesYourSpaceToGrow,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: studafyTeal,
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.roleQuestion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: studafyAbyss,
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.roleChoosePrompt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafySteel, height: 1.4),
          ),
          const SizedBox(height: 24),
          for (final r in UserRole.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: RoleTile(
                role: r,
                selected: selected == r,
                onTap: () => setState(() => selected = r),
              ),
            ),
          const SizedBox(height: 10),
          AuthPrimaryButton(
            label: l10n.roleContinue,
            onPressed: selected == null
                ? null
                : () => Navigator.of(c).pushOnce(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginPage(role: selected!, session: widget.session),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The reader's name for a role.
///
/// One place, so the role a user picked reads the same on the role screen,
/// the welcome line and anywhere else it is shown.
String roleLabel(BuildContext context, UserRole role) {
  final l10n = AppL10n.of(context);
  return switch (role) {
    UserRole.teacher => l10n.roleTeacher,
    UserRole.student => l10n.roleStudent,
    UserRole.parent => l10n.roleParent,
  };
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
    final l10n = AppL10n.of(c);
    final d = switch (role) {
      UserRole.teacher => (
        Icons.school_rounded,
        l10n.roleTeacher,
        l10n.roleTeacherDetail,
      ),
      UserRole.student => (
        Icons.menu_book_rounded,
        l10n.roleStudent,
        l10n.roleStudentDetail,
      ),
      UserRole.parent => (
        Icons.family_restroom_rounded,
        l10n.roleParent,
        l10n.roleParentDetail,
      ),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: softSurface(selected: selected),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: selected ? studafyActionGradient : null,
                    color: selected ? null : studafyFrost.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    d.$1,
                    color: selected ? Colors.white : studafyDeep,
                  ),
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
                          color: studafyAbyss,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.$3,
                        style: const TextStyle(
                          color: studafySteel,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? studafyDeep : studafyMist,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
