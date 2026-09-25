enum StudafyEnvironment { synthetic, development, staging, production }

class RuntimePolicy {
  const RuntimePolicy(this.environment);

  final StudafyEnvironment environment;

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
  bool get requiresRemoteBackend =>
      environment == StudafyEnvironment.development ||
      environment == StudafyEnvironment.staging;

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

  // Production remains blocked while core repositories are local-only and the
  // native identity/signing work has not passed its later release gate.
  bool get blocksApplicationStartup =>
      environment == StudafyEnvironment.production;
}

abstract final class StudafyRuntime {
  static RuntimePolicy? _policy;

  static RuntimePolicy get policy =>
      _policy ??= RuntimePolicy.fromEnvironment();

  static void initialize(RuntimePolicy policy) {
    _policy = policy;
  }
}
