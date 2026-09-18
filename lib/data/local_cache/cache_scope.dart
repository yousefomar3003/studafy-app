import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Identifies whose data a local cache file holds (MOB-070).
///
/// Every cache file is keyed by user *and* school, never by user alone: a
/// teacher who belongs to two schools must not see one school's cached
/// classes while acting in the other. Two [CacheScope]s are equal only when
/// both ids match, so switching either one is a re-key, not a data leak.
class CacheScope {
  const CacheScope({required this.userId, required this.schoolId});

  final String userId;
  final String schoolId;

  /// Filesystem-safe, non-reversible file-name fragment. Deliberately not
  /// the raw id: neither belongs in a file name an OS-level backup or crash
  /// report might surface.
  String get fileKey {
    final digest = sha256.convert(utf8.encode('$userId::$schoolId'));
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
