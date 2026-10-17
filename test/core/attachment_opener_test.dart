import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_opener.dart';
import 'package:studafy/core/file_upload_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cache;
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    cache = Directory.systemTemp.createTempSync('attachment_opener_test');
    calls.clear();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(attachmentViewerChannel, null);
    cache.deleteSync(recursive: true);
  });

  final pdf = DownloadedFile(
    displayName: 'Worksheet',
    mediaType: 'application/pdf',
    bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
  );

  Future<bool> open(String name) =>
      openWithAndroidViewer(pdf, name, cacheDirectory: () async => cache);

  test(
    'writes the file under cache/attachments and asks Android to open it',
    () async {
      messenger.setMockMethodCallHandler(attachmentViewerChannel, (call) async {
        calls.add(call);
        return true;
      });

      expect(await open('Worksheet.pdf'), isTrue);

      expect(calls.single.method, 'open');
      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['type'], 'application/pdf');
      final path = args['path']! as String;
      expect(path, '${cache.path}/attachments/Worksheet.pdf');
      expect(File(path).readAsBytesSync(), pdf.bytes);
    },
  );

  test('a name cannot leave the attachments folder', () async {
    messenger.setMockMethodCallHandler(attachmentViewerChannel, (call) async {
      calls.add(call);
      return true;
    });

    await open('../../evil.pdf');

    final path = (calls.single.arguments as Map<Object?, Object?>)['path'];
    expect(path, '${cache.path}/attachments/evil.pdf');
  });

  test('only the latest file is kept', () async {
    messenger.setMockMethodCallHandler(
      attachmentViewerChannel,
      (call) async => true,
    );

    await open('First.pdf');
    await open('Second.pdf');

    expect(
      Directory('${cache.path}/attachments')
          .listSync()
          .map((entry) => entry.uri.pathSegments.last),
      ['Second.pdf'],
    );
  });

  test(
    'false when no app can open it, so the share sheet is offered',
    () async {
      messenger.setMockMethodCallHandler(
        attachmentViewerChannel,
        (call) async => false,
      );
      expect(await open('Worksheet.pdf'), isFalse);
    },
  );

  test('false when the channel is missing or fails', () async {
    expect(await open('Worksheet.pdf'), isFalse);

    messenger.setMockMethodCallHandler(
      attachmentViewerChannel,
      (call) async => throw PlatformException(code: 'boom'),
    );
    expect(await open('Worksheet.pdf'), isFalse);
  });
}
