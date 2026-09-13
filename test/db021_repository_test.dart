import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification mutation uses the bounded DB-021 RPC', () {
    final source = File('lib/data/supabase_repository.dart').readAsStringSync();

    expect(source, contains(".rpc('mark_notifications_read')"));
    expect(
      source,
      isNot(contains(".from('notifications')\n        .update")),
      reason: 'callers must not control notification ownership or timestamps',
    );
  });
}
