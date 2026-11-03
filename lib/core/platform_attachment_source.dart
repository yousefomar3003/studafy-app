import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'attachment_field.dart';
import 'attachment_policy.dart';
import 'inline_photo.dart';
import 'photo_normaliser.dart';

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
    case AttachmentKind.camera:
      final picked = await ImagePicker().pickImage(
        source: kind == AttachmentKind.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // The picker draws the photo again at this size: a JPEG on iOS
        // whatever the original was (HEIC, WebP), and a JPEG or PNG on
        // Android when it can decode the original. What it leaves in another
        // format is converted below. Hidden details are removed by the server
        // when it scans the upload, and a converted photo never had them.
        imageQuality: photoJpegQuality,
        maxWidth: photoMaxLongEdge.toDouble(),
        maxHeight: photoMaxLongEdge.toDouble(),
      );
      if (picked == null) return null;
      final photo = await normalisePhoto(
        await picked.readAsBytes(),
        passThroughBytes: _photoPassThroughBytes(policy),
      );
      // The picker's file name is its own ("scaled_21.jpg",
      // "image_picker_….jpg"); the photo is named by when it was picked, and
      // the screen puts that in the person's language.
      final now = DateTime.now();
      return PickedAttachment(
        displayName: photoAttachmentName(now, extension: photo.extension),
        mediaType: photo.mediaType,
        bytes: photo.bytes,
        photoTakenAt: now,
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
      return normalisePickedFile(
        PickedAttachment(
          displayName: sanitiseAttachmentName(file.name),
          mediaType: _mediaTypeFor(file.name),
          bytes: bytes,
        ),
        policy,
      );
  }
}

/// A file chosen by name that turns out to be a photo, as a JPEG or PNG
/// the server stores: a HEIC or WebP from the Files app becomes
/// "IMG_1204.jpg". Anything that is not a photo is returned as it is.
///
/// A JPEG or PNG within [policy]'s size limit is uploaded exactly as chosen,
/// as before; one over it is made smaller rather than refused.
Future<PickedAttachment> normalisePickedFile(
  PickedAttachment picked,
  AttachmentPolicy policy, {
  JpegConverter convert = convertToJpegOnDevice,
}) async {
  final photoType = sniffPhotoType(picked.bytes);
  final namedAsPhoto = picked.mediaType.startsWith('image/');
  if (photoType == null && !namedAsPhoto) return picked;
  if (!policy.allowedMediaTypes.contains('image/jpeg')) return picked;
  final photo = await normalisePhoto(
    picked.bytes,
    passThroughBytes: policy.maximumSizeBytes,
    convert: convert,
  );
  return PickedAttachment(
    displayName: photo.converted
        ? withPhotoExtension(picked.displayName, photo.extension)
        : picked.displayName,
    mediaType: photo.mediaType,
    bytes: photo.bytes,
    photoTakenAt: picked.photoTakenAt,
  );
}

/// The most a photo from the camera or the library may weigh before it is
/// made smaller: the purpose's limit, and never more than the AI takes, so
/// the same photo works for a class and for the AI Tutor.
int _photoPassThroughBytes(AttachmentPolicy policy) =>
    policy.maximumSizeBytes < InlinePhoto.maximumBytes
    ? policy.maximumSizeBytes
    : InlinePhoto.maximumBytes;

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
    'm4a' => 'audio/mp4',
    'jpg' || 'jpeg' => 'image/jpeg',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'docx' => AttachmentPolicy.docx,
    'pptx' => AttachmentPolicy.pptx,
    'xlsx' => AttachmentPolicy.xlsx,
    'csv' => AttachmentPolicy.csv,
    _ => fallback,
  };
}
