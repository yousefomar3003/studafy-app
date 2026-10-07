import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';

/// Notes written with simple Markdown - as the AI writes notes from a
/// whiteboard or a lesson - shown as headings, lists and bold text rather
/// than with the `#` and `**` marks showing. Anything else is shown as
/// written. Each block takes its own text's direction, so Arabic notes
/// read right to left inside an English screen.
class NotesText extends StatelessWidget {
  const NotesText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final blocks = parseNotes(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final block in blocks) _block(context, block)],
    );
  }

  Widget _block(BuildContext context, NotesBlock block) {
    final direction =
        UserContentText.directionOf(block.text) ?? Directionality.of(context);
    final base = DefaultTextStyle.of(context).style;
    final style = switch (block.kind) {
      NotesBlockKind.heading => base.copyWith(
        fontWeight: FontWeight.w800,
        color: studafyInk,
        fontSize: block.level == 1 ? 18 : 16,
      ),
      _ => base.copyWith(height: 1.45),
    };
    final rich = Text.rich(
      TextSpan(style: style, children: inlineSpans(block.text)),
      textAlign: TextAlign.start,
    );
    final Widget child = switch (block.kind) {
      NotesBlockKind.bullet || NotesBlockKind.numbered => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              block.marker,
              style: style.copyWith(color: studafyMuted),
            ),
          ),
          Expanded(child: rich),
        ],
      ),
      _ => rich,
    };
    return Directionality(
      textDirection: direction,
      child: Padding(
        padding: EdgeInsets.only(
          top: block.kind == NotesBlockKind.heading ? 8 : 2,
          bottom: 2,
        ),
        child: child,
      ),
    );
  }
}

enum NotesBlockKind { heading, bullet, numbered, paragraph }

@immutable
class NotesBlock {
  const NotesBlock(this.kind, this.text, {this.level = 0, this.marker = ''});

  final NotesBlockKind kind;
  final String text;

  /// A heading's level, 1 to 3.
  final int level;

  /// A list item's bullet or number, as shown.
  final String marker;
}

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _bullet = RegExp(r'^[-*•]\s+(.*)$');
final _numbered = RegExp(r'^(\d{1,3})[.)]\s+(.*)$');

/// [text] as blocks: one per heading or list item, and one per paragraph.
List<NotesBlock> parseNotes(String text) {
  final blocks = <NotesBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(NotesBlock(NotesBlockKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (_heading.firstMatch(line) case final m?) {
      flush();
      blocks.add(
        NotesBlock(
          NotesBlockKind.heading,
          m.group(2)!.replaceAll(RegExp(r'#+$'), '').trim(),
          level: m.group(1)!.length.clamp(1, 3),
        ),
      );
    } else if (_bullet.firstMatch(line) case final m?) {
      flush();
      blocks.add(NotesBlock(NotesBlockKind.bullet, m.group(1)!, marker: '•'));
    } else if (_numbered.firstMatch(line) case final m?) {
      flush();
      blocks.add(
        NotesBlock(
          NotesBlockKind.numbered,
          m.group(2)!,
          marker: '${m.group(1)}.',
        ),
      );
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return blocks;
}

final _bold = RegExp(r'\*\*(.+?)\*\*|__(.+?)__');

/// [text] with `**bold**` shown bold and the marks removed.
List<InlineSpan> inlineSpans(String text) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in _bold.allMatches(text)) {
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    spans.add(
      TextSpan(
        text: m.group(1) ?? m.group(2),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return spans;
}
