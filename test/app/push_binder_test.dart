import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/push_binder.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/features/notifications/domain/push_registrar.dart';

/// Push follows whoever is signed in on the phone.
void main() {
  final context = ActiveContextController.instance;
  tearDown(context.signOut);

  void signIn(String id) => context.hydrate(
    authenticatedProfile: UserProfile(
      id: id,
      displayName: id,
      email: '',
      memberships: const [],
    ),
  );

  test('the phone is registered once per account signed in', () async {
    final registrar = _Registrar();
    final binder = PushBinder(registrar: registrar, context: context);
    addTearDown(binder.dispose);

    signIn('parent');
    signIn('parent'); // A refresh of the same account.
    signIn('child'); // Switched to another account on the phone.
    await pumpEventQueue();

    expect(registrar.registered, 2);
  });

  test('nothing is registered while nobody is signed in', () async {
    final registrar = _Registrar();
    final binder = PushBinder(registrar: registrar, context: context);
    addTearDown(binder.dispose);
    await pumpEventQueue();
    expect(registrar.registered, 0);
  });
}

class _Registrar implements PushRegistrar {
  int registered = 0;

  @override
  Future<void> register() async => registered++;

  @override
  Future<void> unregister() async {}
}
