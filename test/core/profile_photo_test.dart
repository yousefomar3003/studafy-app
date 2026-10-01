import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/profile_photo.dart';

/// Profile photos stay on the device, one per account, and go with it.
void main() {
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('profile_photos');
    ProfilePhotos.folderOverride = folder;
  });

  tearDown(() async {
    ProfilePhotos.folderOverride = null;
    await folder.delete(recursive: true);
  });

  test('each account has its own photo, removed with that account', () async {
    final first = Uint8List.fromList([1, 2, 3]);
    final second = Uint8List.fromList([4, 5]);
    await ProfilePhotos.save('account-a', first);
    await ProfilePhotos.save('account-b', second);

    expect(await ProfilePhotos.read('account-a'), first);
    expect(await ProfilePhotos.read('account-b'), second);
    // Named by a hash, not by the account id.
    final names = folder
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last);
    expect(names.any((name) => name.contains('account-a')), isFalse);

    await ProfilePhotos.delete('account-a');
    expect(await ProfilePhotos.read('account-a'), isNull);
    expect(await ProfilePhotos.read('account-b'), second);
  });
}
