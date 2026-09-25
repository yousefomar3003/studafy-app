import 'file_upload_repository.dart';

/// The client half of `public.file_purpose_policies`.
///
/// The server is the authority and re-checks everything here; this copy
/// exists so a file that was never going to be accepted is refused while the
/// person is still looking at the picker, instead of after an upload intent,
/// a signed PUT and a quarantine row have already been spent on it.
///
/// Keep the numbers identical to the migration. A client that is *stricter*
/// than the server only annoys people; a client that is *looser* sends bytes
/// that the pipeline will reject, which is a wasted round trip, not a hole -
/// nothing here is a security control on its own.
class AttachmentPolicy {
  const AttachmentPolicy({
    required this.purpose,
    required this.maximumSizeBytes,
    required this.allowedMediaTypes,
  });

  final FilePurpose purpose;
  final int maximumSizeBytes;

  /// Media types the server will accept for this purpose, lowercased.
  ///
  /// Deliberately not a superset of what phones can produce. Office formats
  /// are absent because the pipeline has no structural parser for a zip
  /// container and no signature-grade malware engine behind it, so a .docx
  /// would be quarantined and never released. Offering it would be a button
  /// that always fails.
  final Set<String> allowedMediaTypes;

  static const _image = {'image/jpeg', 'image/png'};
  static const _document = {'application/pdf'};

  static const profileImage = AttachmentPolicy(
    purpose: FilePurpose.profileImage,
    maximumSizeBytes: 5 * 1024 * 1024,
    allowedMediaTypes: {'image/jpeg', 'image/png', 'image/webp'},
  );
  static const lessonResource = AttachmentPolicy(
    purpose: FilePurpose.lessonResource,
    maximumSizeBytes: 25 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );
  static const assignmentMaterial = AttachmentPolicy(
    purpose: FilePurpose.assignmentMaterial,
    maximumSizeBytes: 10 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );
  static const assignmentSubmission = AttachmentPolicy(
    purpose: FilePurpose.assignmentSubmission,
    maximumSizeBytes: 10 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );
  static const paperScan = AttachmentPolicy(
    purpose: FilePurpose.paperScan,
    maximumSizeBytes: 25 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );

  /// Deliberately the smallest ceiling: chat is the least supervised place
  /// anything is uploaded, and the migration sets the same 5 MB server-side.
  static const messageAttachment = AttachmentPolicy(
    purpose: FilePurpose.messageAttachment,
    maximumSizeBytes: 5 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );
  static const announcementAttachment = AttachmentPolicy(
    purpose: FilePurpose.announcementAttachment,
    maximumSizeBytes: 10 * 1024 * 1024,
    allowedMediaTypes: {..._document, ..._image},
  );

  static AttachmentPolicy of(FilePurpose purpose) => switch (purpose) {
    FilePurpose.profileImage => profileImage,
    FilePurpose.lessonResource => lessonResource,
    FilePurpose.assignmentMaterial => assignmentMaterial,
    FilePurpose.assignmentSubmission => assignmentSubmission,
    FilePurpose.paperScan => paperScan,
    FilePurpose.messageAttachment => messageAttachment,
    FilePurpose.announcementAttachment => announcementAttachment,
  };

  /// The extensions to hand a file picker, derived from the media types so
  /// the two can never disagree.
  List<String> get pickerExtensions => [
    for (final type in allowedMediaTypes)
      switch (type) {
        'application/pdf' => 'pdf',
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => '',
      },
  ]..removeWhere((value) => value.isEmpty);

  AttachmentRefusal? refuse({
    required String mediaType,
    required int sizeBytes,
  }) {
    if (sizeBytes <= 0) return AttachmentRefusal.empty;
    if (!allowedMediaTypes.contains(mediaType.trim().toLowerCase())) {
      return AttachmentRefusal.mediaType;
    }
    if (sizeBytes > maximumSizeBytes) return AttachmentRefusal.tooLarge;
    return null;
  }
}

enum AttachmentRefusal { empty, mediaType, tooLarge }

/// Reduces a picked filename to something safe to store, log and echo back.
///
/// The server sanitises independently - this is not the control that stops a
/// traversal - but a name travels through an upload intent, a database row
/// and a `Content-Disposition` header, and it is cheaper to make it boring
/// here than to explain later why a filename ever contained a path.
///
/// Keeps: letters (any script, so Arabic names survive), digits, space, dot,
/// dash, underscore, brackets. Everything else becomes an underscore.
String sanitiseAttachmentName(String raw, {String fallback = 'attachment'}) {
  // Any path syntax is dropped entirely rather than escaped: the last segment
  // is the only part that was ever a filename.
  final lastSegment = raw.split(RegExp(r'[/\\]')).last;
  // A leading dot would make it hidden and, with the rest stripped, could
  // leave a name that is only an extension.
  final collapsed = lastSegment
      .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ._\-()\[\]]', unicode: true), '_')
      .replaceAll(RegExp(r'_{2,}'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .trim();
  final trimmed = collapsed.replaceAll(RegExp(r'^[._\s]+'), '');
  if (trimmed.isEmpty || trimmed == '.') return fallback;
  // Long names are a storage and header problem, not a safety one, but the
  // extension is the part worth keeping when something has to go.
  if (trimmed.length <= 120) return trimmed;
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0 || trimmed.length - dot > 12) return trimmed.substring(0, 120);
  final extension = trimmed.substring(dot);
  return trimmed.substring(0, 120 - extension.length) + extension;
}
