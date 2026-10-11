import '../../../data/contracts/v1_client.generated.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_setup.dart';

/// `POST /v1/account/profile` adapter (MOB-070).
///
/// The endpoint needs no school membership and no recent-auth grant — changing
/// your own interface language is not a privileged action — so this is a plain
/// authenticated call. The transport supplies the idempotency key.
class ApiProfileRepository
    implements ProfileRepository, ProfileSetupRepository {
  const ApiProfileRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<void> updateLocale(String locale) async {
    await _client.updateProfile(V1UpdateProfileRequestDto(locale: locale));
  }

  @override
  Future<ProfileSetup> readSetup() async => _setup(await _client.getProfile());

  @override
  Future<ProfileSetup> completeSetup({
    required String displayName,
    required Gender gender,
  }) async => _setup(
    await _client.updateProfile(
      V1UpdateProfileRequestDto(
        displayName: displayName,
        gender: gender.wireValue,
        completeSetup: true,
      ),
    ),
  );

  static ProfileSetup _setup(V1ProfileResponseDto dto) => ProfileSetup(
    displayName: dto.displayName,
    gender: Gender.parse(dto.gender),
    // An older server has no setup to finish.
    complete: dto.setupComplete ?? true,
  );

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

  @override
  Future<OwnProfile> readOwn() async => _own(await _client.getProfile());

  @override
  Future<OwnProfile> rename(String displayName) async => _own(
    await _client.updateProfile(
      V1UpdateProfileRequestDto(displayName: displayName),
    ),
  );

  static OwnProfile _own(V1ProfileResponseDto dto) =>
      OwnProfile(displayName: dto.displayName, publicId: dto.publicId);
}
