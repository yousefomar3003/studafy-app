import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';

/// The colour of a notebook page: warm paper, not the app's blue-white.
const notebookPaper = Color(0xFFFFFDF6);
const _rule = Color(0xFFDCE8F2);
const _margin = Color(0xFFF1B9B4);

/// One page of a paper notebook: ruled lines, and a margin line on the side
/// the writing starts from (the right in Arabic). The lines are drawn
/// behind the content and say nothing to a screen reader.
class RuledPage extends StatelessWidget {
  const RuledPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(40, 26, 22, 32),
    this.spacing = 30,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// The distance between ruled lines.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: notebookPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE6D6)),
        boxShadow: [
          BoxShadow(
            color: studafyAbyss.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _RulesPainter(spacing: spacing, rtl: rtl),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _RulesPainter extends CustomPainter {
  const _RulesPainter({required this.spacing, required this.rtl});

  final double spacing;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = _rule
      ..strokeWidth = 1;
    for (var y = spacing * 2; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = _margin
      ..strokeWidth = 1.4;
    final x = rtl ? size.width - 28 : 28.0;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), margin);
  }

  @override
  bool shouldRepaint(_RulesPainter old) =>
      old.spacing != spacing || old.rtl != rtl;
}

/// A small label for a plan a feature needs: "Plus" or "Max".
class PlanBadge extends StatelessWidget {
  const PlanBadge(this.tier, {super.key});

  final StudyPlanTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final max = tier == StudyPlanTier.max;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: max ? studafyIndigo : studafyTeal,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        max ? l10n.planBadgeMax : l10n.planBadgePlus,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Where a note came from, when it was not typed.
class NoteSourceBadge extends StatelessWidget {
  const NoteSourceBadge(this.entry, {super.key});

  final NotebookEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = entry.fromWhiteboard
        ? l10n.nbFromPhotoBadge
        : entry.fromLesson
        ? l10n.notebookFromLessonBadge
        : null;
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: studafyWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry.fromWhiteboard
                ? Icons.photo_camera_outlined
                : Icons.menu_book_outlined,
            size: 13,
            color: studafyNavy,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: studafyNavy,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Edited 21 Oct" - when a note last changed.
String noteDateLine(BuildContext context, NotebookEntry entry) =>
    AppL10n.of(context).nbEdited(studafyMediumDate(context, entry.changedAt));

/// The first words of a note, without its Markdown, for a page list.
String noteSnippet(String body) => body
    .replaceAll(
      RegExp(r'^\s{0,3}(#{1,6}|[-*+]|\d+[.)]|>)\s*', multiLine: true),
      '',
    )
    .replaceAll(RegExp(r'[*_`]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
