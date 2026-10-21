import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'content_links.dart';
import 'studafy_design.dart';
import 'user_content_text.dart';

/// The AI Tutor's answer, with the Markdown the model writes in rendered:
/// bold, italics, headings, lists, inline code and code blocks.
class HelperAnswerText extends StudyMarkdown {
  const HelperAnswerText(super.text, {super.key, super.color});
}

/// Study text written in Markdown - an AI Tutor answer, or a note in the
/// Notebook - rendered: bold, italics, headings, lists, inline code and
/// code blocks. [fontSize] and [lineHeight] set the body; headings scale
/// with it, so a notebook page can read larger than a chat bubble.
///
/// The text is somebody's own, so like [UserContentText] it is laid out in
/// its own direction - an Arabic note in an English interface still reads
/// right to left, bullets and all.
///
/// Nothing in it reaches the network on its own: an image is shown as its
/// alt text, never fetched, and a link opens only after the reader has seen
/// where it goes and agreed ([confirmAndOpenLink]), and only for https.
class StudyMarkdown extends StatelessWidget {
  const StudyMarkdown(
    this.text, {
    super.key,
    this.color = studafyInk,
    this.fontSize,
    this.lineHeight = 1.4,
  });

  final String text;
  final Color color;
  final double? fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: color,
      height: lineHeight,
      fontSize: fontSize,
    );
    final size = body.fontSize ?? 14;
    final code = body.copyWith(
      fontFamily: 'monospace',
      fontSize: size * .92,
      backgroundColor: studafyWash,
    );
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      strong: const TextStyle(fontWeight: FontWeight.w700),
      em: const TextStyle(fontStyle: FontStyle.italic),
      h1: body.copyWith(fontSize: size * 1.29, fontWeight: FontWeight.w800),
      h2: body.copyWith(fontSize: size * 1.18, fontWeight: FontWeight.w800),
      h3: body.copyWith(fontSize: size * 1.07, fontWeight: FontWeight.w700),
      h4: body.copyWith(fontWeight: FontWeight.w700),
      h5: body.copyWith(fontWeight: FontWeight.w700),
      h6: body.copyWith(fontWeight: FontWeight.w700),
      listBullet: body,
      code: code,
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: studafyWash,
        borderRadius: BorderRadius.circular(10),
      ),
      blockquote: body.copyWith(color: studafyMuted),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 2,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: studafyFrost, width: 3),
        ),
      ),
      a: body.copyWith(
        color: studafyIndigo,
        decoration: TextDecoration.underline,
      ),
      tableBody: body,
      tableHead: body.copyWith(fontWeight: FontWeight.w700),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(top: BorderSide(color: studafyHairline)),
      ),
    );
    return Directionality(
      textDirection:
          UserContentText.directionOf(text) ?? Directionality.of(context),
      child: MarkdownBody(
        data: text,
        styleSheet: styleSheet,
        // A model's single line break is meant as one.
        softLineBreak: true,
        onTapLink: (_, href, _) {
          final link = href == null ? null : safeLink(href);
          if (link != null) confirmAndOpenLink(context, link);
        },
        imageBuilder: (_, _, alt) =>
            Text(alt ?? '', style: body.copyWith(color: studafyMuted)),
        bulletBuilder: (parameters) => Text(
          parameters.style == BulletStyle.orderedList
              ? '${parameters.index + 1}.'
              : '•',
          // End, not right: the number sits against its line in Arabic too.
          textAlign: TextAlign.end,
          style: body,
        ),
      ),
    );
  }
}
