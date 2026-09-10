// ARC-011 architecture boundary checker (ADR-0012).
//
// Enforces the feature-folder import rules on every file under lib/features.
// Exit code 1 on any violation, so CI fails closed on boundary drift.
//
// Usage: dart run tools/check_dart_bounds.dart
import 'dart:io';

/// Which zones exist per feature folder, and what each may import.
const _zoneRules = <String, Map<String, List<String>>>{
  'presentation': {
    'allow': ['application', 'domain'],
    'deny': ['data'],
  },
  'application': {
    'allow': ['domain'],
    'deny': ['data', 'presentation'],
  },
  'domain': {
    'allow': [],
    'deny': ['data', 'presentation', 'application'],
  },
  'data': {
    'allow': ['domain'],
    'deny': ['presentation', 'application'],
  },
};

/// Legacy feature folders that are exempt until their slice migrates.
const _legacyExemptFeatures = <String>{'account'};

/// Core modules every zone may import.
const _coreAllowlist = <String>[
  'core/ids.dart',
  'core/failures.dart',
  'core/result.dart',
  'core/telemetry.dart',
  'core/studafy_domain.dart',
  'core/studafy_design.dart',
  'core/studafy_localizations.dart',
  'core/runtime_environment.dart',
];

/// Data-layer-only imports: presentation and application may never touch
/// them (ARC-011 "slice contains no widget SQL/provider call").
const _dataOnlyImports = <String>[
  'studafy_database.dart',
  'data/backend.dart',
  'data/supabase_repository.dart',
  'data/session_service.dart',
  'data/studafy_repository.dart',
];

final _importPattern = RegExp(
  r"^import\s+'(?:package:studafy/)?([^']+)'",
  multiLine: true,
);

void main() {
  final violations = <String>[];
  final featuresDir = Directory('lib/features');

  if (!featuresDir.existsSync()) {
    stderr.writeln('lib/features not found');
    exit(1);
  }

  var checkedFiles = 0;

  for (final featureDir in featuresDir.listSync()) {
    if (featureDir is! Directory) continue;
    final featureName = featureDir.path.split('/').last;

    // Legacy features are exempt until their slice migrates.
    if (_legacyExemptFeatures.contains(featureName)) continue;

    for (final entry in featureDir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final relativePath = entry.path;
      checkedFiles++;

      final zone = _zoneFor(relativePath);
      if (zone == null) continue;
      final rules = _zoneRules[zone]!;

      final source = entry.readAsStringSync();
      for (final match in _importPattern.allMatches(source)) {
        final import = match.group(1)!;
        final violation = _check(
          import: import,
          featureName: featureName,
          zone: zone,
          rules: rules,
          filePath: relativePath,
        );
        if (violation != null) violations.add(violation);
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln(
      'architecture boundary violations (${violations.length}):\n'
      '${violations.join('\n')}',
    );
    exit(1);
  }

  stdout.writeln(
    'boundary check passed: $checkedFiles feature files, '
    '${_legacyExemptFeatures.length} legacy-exempt features, 0 violations',
  );
}

String? _zoneFor(String path) {
  for (final zone in _zoneRules.keys) {
    if (path.contains('/$zone/')) return zone;
  }
  return null;
}

String? _check({
  required String import,
  required String featureName,
  required String zone,
  required Map<String, List<String>> rules,
  required String filePath,
}) {
  // Flutter/Dart SDK and third-party imports are always allowed.
  if (import.startsWith('package:flutter/') ||
      import.startsWith('package:sqflite/') ||
      import.startsWith('package:supabase') ||
      import.startsWith('package:share_plus/') ||
      import.startsWith('package:intl/') ||
      import.startsWith('package:url_launcher/') ||
      import.startsWith('package:image_picker/') ||
      import.startsWith('package:file_picker/') ||
      import.startsWith('dart:')) {
    return null;
  }

  // Core imports are always allowed.
  if (_coreAllowlist.any(import.endsWith)) return null;

  // Data-only imports are banned outside the data zone.
  if (_dataOnlyImports.any(import.endsWith)) {
    if (zone == 'data' && import.contains('studafy_database')) return null;
    if (zone == 'data' && import.contains('data/')) return null;
    return '$filePath: $zone imports data-layer module "$import" '
        '(only the data zone may touch persistence/provider code)';
  }

  // Same-feature imports: check zone rules.
  if (import.contains('features/$featureName/')) {
    final target = _zoneFor(import);
    if (target != null) {
      if (rules['deny']!.contains(target)) {
        return '$filePath: $zone imports $target '
            '(crossed the $zone boundary within feature "$featureName")';
      }
      if (target == zone || rules['allow']!.contains(target)) return null;
      return '$filePath: $zone imports $target '
          '(not in the allowlist for $zone)';
    }
    return null;
  }

  // Cross-feature imports are banned for all zones.
  if (import.contains('features/')) {
    return '$filePath: cross-feature import "$import" '
        '(features may not import each other)';
  }

  // Anything else under lib/ (app, other top-level) is not allowed in
  // feature zones except the composition root importing presentation.
  if (import.startsWith('app/')) {
    if (zone == 'presentation') return null;
    return '$filePath: $zone imports the composition root '
        '"$import" (only presentation may reference app wiring)';
  }

  return null;
}
