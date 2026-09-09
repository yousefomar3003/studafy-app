import 'package:supabase_flutter/supabase_flutter.dart';

class BackendConfig {
  const BackendConfig({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static const fromEnvironment = BackendConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
}

class StudafyBackend {
  StudafyBackend._();

  static bool _initialized = false;
  static bool get isRemote => _initialized;

  static Future<void> initialize() async {
    final config = BackendConfig.fromEnvironment;
    if (!config.isConfigured) return;
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not configured. Provide SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY with --dart-define.',
      );
    }
    return Supabase.instance.client;
  }
}
