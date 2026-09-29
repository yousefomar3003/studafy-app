import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no client code updates notifications directly', () {
    // Read state is changed only through the /v1 API, which owns ownership
    // and timestamps; a direct table update would bypass both.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => file.readAsStringSync().contains(".from('notifications')"),
        )
        .map((file) => file.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
