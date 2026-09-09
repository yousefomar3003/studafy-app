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
  bool get allowsAiGrading => false;
  bool get allowsRemoteFileUploads => false;

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
