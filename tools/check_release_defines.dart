// REL-002 release defines check (ADR-0044).
//
// Decides whether a native release build may go ahead, from the dart-defines
// it will compile in. The rules are lib/core/production_contract.dart's.
//
//   APP_ENV=production   the production contract must pass
//   APP_ENV=development  allowed: the test copy, for internal testing
//                        (ADR-0042); no contract
//   anything else        refused: staging, synthetic, none, or a mix
//
// Used by the Xcode "Release Defines Check" build phase
// (scripts/release/ios-release-check.sh), Android Gradle's release check
// (android/app/build.gradle.kts, production only) and
// scripts/release/build-store.sh.
//
// Usage:
//   dart tools/check_release_defines.dart --platform android|ios \
//     --encoded "<base64 NAME=value list, as Flutter passes it>"
//   dart tools/check_release_defines.dart --platform android|ios \
//     --file config/dart-defines.production.json --build-number 1042
//
// Exit 0 when the build may go ahead; 1 with "error:" lines (which Xcode
// shows as build errors) when it may not; 2 on bad usage.
import 'dart:convert';
import 'dart:io';

import 'package:studafy/core/production_contract.dart';

void main(List<String> args) {
  String? platform;
  String? encoded;
  String? file;
  String? buildNumber;
  for (var i = 0; i < args.length; i++) {
    final next = i + 1 < args.length ? args[i + 1] : null;
    switch (args[i]) {
      case '--platform':
        platform = next;
      case '--encoded':
        encoded = next;
      case '--file':
        file = next;
      case '--build-number':
        buildNumber = next;
      default:
        _usage('unknown argument ${args[i]}');
    }
    i++;
  }
  if (platform != 'android' && platform != 'ios') {
    _usage('--platform must be android or ios');
  }
  if ((encoded == null) == (file == null)) {
    _usage('give exactly one of --encoded or --file');
  }

  final Map<String, List<String>> defines;
  try {
    defines = encoded != null
        ? decodeFlutterDartDefines(encoded)
        : _fromFile(file!, buildNumber);
  } on FormatException catch (error) {
    _refuse(['the dart-defines could not be read: ${error.message}']);
  } on FileSystemException catch (error) {
    _refuse(['${error.path ?? file}: ${error.message}']);
  }

  final appEnvs = defines['APP_ENV'] ?? const <String>[];
  if (appEnvs.isNotEmpty && appEnvs.every((env) => env == 'development')) {
    stdout.writeln(
      'Release defines: development test copy (ADR-0042); '
      'not a production build.',
    );
    return;
  }
  if (appEnvs.isEmpty || appEnvs.any((env) => env != 'production')) {
    final given = appEnvs.isEmpty ? 'none' : appEnvs.join(', ');
    _refuse([
      'REL-002: a release build must be APP_ENV=production (store) or '
          'APP_ENV=development (internal testing of the test copy); '
          'APP_ENV given: $given.',
    ]);
  }
  final problems = ProductionContract.problems(defines, platform: platform);
  if (problems.isNotEmpty) {
    _refuse([
      'REL-002: this production build does not match the production '
          'defines contract (lib/core/production_contract.dart):',
      ...problems.map((problem) => '  - $problem'),
    ]);
  }
  stdout.writeln('Release defines: production contract passed ($platform).');
}

/// A `--dart-define-from-file` JSON file, read the way the Flutter tool
/// reads it, plus the build number it would add.
Map<String, List<String>> _fromFile(String path, String? buildNumber) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('the file must hold one JSON object');
  }
  return {
    for (final entry in decoded.entries) entry.key: ['${entry.value}'],
    if (buildNumber != null) 'FLUTTER_BUILD_NUMBER': [buildNumber],
  };
}

Never _refuse(List<String> lines) {
  for (final line in lines) {
    stderr.writeln('error: $line');
  }
  exit(1);
}

Never _usage(String message) {
  stderr.writeln('error: $message');
  stderr.writeln(
    'usage: dart tools/check_release_defines.dart --platform android|ios '
    '(--encoded <list> | --file <json> [--build-number <n>])',
  );
  exit(2);
}
