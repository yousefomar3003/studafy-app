import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_l10n.dart';
import 'attachment_field.dart';
import 'attachment_opener.dart';
import 'content_links.dart';
import 'coursework_models.dart';
import 'file_upload_repository.dart';
import 'studafy_design.dart';
import 'uploads_scope.dart';

/// The attachments on a lesson, work, a question or a grade, as one
/// component for every role (ADR-0036): photos as thumbnails, documents as
/// rows that open or share, and titled links that say where they go before
/// opening. Nothing here decides who may see what - the server only ever
/// sends what the reader may open.
class AttachmentsView extends StatelessWidget {
  const AttachmentsView({
    super.key,
    this.attachments = const [],
    this.links = const [],
    this.uploads,
    this.openLink,
    this.dense = false,
  });

  final List<StoredAttachment> attachments;
  final List<ContentLink> links;

  /// Falls back to the app's [UploadsScope].
  final FileUploadRepository? uploads;

  /// Opens a link outside the app. Tests supply their own.
  final Future<bool> Function(Uri url)? openLink;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty && links.isEmpty) return const SizedBox.shrink();
    final images = [
      for (final a in attachments)
        if ((a.mediaType ?? '').startsWith('image/')) a,
    ];
    final documents = [
      for (final a in attachments)
        if (!(a.mediaType ?? '').startsWith('image/')) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, image) in images.indexed)
                  _ImageThumb(
                    attachment: image,
                    uploads: uploads,
                    // A download grant is a request of its own: the first
                    // few load by themselves, the rest when tapped.
                    autoLoad: index < 4,
                    size: dense ? 64 : 88,
                  ),
              ],
            ),
          ),
        if (documents.isNotEmpty)
          StoredAttachmentList(
            attachments: documents,
            uploads: uploads,
            dense: dense,
          ),
        if (links.isNotEmpty) ContentLinkList(links: links, openLink: openLink),
      ],
    );
  }
}

/// Image bytes already fetched this session, by file id, so a list that
/// rebuilds does not ask for a new grant each time.
final Map<String, Uint8List> _thumbnails = {};

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({
    required this.attachment,
    required this.uploads,
    required this.autoLoad,
    required this.size,
  });

  final StoredAttachment attachment;
  final FileUploadRepository? uploads;
  final bool autoLoad;
  final double size;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  bool _loading = false;
  bool _failed = false;

  Uint8List? get _bytes => _thumbnails[widget.attachment.id];

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<DownloadedFile?> _load() async {
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    if (uploads == null || !widget.attachment.isReady || _loading) return null;
    setState(() => _loading = true);
    try {
      final file = await uploads.download(widget.attachment.id);
      if (_thumbnails.length > 40) _thumbnails.remove(_thumbnails.keys.first);
      _thumbnails[widget.attachment.id] = file.bytes;
      if (mounted) setState(() => _failed = false);
      return file;
    } on Object {
      if (mounted) setState(() => _failed = true);
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final bytes = _bytes;
    final file = bytes != null
        ? DownloadedFile(
            displayName: widget.attachment.displayName,
            mediaType: widget.attachment.mediaType ?? 'image/jpeg',
            bytes: bytes,
          )
        : await _load();
    if (file == null || !mounted) return;
    await presentDownloadedFile(context, file);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final bytes = _bytes;
    final ready = widget.attachment.isReady;
    final Widget content;
    if (bytes != null) {
      content = Image.memory(
        bytes,
        fit: BoxFit.cover,
        cacheWidth: (widget.size * 3).round(),
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } else if (_loading) {
      content = const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else {
      content = Icon(
        !ready
            ? Icons.hourglass_empty_rounded
            : _failed
            ? Icons.broken_image_outlined
            : Icons.image_outlined,
        color: studafyMuted,
      );
    }
    return Semantics(
      button: ready,
      label:
          '${widget.attachment.displayName}. '
          '${!ready
              ? l10n.attachmentsChecking
              : _failed
              ? l10n.attachmentsNotAvailable
              : l10n.attachmentsImagePreview}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ready ? _open : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: widget.size,
            height: widget.size,
            color: studafyWash,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Titled links. A tap shows the site and asks first.
class ContentLinkList extends StatelessWidget {
  const ContentLinkList({super.key, required this.links, this.openLink});

  final List<ContentLink> links;
  final Future<bool> Function(Uri url)? openLink;

  Future<void> _confirmAndOpen(BuildContext context, ContentLink link) async {
    final uri = safeLink(link.url);
    if (uri == null) return;
    final l10n = AppL10n.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.linksOpenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              link.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(uri.host, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(uri.toString(), style: const TextStyle(fontSize: 12)),
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
    await open(uri);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final link in links)
        InkWell(
          onTap: () => _confirmAndOpen(context, link),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, size: 20, color: studafyNavy),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: studafyNavy,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Text(
                        Uri.tryParse(link.url)?.host ?? link.url,
                        style: const TextStyle(
                          color: studafyMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Where an editor is: what will change on save, and whether it can be
/// saved yet.
@immutable
class AttachmentsEditorValue {
  const AttachmentsEditorValue({
    this.changes = const AttachmentChanges(),
    this.uploading = false,
    this.failed = false,
  });

  final AttachmentChanges changes;

  /// A file is still on its way up: saving now would leave it behind.
  final bool uploading;

  /// A file failed to upload and has been neither retried nor removed.
  final bool failed;

  bool get ready => !uploading && !failed;
}

/// Adds, removes and replaces the files and titled links on one thing.
///
/// What is already attached can be removed (it is detached on save - kept
/// for the school, no longer shown); new files upload at once with their
/// progress, and can be retried or removed; links need a title. Replacing a
/// file is removing it and adding the new one.
class AttachmentsEditor extends StatefulWidget {
  const AttachmentsEditor({
    super.key,
    required this.purpose,
    required this.schoolId,
    this.uploads,
    this.source,
    this.classroomId,
    this.existingAttachments = const [],
    this.existingLinks = const [],
    this.onChanged,
    this.maxFiles = 5,
    this.maxLinks = 10,
    this.enabled = true,
    this.filesBlockedReason,
  });

  final FilePurpose purpose;

  /// The school the files are filed under; without it, and without
  /// [uploads], only links can be added.
  final String? schoolId;
  final FileUploadRepository? uploads;
  final AttachmentSource? source;
  final String? classroomId;
  final List<StoredAttachment> existingAttachments;
  final List<ContentLink> existingLinks;
  final ValueChanged<AttachmentsEditorValue>? onChanged;
  final int maxFiles;
  final int maxLinks;
  final bool enabled;

  /// Why files cannot be added yet - "choose the class first". The add
  /// buttons still show, so the teacher can see files are possible; a tap
  /// says this instead of picking a file.
  final String? filesBlockedReason;

  @override
  State<AttachmentsEditor> createState() => _AttachmentsEditorState();
}

class _AttachmentsEditorState extends State<AttachmentsEditor> {
  final Set<String> _detached = {};
  final Set<String> _removedLinks = {};
  final List<LinkDraft> _newLinks = [];
  List<Attachment> _uploads = const [];
  bool _showBlocked = false;

  int get _liveLinks =>
      widget.existingLinks.length - _removedLinks.length + _newLinks.length;

  void _emit() => widget.onChanged?.call(
    AttachmentsEditorValue(
      changes: AttachmentChanges(
        attachFileIds: [
          for (final item in _uploads)
            if (item.fileId != null &&
                (item.stage == AttachmentStage.ready ||
                    item.stage == AttachmentStage.quarantined))
              item.fileId!,
        ],
        detachFileIds: [..._detached],
        addLinks: [..._newLinks],
        removeLinkIds: [..._removedLinks],
      ),
      uploading: _uploads.any((a) => a.stage == AttachmentStage.uploading),
      failed: _uploads.any((a) => a.stage == AttachmentStage.failed),
    ),
  );

  Future<void> _addLink() async {
    final l10n = AppL10n.of(context);
    if (_liveLinks >= widget.maxLinks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.attachmentsTooManyLinks(widget.maxLinks))),
      );
      return;
    }
    final link = await showDialog<LinkDraft>(
      context: context,
      builder: (_) => const TitledLinkDialog(),
    );
    if (link == null || !mounted) return;
    setState(() => _newLinks.add(link));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final uploads = widget.uploads ?? UploadsScope.maybeOf(context);
    final schoolId = widget.schoolId;
    final keptFiles = widget.existingAttachments.length - _detached.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final file in widget.existingAttachments)
          _ExistingRow(
            icon: (file.mediaType ?? '').startsWith('image/')
                ? Icons.image_outlined
                : Icons.description_outlined,
            label: file.displayName,
            removed: _detached.contains(file.id),
            enabled: widget.enabled,
            onToggle: () {
              setState(() {
                if (!_detached.remove(file.id)) _detached.add(file.id);
              });
              _emit();
            },
          ),
        if (uploads != null && schoolId != null && widget.source != null)
          AttachmentField(
            purpose: widget.purpose,
            schoolId: schoolId,
            classroomId: widget.classroomId,
            uploads: uploads,
            source: widget.source!,
            maximumCount: (widget.maxFiles - keptFiles).clamp(
              0,
              widget.maxFiles,
            ),
            enabled: widget.enabled,
            onChanged: (items) {
              setState(() => _uploads = items);
              _emit();
            },
          )
        else if (uploads != null && widget.filesBlockedReason != null) ...[
          Row(
            children: [
              TextButton.icon(
                onPressed: widget.enabled
                    ? () => setState(() => _showBlocked = true)
                    : null,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(l10n.attachmentAttachFile),
              ),
              TextButton.icon(
                onPressed: widget.enabled
                    ? () => setState(() => _showBlocked = true)
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(l10n.attachmentPhoto),
              ),
            ],
          ),
          if (_showBlocked)
            Text(
              widget.filesBlockedReason!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
        for (final link in widget.existingLinks)
          _ExistingRow(
            icon: Icons.link_rounded,
            label: link.title,
            sublabel: Uri.tryParse(link.url)?.host,
            removed: _removedLinks.contains(link.id),
            enabled: widget.enabled,
            onToggle: () {
              setState(() {
                if (!_removedLinks.remove(link.id)) _removedLinks.add(link.id);
              });
              _emit();
            },
          ),
        for (final (index, link) in _newLinks.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link_rounded),
            title: Text(link.title),
            subtitle: Text(
              Uri.tryParse(link.url)?.host ?? link.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: l10n.attachmentsRemove,
              icon: const Icon(Icons.close_rounded),
              onPressed: widget.enabled
                  ? () {
                      setState(() => _newLinks.removeAt(index));
                      _emit();
                    }
                  : null,
            ),
          ),
        TextButton.icon(
          onPressed: widget.enabled ? _addLink : null,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(l10n.attachmentsAddLink),
        ),
      ],
    );
  }
}

class _ExistingRow extends StatelessWidget {
  const _ExistingRow({
    required this.icon,
    required this.label,
    required this.removed,
    required this.enabled,
    required this.onToggle,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final bool removed;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: removed ? studafyMuted : null),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          decoration: removed ? TextDecoration.lineThrough : null,
          color: removed ? studafyMuted : null,
        ),
      ),
      subtitle: removed
          ? Text(l10n.attachmentsRemovedOnSave)
          : sublabel == null
          ? null
          : Text(sublabel!),
      trailing: TextButton(
        onPressed: enabled ? onToggle : null,
        child: Text(removed ? l10n.attachmentsKeep : l10n.attachmentsRemove),
      ),
    );
  }
}

/// Asks for a link and the title readers will see.
class TitledLinkDialog extends StatefulWidget {
  const TitledLinkDialog({super.key});

  @override
  State<TitledLinkDialog> createState() => _TitledLinkDialogState();
}

class _TitledLinkDialogState extends State<TitledLinkDialog> {
  final _title = TextEditingController();
  final _url = TextEditingController();
  String? _titleError;
  String? _urlError;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppL10n.of(context);
    final link = safeLink(_url.text);
    final title = _title.text.trim();
    setState(() {
      _urlError = link == null ? l10n.linksInvalid : null;
      _titleError = title.isEmpty ? l10n.attachmentsLinkTitleRequired : null;
    });
    if (link == null || title.isEmpty) return;
    Navigator.pop(
      context,
      LinkDraft(
        title: title.length > 120 ? title.substring(0, 120) : title,
        url: link.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AlertDialog(
      title: Text(l10n.linksAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: l10n.attachmentsLinkAddress,
              hintText: 'https://',
              errorText: _urlError,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.attachmentsLinkTitle,
              errorText: _titleError,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
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
