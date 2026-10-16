import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_design.dart';

/// The frame of every screen before the app proper: the navy backdrop, an
/// optional white logo above, and the content on one white card.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child, this.header, this.footer});

  final Widget child;

  /// Shown on the backdrop above the card - usually the white logo.
  final Widget? header;

  /// Shown on the backdrop below the card.
  final Widget? footer;

  @override
  Widget build(BuildContext c) => AnnotatedRegion<SystemUiOverlayStyle>(
    // Light clock and battery icons over the dark backdrop.
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: studafyBackdrop,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (header != null) ...[
                    Center(child: header),
                    const SizedBox(height: 24),
                  ],
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      22,
                      28,
                      22,
                      24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FB),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: studafyAbyss.withValues(alpha: .35),
                          blurRadius: 40,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  if (footer != null) ...[const SizedBox(height: 16), footer!],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The one strong action on a navy screen: a navy-to-indigo pill.
///
/// Still a [FilledButton], so it keeps the platform's focus, semantics and
/// disabled behaviour; the gradient is painted underneath it.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? studafyActionGradient : null,
        color: enabled ? null : const Color(0xFFD9E1E8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: studafyDeep.withValues(alpha: .35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: studafyMuted,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (showArrow) ...[
              const SizedBox(width: 10),
              Icon(
                directionalIcon(
                  context,
                  ltr: Icons.arrow_forward_rounded,
                  rtl: Icons.arrow_back_rounded,
                ),
                size: 22,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The soft, slightly raised surface of choices on a navy screen: role
/// tiles and sign-in buttons.
BoxDecoration softSurface({bool selected = false}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: selected
        ? [const Color(0xFFEAF4FB), const Color(0xFFD9EAF5)]
        : [Colors.white, const Color(0xFFEDF1F5)],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(
    color: selected ? studafyDeep : const Color(0xFFDCE4EB),
    width: selected ? 2 : 1,
  ),
  boxShadow: [
    BoxShadow(
      color: studafyAbyss.withValues(alpha: selected ? .16 : .08),
      blurRadius: selected ? 16 : 10,
      offset: const Offset(0, 5),
    ),
  ],
);
