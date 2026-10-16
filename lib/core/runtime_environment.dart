import 'production_contract.dart';

enum StudafyEnvironment { synthetic, development, staging, production }

class RuntimePolicy {
  const RuntimePolicy(
    this.environment, {
    this.releaseDefines = compiledReleaseDefines,
  });

  final StudafyEnvironment environment;

  /// The defines a production build is checked against at start-up; the
  /// compiled ones unless a test supplies others.
  final Map<String, String> releaseDefines;

  factory RuntimePolicy.parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'synthetic' => const RuntimePolicy(StudafyEnvironment.synthetic),
      'development' => const RuntimePolicy(StudafyEnvironment.development),
      'staging' => const RuntimePolicy(StudafyEnvironment.staging),
      'production' => const RuntimePolicy(StudafyEnvironment.production),
      _ => throw FormatException(
        'APP_ENV must be synthetic, development, staging, or production.',
      ),
    };
  }

  factory RuntimePolicy.fromEnvironment() => RuntimePolicy.parse(
    const String.fromEnvironment('APP_ENV', defaultValue: 'synthetic'),
  );

  bool get isSynthetic => environment == StudafyEnvironment.synthetic;
  bool get requiresRemoteBackend => !isSynthetic;

  // SEC-001 containment is deliberately not controlled by an environment
  // variable. Changing either capability requires a reviewed code change.
  //
  // AI grading stays hard-false: ADR-0026 removed it, and nothing here may
  // bring it back as a side effect.
  bool get allowsAiGrading => false;

  /// Uploads are on everywhere the app runs, production included.
  ///
  /// FILE-050/051 shipped the whole pipeline - per-purpose media allowlists
  /// and size caps, upload intents, quarantine, structural analysis,
  /// metadata stripping, and single-use user-bound delivery grants - and
  /// the client adapter sends real bytes through it.
  ///
  /// Production was held back while no malware scanner existed. It has one
  /// now: the private ClamAV scanner `studafy-scanner` (fly.scanner.toml),
  /// which the production worker must reach before it scans anything, and
  /// the owner turned production uploads on on 2026-10-17 (DL-070). The
  /// protections are all server-side and stay: the API's
  /// FILE050_NEW_INTENTS_ENABLED / FILE051_PUBLISH_ENABLED /
  /// FILE051_DELIVERY_ENABLED and the worker's FILE051_SCAN_ENABLED are the
  /// kill switches, and nothing is delivered until the scan passes.
  bool get allowsRemoteFileUploads => true;

  /// What stops this production build from starting: every way its
  /// compiled defines miss the production contract. Empty outside
  /// production.
  List<String> get productionStartupProblems =>
      environment == StudafyEnvironment.production
      ? ProductionContract.problemsIn(releaseDefines)
      : const [];

  /// REL-002 (ADR-0044): production starts only with defines that match the
  /// production contract - the production API, Supabase project and legal
  /// pages, a publishable key, Turnstile on. The store build scripts refuse
  /// such a build before it compiles; this is the last line if one is made
  /// another way. Before the cutover production never started.
  bool get blocksApplicationStartup => productionStartupProblems.isNotEmpty;
}

abstract final class StudafyRuntime {
  static RuntimePolicy? _policy;

  static RuntimePolicy get policy =>
      _policy ??= RuntimePolicy.fromEnvironment();

  static void initialize(RuntimePolicy policy) {
    _policy = policy;
  }
}
