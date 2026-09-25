import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/secure_storage.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/data/secure/secure_session_storage.dart';
import 'package:studafy/features/session/data/api_session_repository.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  late SupabaseClient client;
  late ApiSessionRepository repository;
  Uri? launched;
  var canLaunch = true;

  setUp(() {
    launched = null;
    canLaunch = true;
    final store = InMemorySecureStore();
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: SecurePkceStorage(store),
        autoRefreshToken: false,
      ),
    );
    repository = ApiSessionRepository(
      client: client,
      secureStore: store,
      transport: V1HttpTransport(
        baseUri: Uri.parse('http://127.0.0.1:8080'),
        accessToken: () async => null,
        refreshSession: () async => false,
        onSessionLost: () {},
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          if (call.method == 'launch') {
            launched = Uri.parse((call.arguments as Map)['url'] as String);
          }
          return canLaunch;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, null);
    await client.dispose();
  });

  test(
    'Microsoft requests email and uses the registered PKCE callback',
    () async {
      await repository.signInWithProvider(LoginProvider.microsoft);
      expect(launched?.queryParameters['provider'], 'azure');
      expect(launched?.queryParameters['scopes'], 'email');
      expect(
        launched?.queryParameters['redirect_to'],
        'io.studafy.app://login-callback',
      );
      expect(launched?.queryParameters['code_challenge'], isNotEmpty);
      expect(launched?.queryParameters['code_challenge_method'], 's256');
    },
  );

  test('Google opens the provider with the registered callback', () async {
    await repository.signInWithProvider(LoginProvider.google);
    expect(launched?.queryParameters['provider'], 'google');
    expect(
      launched?.queryParameters['redirect_to'],
      'io.studafy.app://login-callback',
    );
    expect(launched?.queryParameters['code_challenge'], isNotEmpty);
  });

  test('both providers are asked to show the account chooser', () async {
    // Without this the browser's own cookies decide the account, so a phone
    // shared by a parent and a student silently signs in as whoever went
    // last and the app reports a wrong-role error it did not cause.
    for (final provider in LoginProvider.values) {
      if (provider == LoginProvider.apple) continue;
      await repository.signInWithProvider(provider);
      expect(
        launched?.queryParameters['prompt'],
        'select_account',
        reason: '${provider.name} must offer an account chooser',
      );
    }
  });

  test('failure to open the browser is reported', () async {
    canLaunch = false;
    await expectLater(
      repository.signInWithProvider(LoginProvider.google),
      throwsStateError,
    );
  });
}
