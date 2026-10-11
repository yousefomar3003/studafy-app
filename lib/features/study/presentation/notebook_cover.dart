import 'package:flutter/material.dart';

import '../../../core/user_content_text.dart';
import '../domain/study_notebook.dart';

/// A notebook's cover colour.
Color notebookColor(NotebookColor color) => switch (color) {
  NotebookColor.navy => const Color(0xFF0A4174),
  NotebookColor.teal => const Color(0xFF2E7D7A),
  NotebookColor.coral => const Color(0xFFC4553F),
  NotebookColor.violet => const Color(0xFF5B4A9E),
  NotebookColor.amber => const Color(0xFFB7791F),
  NotebookColor.green => const Color(0xFF3D7A3F),
  NotebookColor.rose => const Color(0xFFB04A6E),
  NotebookColor.slate => const Color(0xFF4A5868),
};

IconData notebookIcon(NotebookIcon? icon) => switch (icon) {
  null || NotebookIcon.book => Icons.menu_book_rounded,
  NotebookIcon.science => Icons.science_outlined,
  NotebookIcon.math => Icons.calculate_outlined,
  NotebookIcon.language => Icons.translate_rounded,
  NotebookIcon.globe => Icons.public_rounded,
  NotebookIcon.history => Icons.account_balance_outlined,
  NotebookIcon.art => Icons.palette_outlined,
  NotebookIcon.music => Icons.music_note_rounded,
  NotebookIcon.code => Icons.code_rounded,
  NotebookIcon.star => Icons.star_outline_rounded,
};

/// A highlighter's ink, light enough to read through.
Color highlightColor(HighlightColor color) => switch (color) {
  HighlightColor.yellow => const Color(0xFFFFF2A8),
  HighlightColor.green => const Color(0xFFCDEFC4),
  HighlightColor.blue => const Color(0xFFCFE6FA),
  HighlightColor.pink => const Color(0xFFF9D3E0),
};

/// A notebook's cover: its colour, a spine, its icon, title and subtitle.
/// [compact] is the size of a cover on a shelf.
class NotebookCover extends StatelessWidget {
  const NotebookCover({
    super.key,
    required this.title,
    this.subtitle,
    required this.color,
    this.icon,
    this.compact = false,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final NotebookColor color;
  final NotebookIcon? icon;
  final bool compact;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final base = notebookColor(color);
    final radius = BorderRadiusDirectional.only(
      topStart: Radius.circular(compact ? 6 : 10),
      bottomStart: Radius.circular(compact ? 6 : 10),
      topEnd: Radius.circular(compact ? 14 : 22),
      bottomEnd: Radius.circular(compact ? 14 : 22),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [base, Color.lerp(base, Colors.black, .28)!],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: .28),
            blurRadius: compact ? 8 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // The spine.
          PositionedDirectional(
            start: compact ? 8 : 14,
            top: 0,
            bottom: 0,
            child: Container(
              width: compact ? 3 : 5,
              color: Colors.white.withValues(alpha: .18),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 20 : 34,
              compact ? 14 : 28,
              compact ? 12 : 24,
              compact ? 12 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  notebookIcon(icon),
                  color: Colors.white.withValues(alpha: .9),
                  size: compact ? 22 : 40,
                ),
                SizedBox(height: compact ? 10 : 22),
                // The label stuck on the cover.
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 8 : 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(compact ? 6 : 10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserContentText(
                        title,
                        maxLines: compact ? 2 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color.lerp(base, Colors.black, .35),
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 13.5 : 22,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: compact ? 2 : 6),
                        UserContentText(
                          subtitle!,
                          maxLines: compact ? 1 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color.lerp(base, Colors.black, .1),
                            fontSize: compact ? 11.5 : 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (footer != null) ...[
                  if (compact) const Spacer() else const SizedBox(height: 18),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .92),
                      fontSize: compact ? 11.5 : 13.5,
                    ),
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A page of the notebook: paper in the chosen style - lined, plain or
/// squared - with its number at the foot.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({
    super.key,
    required this.style,
    required this.pageLabel,
    required this.child,
  });

  final NotebookPageStyle style;
  final String pageLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Material, not a coloured box, so the lines' and rows' ink shows.
      child: Material(
        color: const Color(0xFFFFFDF8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE9E3D6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _PaperPainter(style, Directionality.of(context)),
          child: Column(
            children: [
              Expanded(child: child),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  pageLabel,
                  style: const TextStyle(
                    color: Color(0xFF8A8270),
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The spacing of the lines, so text can sit on them.
const notebookLineHeight = 28.0;

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.style, this.direction);

  final NotebookPageStyle style;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFBFD3E6).withValues(alpha: .55)
      ..strokeWidth = 1;
    switch (style) {
      case NotebookPageStyle.plain:
        break;
      case NotebookPageStyle.lined:
        for (var y = 64.0; y < size.height - 24; y += notebookLineHeight) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
        }
        // The margin, on the side a line starts from.
        final margin = Paint()
          ..color = const Color(0xFFE8A2A2).withValues(alpha: .6)
          ..strokeWidth = 1.2;
        final x = direction == TextDirection.rtl ? size.width - 36 : 36.0;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), margin);
      case NotebookPageStyle.grid:
        final grid = Paint()
          ..color = const Color(0xFFBFD3E6).withValues(alpha: .4)
          ..strokeWidth = .8;
        for (var y = 20.0; y < size.height; y += 20) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
        }
        for (var x = 20.0; x < size.width; x += 20) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
        }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.style != style || old.direction != direction;
}
