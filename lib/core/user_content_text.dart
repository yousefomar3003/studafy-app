import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// Renders text a person wrote, exactly as they wrote it (MOB-070, ADR-0028).
///
/// **Studafy never translates user content.** Messages, names, class and
/// assignment titles, school names and notes are shown verbatim, in whatever
/// language they were written. Only interface chrome is localized.
///
/// Verbatim is not enough on its own, though. A widget inherits its direction
/// from the surrounding interface, so an Arabic message inside an English
/// screen would be laid out left-to-right: trailing punctuation jumps to the
/// wrong end, and a line starting with a digit or bracket reorders. This
/// widget therefore decides direction from *the string itself* — the first
/// strong character, which is the rule Unicode UAX#9 specifies — and falls
/// back to the surrounding direction for text with no strong character at all
/// (a bare number, an emoji, an ID like `STU-42`).
///
/// Use it wherever the text came from a person or a school, not from an
/// `.arb` file. Interface copy must not use it: that text is already in the
/// reader's language and belongs in the interface's own direction.
class UserContentText extends StatelessWidget {
  const UserContentText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textScaler,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextScaler? textScaler;

  /// The direction this string should be laid out in, or null when the string
  /// carries no signal and the surrounding interface should decide.
  static TextDirection? directionOf(String text) {
    if (!Bidi.hasAnyLtr(text) && !Bidi.hasAnyRtl(text)) return null;
    return Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    final direction = directionOf(text) ?? Directionality.of(context);
    return Directionality(
      textDirection: direction,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textScaler: textScaler,
        // Start, not left: alignment follows the text's own direction, so an
        // Arabic name in an English list still hangs from the right edge of
        // its own box.
        textAlign: TextAlign.start,
      ),
    );
  }
}
