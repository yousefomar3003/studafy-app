import '../core/runtime_environment.dart';
import '../data/backend.dart';
import '../studafy_database.dart';
import 'app_dependencies.dart';

/// Owns runtime initialization so the Flutter entry point does not know about
/// storage/provider implementations.
abstract final class AppBootstrap {
  static Future<AppDependencies> initialize(RuntimePolicy policy) async {
    if (policy.requiresRemoteBackend) {
      if (!BackendConfig.fromEnvironment.isConfigured) {
        throw StateError(
          'Development and staging require an explicitly configured remote backend.',
        );
      }
      await StudafyBackend.initialize();
    }
    if (policy.isSynthetic) {
      await StudafyDatabase.instance.database;
    }
    return AppDependencies.forPolicy(policy);
  }
}
