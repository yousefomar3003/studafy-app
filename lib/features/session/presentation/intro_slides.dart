import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';

/// What Studafy is, in three slides, before choosing a role.
///
/// Deliberately short: three slides, and "Skip" on every one of them, so
/// learning about the app never stands between somebody and signing in.
/// Shown once per device; "What is Studafy?" on the role screen brings it
/// back.
class IntroSlides extends StatefulWidget {
  const IntroSlides({super.key, required this.onDone});

  /// Called by "Skip" and by "Get started" on the last slide.
  final VoidCallback onDone;

  @override
  State<IntroSlides> createState() => _IntroSlidesState();
}

class _IntroSlidesState extends State<IntroSlides> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<_Slide> _slides(AppL10n l10n) => [
    _Slide(
      icon: Icons.school_rounded,
      satellites: const [
        Icons.menu_book_rounded,
        Icons.fact_check_rounded,
        Icons.forum_rounded,
      ],
      title: l10n.introTitleOne,
      body: l10n.introBodyOne,
    ),
    _Slide(
      icon: Icons.edit_note_rounded,
      satellites: const [
        Icons.description_rounded,
        Icons.laptop_mac_rounded,
        Icons.verified_rounded,
      ],
      title: l10n.introTitleTwo,
      body: l10n.introBodyTwo,
    ),
    _Slide(
      icon: Icons.family_restroom_rounded,
      satellites: const [
        Icons.insights_rounded,
        Icons.event_available_rounded,
        Icons.lock_rounded,
      ],
      title: l10n.introTitleThree,
      body: l10n.introBodyThree,
    ),
  ];

  void _next(int count) {
    if (_index >= count - 1) {
      widget.onDone();
      return;
    }
    _pages.nextPage(
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final slides = _slides(l10n);
    final last = _index == slides.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: studafyBackdrop,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 12, 0),
                child: Row(
                  children: [
                    const StudafyLogo(size: 28, onDark: true),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: studafyFrost,
                      ),
                      child: Text(l10n.introSkip),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (index) => setState(() => _index = index),
                  children: [for (final slide in slides) slide],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Semantics(
                      label: l10n.introPageOf(_index + 1, slides.length),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < slides.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 8,
                              width: i == _index ? 26 : 8,
                              decoration: BoxDecoration(
                                color: i == _index
                                    ? studafySky
                                    : studafyFrost.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _next(slides.length),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: Colors.white,
                          foregroundColor: studafyDeep,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(last ? l10n.introStart : l10n.introNext),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.satellites,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final List<IconData> satellites;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final art = (constraints.maxHeight * .46).clamp(150.0, 260.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Art(size: art, icon: icon, satellites: satellites),
              const SizedBox(height: 36),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: studafyFrost,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A large icon in layered rings with three small icons around it. Drawn
/// from icons, so it follows the palette and needs no image assets.
class _Art extends StatelessWidget {
  const _Art({
    required this.size,
    required this.icon,
    required this.satellites,
  });

  final double size;
  final IconData icon;
  final List<IconData> satellites;

  @override
  Widget build(BuildContext context) {
    Widget ring(double factor, double alpha) => Container(
      width: size * factor,
      height: size * factor,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: studafyFrost.withValues(alpha: alpha),
      ),
    );
    Widget satellite(IconData icon, AlignmentDirectional at) => Align(
      alignment: at,
      child: Container(
        width: size * .24,
        height: size * .24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .07),
          boxShadow: [
            BoxShadow(
              color: studafyAbyss.withValues(alpha: .3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: studafyDeep, size: size * .12),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring(1, .08),
          ring(.74, .12),
          Container(
            width: size * .5,
            height: size * .5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [studafySky, studafyTeal],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: size * .24),
          ),
          satellite(satellites[0], const AlignmentDirectional(-.95, -.7)),
          satellite(satellites[1], const AlignmentDirectional(.95, -.45)),
          satellite(satellites[2], const AlignmentDirectional(.55, .95)),
        ],
      ),
    );
  }
}
