import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/inline_photo.dart';

/// A photo sent with a request takes its type from its bytes (2026-10-21):
/// Android's picker names a PNG screenshot without its extension, and the
/// name's guess of "image/jpeg" was refused by the server.
void main() {
  Uint8List bytes(List<int> head) =>
      Uint8List.fromList([...head, ...List.filled(32, 0)]);

  test('a PNG labelled as a JPEG is sent as a PNG', () {
    final photo = InlinePhoto.fromBytes(
      bytes(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      named: 'image/jpeg',
    );
    expect(photo.mediaType, 'image/png');
    expect(photo.problem, isNull);
  });

  test('JPEG and WebP are recognised', () {
    expect(sniffImageType(bytes(const [0xff, 0xd8, 0xff])), 'image/jpeg');
    expect(
      sniffImageType(
        bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
      ),
      'image/webp',
    );
  });

  test('anything else keeps its name and is refused', () {
    final photo = InlinePhoto.fromBytes(
      bytes('%PDF'.codeUnits),
      named: 'application/pdf',
    );
    expect(photo.mediaType, 'application/pdf');
    expect(photo.problem, InlinePhotoProblem.type);
  });
}
