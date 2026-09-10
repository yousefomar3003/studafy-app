import 'package:flutter/foundation.dart';

/// PII-safe client telemetry (ARC-011). Implementations must never receive
/// or emit personal data: no emails, names, ids of children, or message
/// content — only counts, phases, and machine codes.
abstract interface class Telemetry {
  void event(String name, [Map<String, Object?> fields]);
}

/// Emits one JSON line per event in debug builds; silent in profile/release.
class DebugLogTelemetry implements Telemetry {
  const DebugLogTelemetry();

  @override
  void event(String name, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    debugPrint(
      '{"telemetry":"${JsonName.encode(name)}"'
      '${fields.isEmpty ? '' : ',${_encodeFields(fields)}'}}',
    );
  }

  static String _encodeFields(Map<String, Object?> fields) => fields.entries
      .map((e) => '"${JsonName.encode(e.key)}":${_encodeValue(e.value)}')
      .join(',');

  static String _encodeValue(Object? value) => switch (value) {
    null => 'null',
    bool b => '$b',
    int i => '$i',
    double d => '$d',
    String s => '"${JsonName.encode(s)}"',
    _ => '"${JsonName.encode(value.toString())}"',
  };
}

/// Awaits nothing, records nothing. Used by tests.
class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  void event(String name, [Map<String, Object?> fields = const {}]) {}
}

/// Minimal JSON string escaping without dart:convert overhead.
extension JsonName on String {
  static String encode(String raw) => raw
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}
