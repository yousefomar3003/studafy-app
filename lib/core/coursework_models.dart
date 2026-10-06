import 'package:flutter/foundation.dart';

/// The pieces every coursework attachment shares (ADR-0036): titled links,
/// and what changes on something's files and links when it is saved.

/// A titled link a teacher put on a lesson, work, a question or a grade.
@immutable
class ContentLink {
  const ContentLink({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final String url;
}

/// A link to add: a title the reader sees, and where it goes.
@immutable
class LinkDraft {
  const LinkDraft({required this.title, required this.url});

  final String title;
  final String url;
}

/// What changes on something's attachments: files and links added, and
/// those taken off (kept for the school, no longer shown).
@immutable
class AttachmentChanges {
  const AttachmentChanges({
    this.attachFileIds = const [],
    this.detachFileIds = const [],
    this.addLinks = const [],
    this.removeLinkIds = const [],
  });

  final List<String> attachFileIds;
  final List<String> detachFileIds;
  final List<LinkDraft> addLinks;
  final List<String> removeLinkIds;

  bool get isEmpty =>
      attachFileIds.isEmpty &&
      detachFileIds.isEmpty &&
      addLinks.isEmpty &&
      removeLinkIds.isEmpty;
}
