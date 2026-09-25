import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'attachment_policy.dart';
import 'attachment_field.dart';

/// The real picker.
///
/// Both branches are constrained to what the purpose allows, so the operating
/// system's own sheet does most of the filtering. The bytes are still checked
/// against the policy afterwards, because a picker's type filter is a
/// convenience and not a guarantee - a file can be renamed, and some
/// platforms honour the filter loosely.
Future<PickedAttachment?> pickPlatformAttachment(
  AttachmentKind kind,
  AttachmentPolicy policy,
) async {
  switch (kind) {
    case AttachmentKind.photo:
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Re-encoding at pick time drops most camera metadata before the
        // bytes ever leave the device. The server strips it again; this just
        // means the original was never sent.
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return PickedAttachment(
        displayName: sanitiseAttachmentName(picked.name),
        mediaType: _mediaTypeFor(picked.name, fallback: 'image/jpeg'),
        bytes: bytes,
      );

    case AttachmentKind.document:
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: policy.pickerExtensions,
      );
      if (file == null) return null;
      // Read here rather than carrying a path around: the upload adapter
      // takes bytes, and a path is a capability this layer should not pass on.
      final bytes = await file.readAsBytes();
      return PickedAttachment(
        displayName: sanitiseAttachmentName(file.name),
        mediaType: _mediaTypeFor(file.name),
        bytes: bytes,
      );
  }
}

/// Derived from the extension, never from a client-supplied type string.
///
/// The server re-derives it from the bytes themselves during structural
/// analysis and rejects a mismatch, so this only has to be right enough to
/// fail early on the obvious cases.
String _mediaTypeFor(String name, {String fallback = 'application/pdf'}) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return fallback;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => fallback,
  };
}
