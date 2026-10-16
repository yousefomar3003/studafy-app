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
  // variable. Re-enabling either capability requires a reviewed code change.
  //
  // AI grading stays hard-false: ADR-0026 removed it, and nothing here may
  // bring it back as a side effect.
  bool get allowsAiGrading => false;

  /// Uploads are on everywhere the app actually runs.
  ///
  /// FILE-050/051 shipped the whole pipeline - per-purpose media allowlists
  /// and size caps, quarantine, structural analysis, metadata stripping, and
  /// single-use user-bound delivery grants - and the client adapter was
  /// written but never wired. This is the reviewed change that wires it.
  ///
  /// Production is excluded and stays excluded: the worker refuses to run
  /// without an external malware provider, and none is contracted, so a
  /// production upload would fail closed anyway. Keeping it false here means
  /// the app never even offers the control.
  bool get allowsRemoteFileUploads =>
      environment != StudafyEnvironment.production;

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
