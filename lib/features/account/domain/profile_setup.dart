import 'package:flutter/foundation.dart';

/// How someone describes themselves, asked once at first sign-in.
enum Gender {
  male('male'),
  female('female'),
  preferNotToSay('prefer_not_to_say');

  const Gender(this.wireValue);
  final String wireValue;

  static Gender? parse(String? value) =>
      Gender.values.where((gender) => gender.wireValue == value).firstOrNull;
}

/// The caller's own profile, as first-sign-in setup needs it.
@immutable
class ProfileSetup {
  const ProfileSetup({
    required this.displayName,
    required this.complete,
    this.gender,
  });

  /// Until setup, this is the name derived from the sign-in (often the start
  /// of an email address); the setup page offers it to be corrected.
  final String displayName;
  final Gender? gender;

  /// The person has chosen their name and answered gender.
  final bool complete;
}

/// First-sign-in setup: what to call someone, and their gender. The answer
/// is the person's own; the server returns it to them and nobody else.
abstract interface class ProfileSetupRepository {
  Future<ProfileSetup> readSetup();

  Future<ProfileSetup> completeSetup({
    required String displayName,
    required Gender gender,
  });
}
