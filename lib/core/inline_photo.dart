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

  /// A photo whose type is read from its bytes. A phone's picker often names
  /// a PNG screenshot without its extension, so the name's type can be
  /// wrong; [named] is used only when the bytes are not a known image.
  factory InlinePhoto.fromBytes(Uint8List bytes, {required String named}) =>
      InlinePhoto(mediaType: sniffImageType(bytes) ?? named, bytes: bytes);

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

/// JPEG, PNG or WebP, as the bytes say, or null for anything else.
String? sniffImageType(Uint8List bytes) {
  bool starts(List<int> prefix) =>
      bytes.length >= prefix.length &&
      [for (var i = 0; i < prefix.length; i++) bytes[i] == prefix[i]]
          .every((same) => same);
  if (starts(const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}
