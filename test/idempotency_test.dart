import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/idempotency.dart';

void main() {
  final serverFormat = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{15,127}$');

  test('every key is in the format the server accepts', () {
    for (var i = 0; i < 200; i++) {
      expect(newIdempotencyKey('join-code'), matches(serverFormat));
    }
    expect(generateUuidV4(), matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('a retried command keeps its key until it succeeds', () async {
    final keys = PendingIdempotencyKeys();
    final first = keys.keyFor('class', 'Maths|7|A');
    expect(keys.keyFor('class', 'Maths|7|A'), first);
    expect(keys.keyFor('class', 'Science|7|A'), isNot(first));

    final seen = <String>[];
    await expectLater(
      keys.run('class', 'Maths|7|A', (key) async {
        seen.add(key);
        throw StateError('timeout');
      }),
      throwsStateError,
    );
    await keys.run('class', 'Maths|7|A', (key) async => seen.add(key));
    // The failed attempt and its retry used the same key...
    expect(seen, [first, first]);
    // ...and once it succeeded the next command gets a new one.
    expect(keys.keyFor('class', 'Maths|7|A'), isNot(first));
  });
}
