import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Identifies whose data a local cache file holds (MOB-070).
///
/// Every cache file is keyed by user *and* school, never by user alone: a
/// teacher who belongs to two schools must not see one school's cached
/// classes while acting in the other. Two [CacheScope]s are equal only when
/// both ids match, so switching either one is a re-key, not a data leak.
///
/// [schoolId] is null for someone who belongs to no school. A guardian is
/// the permanent case: they are linked to a child, never enrolled, so they
/// hold no membership and never will. Refusing them a cache refused them
/// every cached read, which took the whole notifications tab down with it.
/// The separation argument does not apply to them — a scope with no school
/// holds no school's rows to leak — and it is still its own file, distinct
/// from every school-scoped one.
class CacheScope {
  const CacheScope({required this.userId, this.schoolId});

  final String userId;
  final String? schoolId;

  String get userFileKey => sha256.convert(utf8.encode(userId)).toString();

  /// Filesystem-safe, non-reversible file-name fragment. Deliberately not
  /// the raw id: neither belongs in a file name an OS-level backup or crash
  /// report might surface.
  ///
  /// A null school hashes as the empty string rather than "null", so the key
  /// for a school-scoped cache is byte-identical to what it was before the
  /// field became nullable: existing files stay addressable instead of being
  /// silently orphaned on upgrade. School ids are uuids, so no real school
  /// can collide with the empty one.
  String get fileKey {
    final digest = sha256.convert(utf8.encode('$userId::${schoolId ?? ''}'));
    return digest.toString().substring(0, 32);
  }

  @override
  bool operator ==(Object other) =>
      other is CacheScope &&
      other.userId == userId &&
      other.schoolId == schoolId;

  @override
  int get hashCode => Object.hash(userId, schoolId);

  @override
  String toString() => 'CacheScope($fileKey)';
}
