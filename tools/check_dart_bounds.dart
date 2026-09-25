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
///
/// AUTH-030 migrated `account` behind AccountRepository/AccountInteractor, so
/// it is now enforced like every other feature.
const _legacyExemptFeatures = <String>{};

/// Core modules every zone may import.
const _coreAllowlist = <String>[
  'core/ids.dart',
  'core/class_join_link.dart',
  'core/secure_storage.dart',
  'core/account_lifecycle.dart',
  'core/failures.dart',
  'core/result.dart',
  'core/telemetry.dart',
  'core/studafy_domain.dart',
  'core/studafy_design.dart',
  // Named routes only - no widgets, no wiring. A screen must be able to say
  // where it is navigating to without importing lib/app, which is what the
  // composition-root rule below forbids.
  'core/app_routes.dart',
  'core/studafy_localizations.dart',
  'core/runtime_environment.dart',
  // MOB-070 localization (ADR-0028). The generated localizations are the one
  // source of interface copy, so every zone may read them; the port below is
  // how the composition root injects device-scoped settings.
  'l10n/generated/app_l10n.dart',
  'core/device_settings.dart',
  'core/locale_controller.dart',
  'core/language_picker.dart',
  // Renders text a person wrote, verbatim and in its own direction; every
  // slice that shows user content needs it (ADR-0028).
  'core/user_content_text.dart',
  'core/studafy_formatting.dart',
  // Attaching a document or photo is not one slice's concern: work is handed
  // in from academic, files ride along on a message or an announcement from
  // messaging, and a teacher files class material from the shell. The port,
  // the purpose policy, the shared control and its picker therefore live in
  // core, like user_content_text.dart above, rather than in a `files` feature
  // that every other feature would have to import.
  'core/file_upload_repository.dart',
  'core/attachment_policy.dart',
  'core/attachment_field.dart',
  'core/platform_attachment_source.dart',
  'core/uploads_scope.dart',
];

/// Data-layer-only imports: presentation and application may never touch
/// them (ARC-011 "slice contains no widget SQL/provider call").
const _dataOnlyImports = <String>[
  'studafy_database.dart',
  // The generated transport client and its HTTP adapter are data-layer:
  // presentation must go through a repository port, never call /v1 itself.
  'data/contracts/v1_client.generated.dart',
  'data/contracts/v1_http_transport.dart',
  // The typed /v1/billing client is a transport client too (PAY-071).
  'data/billing/v1_billing_api.dart',
  'data/secure/keychain_secure_store.dart',
  'data/secure/secure_session_storage.dart',
  'data/backend.dart',
  'data/supabase_repository.dart',
  'data/session_service.dart',
  'data/studafy_repository.dart',
  'data/subscription_service.dart',
  // MOB-070 local cache vNext: presentation/application must go through a
  // repository port, never touch the scoped cache, outbox, or its sqflite
  // handle directly.
  'data/local_cache/cache_scope.dart',
  'data/local_cache/offline_cache_database.dart',
  'data/local_cache/offline_cache_store.dart',
  'data/local_cache/mutation_outbox_engine.dart',
  'data/local_cache/session_cache_binder.dart',
  // MOB-070: the preference-store adapter. Presentation and application reach
  // device settings through DeviceSettingsStore, never the plugin.
  'data/settings/preferences_device_settings.dart',
];

/// Provider/persistence symbols are forbidden even when a Dart `part` file
/// inherits imports from its parent library. This closes the import-only
/// checker gap that could otherwise hide direct SQL/network calls in UI code.
const _dataOnlySymbols = <String>[
  'StudafyDatabase',
  'StudafyBackend',
  'Supabase.instance',
  '.rawQuery(',
  '.rawInsert(',
  '.rawUpdate(',
  '.rawDelete(',
  '.functions.invoke(',
  // Reaching an interactor's repository from a widget re-crosses the boundary
  // the interactor exists to hold (AUTH-030).
  'session.repository',
];

final _importPattern = RegExp(r"^import\s+'([^']+)'", multiLine: true);

void main(List<String> arguments) {
  final rootArgument = arguments
      .where((argument) => argument.startsWith('--root='))
      .firstOrNull;
  final root = Directory(
    rootArgument == null
        ? Directory.current.path
        : rootArgument.substring('--root='.length),
  ).absolute;
  final report = checkDartBoundaries(root.path);

  if (report.violations.isNotEmpty) {
    stderr.writeln(
      'architecture boundary violations (${report.violations.length}):\n'
      '${report.violations.join('\n')}',
    );
    exit(1);
  }

  stdout.writeln(
    'boundary check passed: ${report.checkedFiles} feature files, '
    '${_legacyExemptFeatures.length} legacy-exempt features, 0 violations',
  );
}

class DartBoundaryReport {
  const DartBoundaryReport({
    required this.checkedFiles,
    required this.violations,
  });

  final int checkedFiles;
  final List<String> violations;
}

DartBoundaryReport checkDartBoundaries(String rootPath) {
  final violations = <String>[];
  final root = Directory(rootPath).absolute;
  final featuresDir = Directory('${root.path}/lib/features');

  if (!featuresDir.existsSync()) {
    return const DartBoundaryReport(
      checkedFiles: 0,
      violations: ['lib/features not found'],
    );
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
      if (zone != 'data') {
        for (final symbol in _dataOnlySymbols) {
          if (source.contains(symbol)) {
            violations.add(
              '$relativePath: $zone uses data-layer symbol "$symbol" '
              '(persistence/provider calls are data-zone only)',
            );
          }
        }
      }
      for (final match in _importPattern.allMatches(source)) {
        final import = match.group(1)!;
        final violation = _check(
          import: import,
          featureName: featureName,
          zone: zone,
          rules: rules,
          filePath: relativePath,
          rootPath: root.path,
        );
        if (violation != null) violations.add(violation);
      }
    }
  }

  return DartBoundaryReport(
    checkedFiles: checkedFiles,
    violations: List.unmodifiable(violations),
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
  required String rootPath,
}) {
  if (import.startsWith('dart:')) {
    return null;
  }

  if (import.startsWith('package:') && !import.startsWith('package:studafy/')) {
    if (import.startsWith('package:flutter/')) return null;
    // AUTH-030 adapters: the identity provider SDK, the platform keystore,
    // native Sign in with Apple, and the hashing used to bind the Apple nonce.
    if (import.startsWith('package:supabase') ||
        import.startsWith('package:sqflite/') ||
        import.startsWith('package:flutter_secure_storage/') ||
        import.startsWith('package:sign_in_with_apple/') ||
        import.startsWith('package:crypto/')) {
      return zone == 'data'
          ? null
          : '$filePath: $zone imports provider package "$import" '
                '(provider packages are data-zone only)';
    }
    // Reviewed native Turnstile host: only the family's challenge view may
    // load the owned public widget page. API calls remain in the data layer.
    if (import.startsWith('package:webview_flutter/')) {
      return featureName == 'family' &&
              zone == 'presentation' &&
              filePath.endsWith('/family_challenge_page.dart')
          ? null
          : '$filePath: webview_flutter is restricted to the family challenge view';
    }
    if (import.startsWith('package:share_plus/') ||
        import.startsWith('package:intl/') ||
        import.startsWith('package:url_launcher/') ||
        import.startsWith('package:image_picker/') ||
        import.startsWith('package:file_picker/')) {
      return zone == 'presentation'
          ? null
          : '$filePath: $zone imports UI/platform package "$import" '
                '(UI/platform packages are presentation-zone only)';
    }
    return '$filePath: unreviewed third-party import "$import"';
  }

  final internalImport = _resolveInternalImport(
    import: import,
    filePath: filePath,
    rootPath: rootPath,
  );
  if (internalImport == null) {
    return '$filePath: could not resolve internal import "$import"';
  }

  // Core imports are always allowed.
  if (_coreAllowlist.any(internalImport.endsWith)) return null;

  // Data-only imports are banned outside the data zone.
  if (_dataOnlyImports.any(internalImport.endsWith)) {
    if (zone == 'data') return null;
    return '$filePath: $zone imports data-layer module "$internalImport" '
        '(only the data zone may touch persistence/provider code)';
  }

  final featureMatch = RegExp(r'^lib/features/([^/]+)/([^/]+)/')
      .firstMatch(internalImport);
  if (featureMatch != null) {
    final targetFeature = featureMatch.group(1)!;
    final target = featureMatch.group(2)!;
    if (targetFeature != featureName) {
      return '$filePath: cross-feature import "$internalImport" '
          '(features may not import each other)';
    }
    if (rules['deny']!.contains(target)) {
      return '$filePath: $zone imports $target '
          '(crossed the $zone boundary within feature "$featureName")';
    }
    if (target == zone || rules['allow']!.contains(target)) return null;
    return '$filePath: $zone imports $target '
        '(not in the allowlist for $zone)';
  }

  // Dependency direction is app -> features. Features never import wiring.
  if (internalImport.startsWith('lib/app/')) {
    return '$filePath: $zone imports the composition root '
        '"$internalImport" (feature code may not reference app wiring)';
  }

  return '$filePath: internal import "$internalImport" is not allowlisted';
}

String? _resolveInternalImport({
  required String import,
  required String filePath,
  required String rootPath,
}) {
  if (import.startsWith('package:studafy/')) {
    return 'lib/${import.substring('package:studafy/'.length)}';
  }
  if (import.contains(':')) return null;

  final resolved = File(filePath).parent.uri
      .resolve(import)
      .normalizePath()
      .toFilePath();
  final normalizedRoot = Directory(rootPath).absolute.path;
  final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
      ? normalizedRoot
      : '$normalizedRoot${Platform.pathSeparator}';
  if (!resolved.startsWith(prefix)) return null;
  return resolved
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}
