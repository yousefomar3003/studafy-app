import '../core/studafy_domain.dart';
import 'backend.dart';

class SessionService {
  const SessionService._();

  static Future<void> signOut() async {
    if (StudafyBackend.isRemote) {
      await StudafyBackend.client.auth.signOut();
    }
    ActiveContextController.instance.signOut();
  }
}
