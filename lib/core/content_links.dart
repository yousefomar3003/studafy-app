import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_l10n.dart';
import 'user_content_text.dart';

/// Links a teacher adds to a lesson, an assignment or an announcement.
///
/// They travel inside the text itself, one per line under the notes, so every
/// place that already carries a teacher's text carries its links too. Only
/// `https` links with a real host are accepted, and a reader is always shown
/// where a link goes before it opens: a lesson link is text somebody typed,
/// and a child should not be sent somewhere by a link that says one thing and
/// opens another.

/// A link that may be added and opened: https, a host, no credentials.
Uri? safeLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

final _linkPattern = RegExp(r'https://[^\s<>"]+');

/// Links as people type them in a chat: https, http, or a bare www. address.
final _chatLinkPattern = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+',
  caseSensitive: false,
);

/// A link typed in a chat, ready to open, or null. A www. address is opened
/// over https; nothing with credentials or without a real host is a link.
Uri? chatLink(String raw) {
  final value = raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

/// [body] with [links] on their own lines beneath it.
String textWithLinks(String body, List<Uri> links) {
  final trimmed = body.trim();
  if (links.isEmpty) return trimmed;
  final lines = [for (final link in links) link.toString()].join('\n');
  return trimmed.isEmpty ? lines : '$trimmed\n\n$lines';
}

/// "Add link", and the links added so far, removable.
class LinksField extends StatefulWidget {
  const LinksField({super.key, required this.onChanged, this.enabled = true});

  final ValueChanged<List<Uri>> onChanged;
  final bool enabled;

  @override
  State<LinksField> createState() => _LinksFieldState();
}

class _LinksFieldState extends State<LinksField> {
  final List<Uri> _links = [];

  Future<void> _add() async {
    final added = await showDialog<Uri>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (added == null || !mounted) return;
    setState(() => _links.add(added));
    widget.onChanged(List.unmodifiable(_links));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final link in _links)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_rounded),
            title: Text(link.host),
            subtitle: Text(
              link.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: l10n.linksRemove,
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.enabled
                  ? () {
                      setState(() => _links.remove(link));
                      widget.onChanged(List.unmodifiable(_links));
                    }
                  : null,
            ),
          ),
        TextButton.icon(
          onPressed: widget.enabled ? _add : null,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(l10n.linksAdd),
        ),
      ],
    );
  }
}

/// Asks for one link. Owns its text field's controller, so the controller
/// outlives the dialog's closing animation.
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final link = safeLink(_controller.text);
    if (link == null) {
      setState(() => _error = AppL10n.of(context).linksInvalid);
      return;
    }
    Navigator.pop(context, link);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.linksAddTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(hintText: 'https://', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.linksAdd)),
      ],
    );
  }
}

/// Shows where [link] goes and opens it outside the app only once the reader
/// says so. Every tappable link in the app goes through here.
Future<void> confirmAndOpenLink(
  BuildContext context,
  Uri link, {
  Future<bool> Function(Uri url)? openLink,
}) async {
  final l10n = AppL10n.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.linksOpenTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(link.host, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(link.toString(), style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.linksCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.linksOpen),
        ),
      ],
    ),
  );
  if (go != true) return;
  final open =
      openLink ??
      (Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);
  await open(link);
}

/// A teacher's text, with its https links tappable. A tap shows the site
/// and asks first.
class LinkedText extends StatefulWidget {
  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.openLink,
    this.chat = false,
    this.linkColor,
  });

  final String text;
  final TextStyle? style;

  /// A message: http and bare www. links are links too, as people type them.
  /// Every one still shows where it goes and asks before opening.
  final bool chat;

  /// The link colour, where the theme's would not read - a sent bubble.
  final Color? linkColor;

  /// Opens a link outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmAndOpen(Uri link) =>
      confirmAndOpenLink(context, link, openLink: widget.openLink);

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final text = widget.text;
    final matches = (widget.chat ? _chatLinkPattern : _linkPattern)
        .allMatches(text)
        .toList();
    if (matches.isEmpty) return UserContentText(text, style: widget.style);
    final linkStyle = (widget.style ?? const TextStyle()).copyWith(
      color: widget.linkColor ?? Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      var raw = match.group(0)!;
      // "see www.example.com." - the full stop ends the sentence, not the
      // address.
      final trailing = RegExp(r'[.,;:!?)\]]+$').firstMatch(raw)?.group(0);
      if (trailing != null) {
        raw = raw.substring(0, raw.length - trailing.length);
      }
      final link = widget.chat ? chatLink(raw) : safeLink(raw);
      if (link == null) {
        spans.add(TextSpan(text: raw));
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _confirmAndOpen(link);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(text: raw, style: linkStyle, recognizer: recognizer),
        );
      }
      if (trailing != null) spans.add(TextSpan(text: trailing));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Directionality(
      textDirection:
          UserContentText.directionOf(text) ?? Directionality.of(context),
      child: Text.rich(TextSpan(style: widget.style, children: spans)),
    );
  }
}
