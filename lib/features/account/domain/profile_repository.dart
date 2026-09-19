/// Port for the signed-in user's own profile (MOB-070).
///
/// Today it carries one field. The interface language is stored on the profile
/// because the server, not the app, renders email and push copy: a user who
/// switches Studafy to Arabic must stop receiving English notifications.
abstract interface class ProfileRepository {
  /// Records the interface language the user chose, as a BCP 47 language code.
  Future<void> updateLocale(String locale);

  /// The language stored on the profile, used to seed a device that has never
  /// been told what to use — so signing in on a new phone keeps your language.
  /// Null when it cannot be read; the caller then leaves the device as it is.
  Future<String?> readLocale();
}
