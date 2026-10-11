import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

/// The signed-in person's own profile, as the profile screen shows it.
@immutable
class OwnProfile {
  const OwnProfile({required this.displayName, this.publicId});

  final String displayName;

  /// The account's ten-digit Studafy number, as digits; null from servers
  /// that do not issue one yet.
  final String? publicId;
}

/// The longest name the server accepts.
const maxDisplayNameLength = 160;

/// A name as it will be saved: trimmed, with runs of spaces made one. Any
/// script is fine - nothing here assumes Latin letters. Null when nothing
/// is left, or it is too long.
String? normaliseDisplayName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.characters.length > maxDisplayNameLength) {
    return null;
  }
  return name;
}

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

  /// The name and Studafy number the person sees on their profile.
  Future<OwnProfile> readOwn();

  /// Changes the person's own display name; returns the profile as saved.
  Future<OwnProfile> rename(String displayName);
}
