import 'package:flutter/material.dart';

import 'studafy_design.dart';

/// Shared building blocks of the redesigned screens. Every screen composes
/// these rather than styling its own, so spacing, corners, icons and states
/// stay the same everywhere.

final _letter = RegExp(r'\p{L}', unicode: true);

/// The first two letters of a name, for an avatar with no photo.
///
/// Letters only: spaces, dots, digits and emoji are skipped, so "  Mr.ahmad"
/// gives "MR" and "Yousef Omar" gives "YO". Works per character, so Arabic
/// and other scripts give their own first two letters. A one-letter name
/// gives one letter, and a name with no letters gives "?".
String profileInitials(String name) {
  final letters = <String>[];
  for (final character in name.characters) {
    if (_letter.hasMatch(character)) letters.add(character);
    if (letters.length == 2) break;
  }
  if (letters.isEmpty) return '?';
  return letters.join().toUpperCase();
}

/// A recognisable icon for a class from its name - a flask for science, a
/// calculator for maths - in English or Arabic, and an open book otherwise.
IconData subjectIcon(String name) {
  final value = name.toLowerCase();
  bool any(List<String> words) => words.any(value.contains);
  if (any([
    'math',
    'algebra',
    'geometr',
    'calcul',
    'رياضيات',
    'جبر',
    'هندسة',
  ])) {
    return Icons.calculate_rounded;
  }
  if (any(['physic', 'فيزياء'])) return Icons.bolt_rounded;
  if (any(['chem', 'كيمياء'])) return Icons.science_rounded;
  if (any(['bio', 'أحياء', 'احياء'])) return Icons.eco_rounded;
  if (any(['science', 'علوم'])) return Icons.science_rounded;
  if (any([
    'english',
    'arabic',
    'french',
    'language',
    'literat',
    'reading',
    'writing',
    'لغة',
    'عربي',
    'انجليزي',
    'إنجليزي',
    'فرنسي',
    'أدب',
  ])) {
    return Icons.translate_rounded;
  }
  if (any([
    'history',
    'social',
    'geograph',
    'civic',
    'تاريخ',
    'جغرافيا',
    'اجتماعيات',
    'وطنية',
  ])) {
    return Icons.public_rounded;
  }
  if (any([
    'islam',
    'relig',
    'quran',
    'قرآن',
    'إسلام',
    'اسلام',
    'دين',
    'تربية إسلامية',
  ])) {
    return Icons.auto_stories_rounded;
  }
  if (any(['art', 'draw', 'design', 'فن', 'رسم'])) return Icons.palette_rounded;
  if (any(['music', 'موسيقى'])) return Icons.music_note_rounded;
  if (any(['sport', 'physical ed', 'p.e', 'gym', 'رياضة', 'بدنية'])) {
    return Icons.sports_soccer_rounded;
  }
  if (any([
    'computer',
    'ict',
    'coding',
    'program',
    'tech',
    'حاسوب',
    'حاسب',
    'برمجة',
    'تكنولوجيا',
  ])) {
    return Icons.computer_rounded;
  }
  return Icons.menu_book_rounded;
}

/// A round avatar showing a person's initials, tinted from the palette.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.radius = 22});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CircleAvatar(
      radius: radius,
      backgroundColor: studafyWash,
      child: Text(
        profileInitials(name),
        style: TextStyle(
          color: studafyNavy,
          fontSize: radius * .72,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// A small rounded square holding an icon, used to make a row or card
/// recognisable at a glance.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.color = studafyNavy,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Icon(icon, color: color, size: size * .5),
  );
}

/// A heading that starts a group on a page, with an optional action on the
/// far side ("See all", "New").
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.padding = const EdgeInsetsDirectional.fromSTEB(4, 20, 0, 10),
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                color: studafyInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// A short status in words with an icon, never in colour alone: Draft,
/// Published, Present, Absent...
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.color = studafyNavy,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The round "+" that opens a screen's creation menu. Its accessible name
/// is [label] ("Create"), read out and shown on long press.
class StudafyCreateButton extends StatelessWidget {
  const StudafyCreateButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [studafyDeep, studafyTeal],
          ),
          boxShadow: [
            BoxShadow(
              color: studafyDeep.withValues(alpha: .35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 60,
              child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A row of pill-shaped tabs, for switching between the parts of one page
/// (Lessons / Assignments / Wellbeing, Messages / Announcements).
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final IconData Function(T value)? icon;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: _PillTab(
              label: label(value),
              icon: icon?.call(value),
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
          ),
      ],
    ),
  );
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? studafyNavy : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? studafyNavy : studafyHairline),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : studafyMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : studafyInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A titled group of settings rows on one white card, as in the iOS
/// Settings app.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.footer,
  });

  final String? title;
  final List<Widget> children;

  /// A line of explanation under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                color: studafyMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ),
        ),
      FeatureCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 64,
                  color: studafyHairline,
                ),
              child,
            ],
          ],
        ),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Text(
            footer!,
            style: const TextStyle(color: studafyMuted, fontSize: 12.5),
          ),
        ),
    ],
  );
}

/// One row in a [SettingsGroup]: an icon, a title, an optional description,
/// and a chevron or other trailing control.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? studafyDanger : studafyNavy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: destructive ? studafyDanger : studafyInk,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron && onTap != null)
              Icon(forwardChevron(context), color: studafyMuted),
          ],
        ),
      ),
    );
  }
}

/// A calm, centred empty or error state with an optional action.
class StudafyEmptyState extends StatelessWidget {
  const StudafyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: studafyWash,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: studafyNavy, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: studafyInk,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: studafyMuted, height: 1.4),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

/// A large page title, as in iOS, with an optional line under it and
/// actions on the far side. It shares the page's background, so the header
/// and the content read as one screen rather than a band above a sheet.
class StudafyLargeTitle extends StatelessWidget {
  const StudafyLargeTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 6),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.8,
                      height: 1.15,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: studafyMuted,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: action,
            ),
        ],
      ),
    ),
  );
}

/// A round, quiet header button - white with a hairline, like the
/// notifications bell - for page-level actions such as History. Its label is
/// read out and shown on long press; use [StudafyPillButton] where the
/// label should be visible.
class StudafyRoundButton extends StatelessWidget {
  const StudafyRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      disabledBackgroundColor: Colors.white.withValues(alpha: .6),
      side: const BorderSide(color: studafyHairline, width: 1.2),
      fixedSize: const Size(44, 44),
      minimumSize: const Size(44, 44),
    ),
    icon: Icon(icon, color: onPressed == null ? studafyMuted : studafyInk),
  );
}

/// A compact, labelled header action: an icon and a word, on a soft pill.
class StudafyPillButton extends StatelessWidget {
  const StudafyPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Filled in the brand colour, for the one action a page wants noticed.
  final bool prominent;

  @override
  Widget build(BuildContext context) => Tooltip(
    // The label is already visible and read out; the tooltip only repeats
    // it on long press, as every other header control does.
    message: label,
    excludeFromSemantics: true,
    child: _button(),
  );

  Widget _button() => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: prominent ? studafyNavy : Colors.white,
      foregroundColor: prominent ? Colors.white : studafyNavy,
      side: prominent ? null : const BorderSide(color: studafyHairline),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    icon: Icon(icon, size: 19),
    label: Text(label),
  );
}

/// The student's plan at a glance: its name, how much of today's or this
/// month's allowance is used, what the next plan adds, and the way to it.
///
/// Built from plain values so any feature can show it without depending on
/// the study feature. With no [actionLabel] it only informs - a student who
/// already has the access is never shown an upgrade.
class PlanSummaryCard extends StatelessWidget {
  const PlanSummaryCard({
    super.key,
    required this.eyebrow,
    required this.planName,
    this.detail,
    this.progress,
    this.benefitsTitle,
    this.benefits = const [],
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// "Your plan".
  final String eyebrow;
  final String planName;

  /// A line of usage: "4 of 10 questions today".
  final String? detail;

  /// 0 to 1, drawn as a bar under [detail].
  final double? progress;

  /// "Upgrade to Studafy Plus for:".
  final String? benefitsTitle;
  final List<String> benefits;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// One line and the action, for places where the plan is secondary.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final upgrade = actionLabel != null && onAction != null;
    final button = upgrade
        ? FilledButton.icon(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: studafyNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.workspace_premium_rounded, size: 19),
            label: Text(actionLabel!),
          )
        : null;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Color.alphaBlend(studafySky.withValues(alpha: .16), Colors.white),
              Colors.white,
            ],
          ),
          border: Border.all(color: studafyFrost.withValues(alpha: .8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.workspace_premium_rounded,
                  color: studafyDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        planName,
                        style: const TextStyle(
                          color: studafyInk,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (compact && button != null) button,
              ],
            ),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(
                detail!,
                style: const TextStyle(color: studafyInk, fontSize: 13.5),
              ),
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: progress! >= 1 ? studafyDanger : studafyTeal,
                    backgroundColor: studafyWash,
                  ),
                ),
              ],
            ],
            if (!compact && benefits.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (benefitsTitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    benefitsTitle!,
                    style: const TextStyle(
                      color: studafyInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              for (final benefit in benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: studafyTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            color: studafyInk,
                            fontSize: 13.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (!compact && button != null) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: button),
            ],
          ],
        ),
      ),
    );
  }
}
