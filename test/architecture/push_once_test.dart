import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every page is opened with `pushOnce`, so a repeated tap never stacks the
/// same page twice (lib/core/navigation.dart).
void main() {
  test('no screen pushes a page without the repeat-tap guard', () {
    final raw = RegExp(
      r'Navigator\.push\(|\bnavigator\.push[<(]|\)\s*\.push[<(]',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('generated') ||
          file.path.endsWith('core/navigation.dart')) {
        continue;
      }
      final text = file.readAsStringSync();
      if (raw.hasMatch(text)) offenders.add(file.path);
    }
    expect(offenders, isEmpty, reason: 'use Navigator.of(context).pushOnce');
  });
}
