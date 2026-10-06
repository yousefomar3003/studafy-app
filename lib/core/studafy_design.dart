import 'package:flutter/material.dart';

// Brand roles. Every screen reads these names, so the whole app follows the
// ocean palette below: white is the primary surface, the deep blue is the
// accent for actions and selection, and the steel blue carries secondary
// text. The names predate the palette and are kept so nothing else changes.
const studafyNavy = Color(0xFF0A4174);
const studafyCyan = Color(0xFF4E8EA2);
const studafyInk = Color(0xFF001D39);
const studafyMuted = Color(0xFF49769F);

/// The page behind cards: white with the faintest frost, so a white card
/// still reads as a surface without a hard line between them.
const studafyCanvas = Color(0xFFF7FAFD);

/// Hairlines and quiet fills, from the lightest palette colour.
const studafyHairline = Color(0xFFE2ECF3);
const studafyWash = Color(0xFFEFF5FA);

/// Errors stay red: they are a warning, not a brand choice.
const studafyDanger = Color(0xFFB3261E);

// The ocean palette, darkest to lightest. The welcome, sign-in and intro
// screens are built from it; the rest of the app moves to it screen by
// screen.
const studafyAbyss = Color(0xFF001D39);
const studafyDeep = Color(0xFF0A4174);
const studafySteel = Color(0xFF49769F);
const studafyTeal = Color(0xFF4E8EA2);
const studafyMist = Color(0xFF6EA2B3);
const studafySky = Color(0xFF7BBDE8);
const studafyFrost = Color(0xFFBDD8E9);

/// The deep-water backdrop behind the welcome and sign-in screens.
const studafyOceanGradient = LinearGradient(
  begin: AlignmentDirectional.topStart,
  end: AlignmentDirectional.bottomEnd,
  colors: [studafyAbyss, studafyDeep, studafyTeal],
  stops: [0, .55, 1],
);

/// Primary actions on the ocean screens.
const studafyActionGradient = LinearGradient(
  begin: AlignmentDirectional.centerStart,
  end: AlignmentDirectional.centerEnd,
  colors: [studafyDeep, studafyTeal],
);

/// The brand wordmark artwork: "studafy" with the sparkle cross over the t.
const studafyWordmarkAsset = 'assets/brand/studafy_wordmark.png';

/// The same artwork for dark backgrounds: white letters, the cross still in
/// its own cyan.
const studafyWordmarkOnDarkAsset = 'assets/brand/studafy_wordmark_white.png';

/// Width over height of [studafyWordmarkAsset], so space is reserved for it
/// before the image has decoded and the header never jumps.
const studafyWordmarkAspect = 3.34;

/// Brand lockup shared by the session flow and every shell.
///
/// The real wordmark artwork everywhere: navy on light surfaces, and white
/// (with the cross kept cyan) on the ocean backdrop of the first screens.
class StudafyLogo extends StatelessWidget {
  const StudafyLogo({super.key, this.size = 46, this.onDark = false});
  final double size;

  /// White wordmark for the ocean backdrop.
  final bool onDark;
  @override
  Widget build(BuildContext c) {
    final height = size * 1.15;
    return Semantics(
      label: 'Studafy',
      image: true,
      child: SizedBox(
        height: height,
        width: height * studafyWordmarkAspect,
        child: Image.asset(
          onDark ? studafyWordmarkOnDarkAsset : studafyWordmarkAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          // A build without the asset still shows the brand.
          errorBuilder: (_, _, _) => FittedBox(child: _drawn()),
        ),
      ),
    );
  }

  Widget _drawn() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size * .56,
        height: size * .56,
        margin: EdgeInsetsDirectional.only(end: size * .05),
        decoration: BoxDecoration(
          color: onDark
              ? studafyFrost.withValues(alpha: .22)
              : studafyCyan.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size * .18),
        ),
        child: Icon(
          Icons.add_rounded,
          color: onDark ? studafySky : studafyCyan,
          size: size * .45,
        ),
      ),
      Text(
        'studafy',
        style: TextStyle(
          fontSize: size,
          height: 1,
          letterSpacing: -2,
          fontWeight: FontWeight.w900,
          color: onDark ? Colors.white : studafyNavy,
        ),
      ),
    ],
  );
}

/// Shared card primitive used across features: a white, softly raised
/// surface with rounded corners and a hairline edge.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.child,
    this.onTap,
    this.tint,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext c) {
    final radius = BorderRadius.circular(22);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: studafyAbyss.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: tint == null
            ? Colors.white
            : Color.alphaBlend(tint!.withValues(alpha: .07), Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: tint == null
                ? studafyHairline
                : tint!.withValues(alpha: .18),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : StudafyPressable(child: card);
  }
}

/// Pull-to-refresh that always reaches the server.
///
/// Reads answered moments ago are reused so screens open instantly; someone
/// pulling to refresh wants what is there now, so those are forgotten first.
class StudafyRefreshIndicator extends StatelessWidget {
  const StudafyRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  /// Installed by the composition root. Null in tests and synthetic builds,
  /// which remember nothing.
  static VoidCallback? forgetRecentReads;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      forgetRecentReads?.call();
      return onRefresh();
    },
    child: child,
  );
}

/// Gives a tappable surface a brief, gentle press: it settles to 98% while
/// a finger is on it. Purely visual - the child handles the tap - and still
/// under the device's reduce-motion setting.
class StudafyPressable extends StatefulWidget {
  const StudafyPressable({super.key, required this.child, this.scale = .98});

  final Widget child;
  final double scale;

  @override
  State<StudafyPressable> createState() => _StudafyPressableState();
}

class _StudafyPressableState extends State<StudafyPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    // A tap recogniser rather than raw pointer events: a touch that turns
    // into a scroll is cancelled, so cards no longer shrink under a finger
    // that is scrolling past them. It never wins the tap - the child does -
    // so it only watches.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class StudafyNavItem {
  const StudafyNavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Persistent navigation shared by every role: a floating, rounded glass
/// bar that sits above the page rather than cutting a band across it.
///
/// It never covers content - it occupies the scaffold's bottom slot, so the
/// page above ends where it starts - and it becomes more compact while the
/// person scrolls ([compact]), expanding again on any touch. Labels stay in
/// the semantics and tooltips when they are hidden. Motion follows the
/// device's reduce-motion setting. The bar is an almost opaque white, so it
/// stays legible on any page.
class StudafyNavigationBar extends StatelessWidget {
  const StudafyNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    this.accent = studafyNavy,
    this.compact = false,
    this.onInteract,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<StudafyNavItem> items;
  final Color accent;

  /// Icons only, and a little lower, while the page is being scrolled.
  final bool compact;

  /// Called on any touch of the bar, so the host can expand it again.
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final radius = BorderRadius.circular(compact ? 26 : 30);
    return _HiddenWhileTyping(
      duration: duration,
      child: _bar(context, duration, radius),
    );
  }

  Widget _bar(BuildContext context, Duration duration, BorderRadius radius) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 6),
        child: Listener(
          onPointerDown: (_) => onInteract?.call(),
          // The slot keeps the full height while the bar shrinks inside it,
          // so going compact never resizes - and re-lays out - the page
          // above, mid-scroll.
          child: SizedBox(
            height: 70,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                height: compact ? 58 : 70,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: studafyAbyss.withValues(alpha: .14),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                // No backdrop blur: the bar sits in the scaffold's bottom slot, so
                // nothing ever scrolls behind it to blur, and the filter only cost
                // a full re-composite on every frame.
                child: ClipRRect(
                  borderRadius: radius,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .9),
                      borderRadius: radius,
                      border: Border.all(color: studafyHairline),
                    ),
                    child: Row(
                      children: [
                        for (final (index, item) in items.indexed)
                          Expanded(
                            child: StudafyNavDestination(
                              item: item,
                              selected: index == selectedIndex,
                              compact: compact,
                              accent: accent,
                              duration: duration,
                              onTap: () => onSelected(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Takes the bar out of the way while the person is typing - a question to
/// the helper, a note, a search - and brings it back when they leave the
/// field. Follows focus rather than the on-screen keyboard, so it behaves
/// the same with a hardware keyboard.
class _HiddenWhileTyping extends StatefulWidget {
  const _HiddenWhileTyping({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_HiddenWhileTyping> createState() => _HiddenWhileTypingState();
}

class _HiddenWhileTypingState extends State<_HiddenWhileTyping> {
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
    _typing = _isTyping();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    super.dispose();
  }

  static bool _isTyping() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null || !focused.mounted) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _focusChanged() {
    final typing = _isTyping();
    if (typing != _typing && mounted) setState(() => _typing = typing);
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: widget.duration,
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: _typing ? const SizedBox(width: double.infinity) : widget.child,
  );
}

/// One destination on [StudafyNavigationBar].
class StudafyNavDestination extends StatelessWidget {
  const StudafyNavDestination({
    super.key,
    required this.item,
    required this.selected,
    required this.compact,
    required this.accent,
    required this.duration,
    required this.onTap,
  });

  final StudafyNavItem item;
  final bool selected;
  final bool compact;
  final Color accent;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: item.label,
    excludeSemantics: true,
    child: Tooltip(
      message: item.label,
      excludeFromSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 16 : 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: selected ? studafyWash : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? item.selectedIcon : item.icon,
                size: 24,
                color: selected ? accent : studafyMuted,
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              child: compact
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? accent : studafyMuted,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

class StudafyStatusCard extends StatelessWidget {
  const StudafyStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $message',
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: studafyNavy, size: 34),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: studafyMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Picks between a left-facing and a right-facing icon by the reading
/// direction (MOB-070, ADR-0028).
///
/// Material mirrors `AppBar`'s automatic leading and `BackButton` for itself,
/// but it does **not** mirror `Icons.chevron_right`, `Icons.arrow_forward` or
/// `Icons.send`. In Arabic those point backwards unless chosen here.
IconData directionalIcon(
  BuildContext context, {
  required IconData ltr,
  required IconData rtl,
}) => Directionality.of(context) == TextDirection.rtl ? rtl : ltr;

/// The "go deeper" chevron on a row, pointing the way the reader reads.
/// The mirror of [forwardChevron]: "previous" in the reading direction.
IconData backChevron(BuildContext context) => directionalIcon(
  context,
  ltr: Icons.chevron_left_rounded,
  rtl: Icons.chevron_right_rounded,
);

IconData forwardChevron(BuildContext context) => directionalIcon(
  context,
  ltr: Icons.chevron_right_rounded,
  rtl: Icons.chevron_left_rounded,
);

/// Shared editorial header for each role. Motion respects device preferences.
class StudafyHero extends StatelessWidget {
  const StudafyHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
    this.child,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? child;

  /// Screens whose hero has already faded in. A hero is rebuilt when it is
  /// scrolled back into view or its page reloads, and replaying the entrance
  /// each time read as the page flickering.
  static final _entered = Expando<bool>('StudafyHero.entered');

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final entered = route != null && (_entered[route] ?? false);
    if (route != null) _entered[route] = true;
    return _entrance(context, from: entered ? 1 : 0);
  }

  Widget _entrance(BuildContext context, {required double from}) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: from, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        builder: (context, value, content) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: content,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [studafyAbyss, studafyDeep, studafyTeal],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eyebrow,
                      style: const TextStyle(
                        color: studafyFrost,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: studafyFrost, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  color: studafyFrost,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (child != null) ...[const SizedBox(height: 20), child!],
            ],
          ),
        ),
      );
}
