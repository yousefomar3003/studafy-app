import 'dart:math';

/// Client-made identifiers: UUIDs and idempotency keys.

/// RFC 4122 version-4 UUID, made on the device so a queued or retried
/// command has a stable identity before it has ever reached the server.
///
/// Pass [random] only in tests that need a fixed sequence.
String generateUuidV4({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// A new idempotency key for one command.
///
/// [operation] names what is being done (`class`, `join-code`), which makes a
/// key readable in a server log; it must start with a letter, as the server
/// requires keys to start with a letter or digit.
String newIdempotencyKey(String operation) {
  assert(RegExp(r'^[A-Za-z][A-Za-z0-9._:-]{0,60}$').hasMatch(operation));
  return '$operation-${generateUuidV4()}';
}

/// Idempotency keys for commands a person may retry.
///
/// A command keeps its key until it succeeds, so pressing Save again after a
/// timeout replays the first attempt on the server instead of doing the work
/// twice. A different command - different [fingerprint] - gets its own key.
class PendingIdempotencyKeys {
  final Map<String, String> _pending = {};

  /// The key for this command: the same one until [completed] is called.
  String keyFor(String operation, String fingerprint) => _pending.putIfAbsent(
    '$operation|$fingerprint',
    () => newIdempotencyKey(operation),
  );

  /// Forgets the key once the server has accepted the command.
  void completed(String operation, String fingerprint) =>
      _pending.remove('$operation|$fingerprint');

  /// Runs [command] with this command's key, and forgets the key only if it
  /// succeeded.
  Future<T> run<T>(
    String operation,
    String fingerprint,
    Future<T> Function(String key) command,
  ) async {
    final result = await command(keyFor(operation, fingerprint));
    completed(operation, fingerprint);
    return result;
  }
}
