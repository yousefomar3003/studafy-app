import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A photo or screenshot sent with a request itself (ADR-0045).
///
/// A student who is in no class has no school to upload into, so their
/// photos go to the AI with the question, or with the request for notes.
/// The server checks one, draws it again and reads it once; it is never
/// stored. A student in a class uploads as before.
@immutable
class InlinePhoto {
  const InlinePhoto({required this.mediaType, required this.bytes});

  final String mediaType;
  final Uint8List bytes;

  /// The image types the server reads.
  static const mediaTypes = {'image/jpeg', 'image/png', 'image/webp'};

  /// The most the server takes for one image: a full-size screenshot.
  static const maximumBytes = 4000000;

  /// Why this photo cannot be sent, or null when it can.
  InlinePhotoProblem? get problem {
    if (!mediaTypes.contains(mediaType)) return InlinePhotoProblem.type;
    if (bytes.length > maximumBytes) return InlinePhotoProblem.size;
    return null;
  }

  Map<String, Object?> toJson() => {
    'mediaType': mediaType,
    'data': base64Encode(bytes),
  };
}

enum InlinePhotoProblem {
  /// Not a JPEG, PNG or WebP image.
  type,

  /// Larger than [InlinePhoto.maximumBytes].
  size,
}
