import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/attachment_policy.dart';
import 'package:studafy/core/photo_normaliser.dart';
import 'package:studafy/core/platform_attachment_source.dart';

/// Every photo leaves the phone as a JPEG or PNG (2026-11-03): an iPhone's
/// HEIC or a WebP from the Files app is drawn again as a JPEG first. The
/// converter is a fake that records what it was asked.
void main() {
  Uint8List withHead(List<int> head, [int length = 64]) =>
      Uint8List.fromList([...head, ...List.filled(length - head.length, 0)]);

  Uint8List ftyp(String brand, [List<String> compatible = const []]) {
    final size = 16 + 4 * compatible.length;
    return withHead([
      0,
      0,
      0,
      size,
      ...'ftyp'.codeUnits,
      ...brand.codeUnits,
      0,
      0,
      0,
      0,
      for (final b in compatible) ...b.codeUnits,
    ]);
  }

  final heic = ftyp('heic', ['mif1', 'heic']);
  final heifGeneric = ftyp('mif1', ['heic']);
  final webp = withHead([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]);
  final png = withHead(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

  /// A JPEG of the given size: start of image, then a baseline frame header.
  Uint8List jpeg(int width, int height) => Uint8List.fromList([
    0xff, 0xd8, // SOI
    0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, // APP0, empty
    0xff, 0xc0, 0x00, 0x11, 0x08, // SOF0, length 17, 8 bits
    height >> 8, height & 0xff, width >> 8, width & 0xff,
    ...List.filled(10, 0),
    0xff, 0xd9, // EOI
  ]);

  group('normalisePhoto', () {
    late List<({int bytes, int minWidth, int minHeight, int quality})> calls;
    late List<Uint8List> outputs;

    Future<Uint8List> fakeConvert(
      Uint8List bytes, {
      required int minWidth,
      required int minHeight,
      required int quality,
    }) async {
      calls.add((
        bytes: bytes.length,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      ));
      return outputs.removeAt(0);
    }

    setUp(() {
      calls = [];
      outputs = [];
    });

    test('a HEIC becomes a JPEG', () async {
      outputs.add(jpeg(2400, 1800));
      final photo = await normalisePhoto(heic, convert: fakeConvert);
      expect(photo.mediaType, 'image/jpeg');
      expect(photo.extension, 'jpg');
      expect(photo.converted, isTrue);
      expect(photo.bytes, jpeg(2400, 1800));
      expect(calls.single, (
        bytes: heic.length,
        minWidth: photoMaxLongEdge,
        minHeight: photoMaxLongEdge,
        quality: photoJpegQuality,
      ));
    });

    test('a WebP becomes a JPEG', () async {
      outputs.add(jpeg(800, 600));
      final photo = await normalisePhoto(webp, convert: fakeConvert);
      expect(photo.mediaType, 'image/jpeg');
      expect(calls, hasLength(1));
    });

    test('a JPEG and a PNG that fit pass through untouched', () async {
      final small = jpeg(1200, 900);
      final asJpeg = await normalisePhoto(small, convert: fakeConvert);
      expect(identical(asJpeg.bytes, small), isTrue);
      expect(asJpeg.mediaType, 'image/jpeg');
      expect(asJpeg.converted, isFalse);

      final asPng = await normalisePhoto(png, convert: fakeConvert);
      expect(asPng.mediaType, 'image/png');
      expect(asPng.extension, 'png');
      expect(calls, isEmpty);
    });

    test('a JPEG over the limit is made smaller instead', () async {
      outputs.add(jpeg(2400, 1800));
      final big = Uint8List.fromList([
        ...jpeg(6000, 4500),
        ...List.filled(64, 0),
      ]);
      final photo = await normalisePhoto(
        big,
        passThroughBytes: 32,
        convert: fakeConvert,
      );
      expect(photo.converted, isTrue);
      expect(calls, hasLength(1));
    });

    test('the longer side ends at 2400, as from the picker', () async {
      // The plugin bounds the shorter side first: 4032 x 3024 comes back
      // 3200 x 2400, and is drawn once more by its longer side.
      outputs
        ..add(jpeg(3200, 2400))
        ..add(jpeg(2400, 1800));
      final photo = await normalisePhoto(heic, convert: fakeConvert);
      expect(calls, hasLength(2));
      expect(calls.last.minWidth, 2400);
      expect(calls.last.minHeight, 1800);
      expect(jpegSize(photo.bytes), (width: 2400, height: 1800));
    });

    test('a converter that fails gives a clear error', () async {
      Future<Uint8List> broken(
        Uint8List bytes, {
        required int minWidth,
        required int minHeight,
        required int quality,
      }) async => throw UnsupportedError('no HEIC decoder');

      await expectLater(
        normalisePhoto(heic, convert: broken),
        throwsA(
          isA<PhotoConversionFailed>()
              .having((e) => e.sourceType, 'sourceType', 'image/heic')
              .having((e) => e.cause, 'cause', isA<UnsupportedError>()),
        ),
      );
    });

    test(
      'a converter that returns something other than a JPEG fails',
      () async {
        outputs.add(png);
        await expectLater(
          normalisePhoto(heic, convert: fakeConvert),
          throwsA(isA<PhotoConversionFailed>()),
        );
      },
    );

    test('nothing at all cannot be converted', () async {
      await expectLater(
        normalisePhoto(Uint8List(0), convert: fakeConvert),
        throwsA(isA<PhotoConversionFailed>()),
      );
      expect(calls, isEmpty);
    });
  });

  group('a file chosen by name', () {
    Future<Uint8List> toJpeg(
      Uint8List bytes, {
      required int minWidth,
      required int minHeight,
      required int quality,
    }) async => jpeg(1000, 750);

    test('a HEIC from the Files app is uploaded as IMG.jpg', () async {
      final picked = await normalisePickedFile(
        PickedAttachment(
          displayName: 'IMG_1204.HEIC',
          mediaType: 'image/heic',
          bytes: heifGeneric,
        ),
        AttachmentPolicy.assignmentSubmission,
        convert: toJpeg,
      );
      expect(picked.displayName, 'IMG_1204.jpg');
      expect(picked.mediaType, 'image/jpeg');
      expect(
        AttachmentPolicy.assignmentSubmission.refuse(
          mediaType: picked.mediaType,
          sizeBytes: picked.bytes.length,
        ),
        isNull,
      );
    });

    test('a PDF, and a PNG within the limit, are left alone', () async {
      final pdf = PickedAttachment(
        displayName: 'Worksheet.pdf',
        mediaType: 'application/pdf',
        bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
      );
      expect(
        identical(
          await normalisePickedFile(
            pdf,
            AttachmentPolicy.lessonResource,
            convert: toJpeg,
          ),
          pdf,
        ),
        isTrue,
      );

      final diagram = await normalisePickedFile(
        PickedAttachment(
          displayName: 'Diagram.png',
          mediaType: 'image/png',
          bytes: png,
        ),
        AttachmentPolicy.lessonResource,
        convert: toJpeg,
      );
      expect(diagram.displayName, 'Diagram.png');
      expect(diagram.bytes, png);
    });
  });

  group('sniffPhotoType', () {
    test('reads HEIC, HEIF, AVIF, WebP, GIF, BMP and TIFF from the bytes', () {
      expect(sniffPhotoType(heic), 'image/heic');
      expect(sniffPhotoType(heifGeneric), 'image/heic');
      expect(sniffPhotoType(ftyp('mif1')), 'image/heif');
      expect(sniffPhotoType(ftyp('avif')), 'image/avif');
      expect(sniffPhotoType(ftyp('isom')), isNull); // a video
      expect(sniffPhotoType(webp), 'image/webp');
      expect(sniffPhotoType(withHead('GIF89a'.codeUnits)), 'image/gif');
      expect(sniffPhotoType(withHead('BM'.codeUnits)), 'image/bmp');
      expect(sniffPhotoType(withHead('II*\u0000'.codeUnits)), 'image/tiff');
      expect(sniffPhotoType(jpeg(1, 1)), 'image/jpeg');
      expect(sniffPhotoType(Uint8List.fromList('%PDF'.codeUnits)), isNull);
    });
  });

  test('jpegSize reads the frame header', () {
    expect(jpegSize(jpeg(4032, 3024)), (width: 4032, height: 3024));
    expect(jpegSize(png), isNull);
  });

  test('withPhotoExtension swaps or adds the extension', () {
    expect(withPhotoExtension('IMG_1204.HEIC', 'jpg'), 'IMG_1204.jpg');
    expect(withPhotoExtension('scan', 'jpg'), 'scan.jpg');
    expect(withPhotoExtension('my.photo.webp', 'jpg'), 'my.photo.jpg');
  });
}
