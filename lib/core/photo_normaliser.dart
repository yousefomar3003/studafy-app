import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'inline_photo.dart';

/// Every photo leaves the phone as a JPEG or a PNG (2026-11-03).
///
/// The server stores only JPEG and PNG photos, and the AI reads only JPEG,
/// PNG and WebP. Phones produce more than that: an iPhone shoots HEIC, the
/// Files app hands over whatever was saved (HEIC, HEIF, WebP, GIF, TIFF,
/// AVIF), and Android's photo picker passes some of these through as they
/// are. So a photo of any other kind is drawn again here, on the device, as
/// a JPEG no longer than [photoMaxLongEdge] on its longest side, and the
/// result is what is uploaded or sent.
///
/// A JPEG or PNG that already fits is sent exactly as picked: image_picker
/// has already made it small (2400 pixels, quality 85), and a teacher's PNG
/// diagram should not lose its sharp lines. One over the limit is drawn
/// again as a JPEG instead of being refused.
///
/// Hidden details: a converted photo carries none - the JPEG is written
/// without its EXIF block, and the picture is turned upright first so
/// nothing depends on an orientation tag. A photo sent as it was keeps
/// whatever the picker left, and the server removes it when it scans the
/// upload (the privacy policy's "hidden details are removed from photos"),
/// as it did before this change.
@immutable
class NormalisedPhoto {
  const NormalisedPhoto({
    required this.bytes,
    required this.mediaType,
    required this.converted,
  });

  final Uint8List bytes;

  /// `image/jpeg` or `image/png`, read from the bytes.
  final String mediaType;

  /// True when the bytes were drawn again here.
  final bool converted;

  /// The file extension for [mediaType], without the dot.
  String get extension => mediaType == 'image/png' ? 'png' : 'jpg';
}

/// A photo the phone could not turn into a JPEG: a format it has no decoder
/// for (HEIC on Android before 9), or a damaged file. Screens say so in
/// plain words rather than "could not be opened".
class PhotoConversionFailed implements Exception {
  const PhotoConversionFailed(this.sourceType, [this.cause]);

  /// What the bytes looked like (`image/heic`), or null when unknown.
  final String? sourceType;
  final Object? cause;

  @override
  String toString() =>
      'PhotoConversionFailed(${sourceType ?? 'unknown type'}'
      '${cause == null ? '' : ': $cause'})';
}

/// The longest side of a converted photo, the same as image_picker is asked
/// for when a photo is chosen or taken.
const photoMaxLongEdge = 2400;

/// JPEG quality of a converted photo, the same as image_picker's.
const photoJpegQuality = 85;

/// Draws [bytes] again as a JPEG. The platform plugin scales the picture
/// so that it is at least [minWidth] by [minHeight] (whichever is reached
/// first), never larger than it was. Injected so a test never touches a
/// platform channel.
typedef JpegConverter = Future<Uint8List> Function(
  Uint8List bytes, {
  required int minWidth,
  required int minHeight,
  required int quality,
});

/// The real converter: flutter_image_compress, which decodes with the
/// platform (UIImage on iOS, which reads HEIC, HEIF, WebP, GIF and TIFF;
/// BitmapFactory on Android, which reads HEIC from Android 9). Writes no
/// EXIF and turns the picture upright first.
Future<Uint8List> convertToJpegOnDevice(
  Uint8List bytes, {
  required int minWidth,
  required int minHeight,
  required int quality,
}) => FlutterImageCompress.compressWithList(
  bytes,
  minWidth: minWidth,
  minHeight: minHeight,
  quality: quality,
  format: CompressFormat.jpeg,
  keepExif: false,
  autoCorrectionAngle: true,
);

/// [bytes] as a JPEG or PNG the server and the AI accept.
///
/// A JPEG or PNG no larger than [passThroughBytes] comes back unchanged;
/// anything else is converted. Throws [PhotoConversionFailed] when it
/// cannot be.
Future<NormalisedPhoto> normalisePhoto(
  Uint8List bytes, {
  int passThroughBytes = InlinePhoto.maximumBytes,
  JpegConverter convert = convertToJpegOnDevice,
}) async {
  final type = sniffPhotoType(bytes);
  if ((type == 'image/jpeg' || type == 'image/png') &&
      bytes.length <= passThroughBytes) {
    return NormalisedPhoto(bytes: bytes, mediaType: type!, converted: false);
  }
  if (bytes.isEmpty) throw PhotoConversionFailed(type);
  try {
    var jpeg = await convert(
      bytes,
      minWidth: photoMaxLongEdge,
      minHeight: photoMaxLongEdge,
      quality: photoJpegQuality,
    );
    // The plugin bounds the shorter side, so a 4:3 photo comes back 3200
    // pixels long. Once more, sized by the longer side, brings it to the
    // same 2400 as a photo from the picker.
    final size = jpegSize(jpeg);
    if (size != null) {
      final longEdge = math.max(size.width, size.height);
      if (longEdge > photoMaxLongEdge) {
        final scale = photoMaxLongEdge / longEdge;
        jpeg = await convert(
          jpeg,
          minWidth: math.max(1, (size.width * scale).floor()),
          minHeight: math.max(1, (size.height * scale).floor()),
          quality: photoJpegQuality,
        );
      }
    }
    if (sniffImageType(jpeg) != 'image/jpeg') {
      throw PhotoConversionFailed(type, 'the converter did not return a JPEG');
    }
    return NormalisedPhoto(
      bytes: jpeg,
      mediaType: 'image/jpeg',
      converted: true,
    );
  } on PhotoConversionFailed {
    rethrow;
  } on Object catch (error) {
    throw PhotoConversionFailed(type, error);
  }
}

/// The kind of picture [bytes] hold, as the bytes say: the types
/// [sniffImageType] knows, plus HEIC, HEIF, AVIF, GIF, BMP and TIFF. Null
/// for anything else.
String? sniffPhotoType(Uint8List bytes) {
  final known = sniffImageType(bytes);
  if (known != null) return known;
  String ascii(int start, int end) =>
      bytes.length < end ? '' : String.fromCharCodes(bytes.sublist(start, end));
  // ISO base media: a box of type `ftyp`, then the major brand. Some
  // cameras put a generic major brand first and the real one in the
  // compatible brands that follow, so those are read too.
  if (ascii(4, 8) == 'ftyp') {
    final boxSize =
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    final end = math.min(bytes.length, math.max(16, boxSize));
    final brands = <String>[
      ascii(8, 12),
      for (var at = 16; at + 4 <= end; at += 4) ascii(at, at + 4),
    ];
    const heic = {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis'};
    if (brands.any(heic.contains)) return 'image/heic';
    if (brands.contains('avif') || brands.contains('avis')) {
      return 'image/avif';
    }
    if (brands.contains('mif1') || brands.contains('msf1')) {
      return 'image/heif';
    }
    return null;
  }
  if (ascii(0, 4) == 'GIF8') return 'image/gif';
  if (ascii(0, 2) == 'BM') return 'image/bmp';
  if (ascii(0, 4) == 'II*\u0000' || ascii(0, 4) == 'MM\u0000*') {
    return 'image/tiff';
  }
  return null;
}

/// Width and height of a JPEG, from its frame header; null when [bytes] is
/// not a JPEG or has no frame header.
({int width, int height})? jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  var at = 2;
  while (at + 4 <= bytes.length) {
    if (bytes[at] != 0xff) return null;
    final marker = bytes[at + 1];
    // Fill bytes, and markers that carry no length.
    if (marker == 0xff) {
      at += 1;
      continue;
    }
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd9)) {
      at += 2;
      continue;
    }
    final length = (bytes[at + 2] << 8) | bytes[at + 3];
    final isFrame =
        marker >= 0xc0 &&
        marker <= 0xcf &&
        marker != 0xc4 &&
        marker != 0xc8 &&
        marker != 0xcc;
    if (isFrame) {
      if (at + 9 > bytes.length) return null;
      final height = (bytes[at + 5] << 8) | bytes[at + 6];
      final width = (bytes[at + 7] << 8) | bytes[at + 8];
      return (width: width, height: height);
    }
    at += 2 + length;
  }
  return null;
}

/// [name] with its extension replaced by [extension] ("IMG_1204.HEIC" to
/// "IMG_1204.jpg"), or added when it has none.
String withPhotoExtension(String name, String extension) {
  final dot = name.lastIndexOf('.');
  final stem = dot <= 0 ? name : name.substring(0, dot);
  return '$stem.$extension';
}
