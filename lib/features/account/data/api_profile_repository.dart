import '../../../data/contracts/v1_client.generated.dart';
import '../domain/profile_repository.dart';

/// `POST /v1/account/profile` adapter (MOB-070).
///
/// The endpoint needs no school membership and no recent-auth grant — changing
/// your own interface language is not a privileged action — so this is a plain
/// authenticated call. The transport supplies the idempotency key.
class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<void> updateLocale(String locale) async {
    await _client.updateProfile(V1UpdateProfileRequestDto(locale: locale));
  }

  @override
  Future<String?> readLocale() async {
    try {
      final context = await _client.getAuthContext();
      return context.locale;
    } on Exception {
      // Signed out, offline, or the call failed. The device keeps whatever
      // language it is already showing; this only ever seeds, never corrects.
      return null;
    }
  }
}
