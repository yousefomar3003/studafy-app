import 'package:flutter/foundation.dart';

import '../../../core/studafy_domain.dart';

/// An account kept on this device, to switch to without signing in again -
/// the way Instagram keeps several accounts on one phone.
///
/// Two kinds: accounts somebody signed in to themselves, and child accounts
/// a parent manages ([managedBy]). A young child has no email or phone, so
/// their account can only ever be entered through the parent who made it.
@immutable
class DeviceAccount {
  const DeviceAccount({
    required this.userId,
    required this.displayName,
    required this.role,
    this.managedBy,
    this.managedByName,
  });

  final String userId;
  final String displayName;

  /// The role the account is opened as. A child account is always a student.
  final StudafyRole role;

  /// The parent's account, for a child account they manage.
  final String? managedBy;

  /// The parent's name, so the app can say whose sub-account this is.
  final String? managedByName;

  bool get isManaged => managedBy != null;

  DeviceAccount copyWith({String? displayName, StudafyRole? role}) =>
      DeviceAccount(
        userId: userId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        managedBy: managedBy,
        managedByName: managedByName,
      );

  Map<String, Object?> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'role': role.name,
    'managedBy': managedBy,
    'managedByName': managedByName,
  };

  /// Null for anything this build cannot read, so a damaged or older entry
  /// drops out of the list instead of breaking it.
  static DeviceAccount? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final userId = json['userId'];
    final name = json['displayName'];
    final role = StudafyRole.values
        .where((value) => value.name == json['role'])
        .firstOrNull;
    if (userId is! String || name is! String || role == null) return null;
    final managedBy = json['managedBy'];
    final managedByName = json['managedByName'];
    return DeviceAccount(
      userId: userId,
      displayName: name,
      role: role,
      managedBy: managedBy is String ? managedBy : null,
      managedByName: managedByName is String ? managedByName : null,
    );
  }
}

/// A child account the signed-in parent manages, as the server lists it.
@immutable
class ManagedChild {
  const ManagedChild({
    required this.childId,
    required this.displayName,
    required this.createdAt,
  });

  final String childId;
  final String displayName;
  final DateTime createdAt;
}

/// Why something about a child account was refused.
enum ManagedChildRefusal {
  /// One account may manage six children.
  limitReached,

  /// This server cannot create child accounts, or did not answer.
  unavailable,

  /// Anything else.
  failed,
}

class ManagedChildException implements Exception {
  const ManagedChildException(this.refusal);
  final ManagedChildRefusal refusal;

  @override
  String toString() => 'ManagedChildException($refusal)';
}

/// The parent's side of child accounts.
abstract interface class ManagedChildrenRepository {
  Future<List<ManagedChild>> list();

  /// Creates a student account for [displayName]. The parent accepts the
  /// terms for the child, in [locale], by doing so.
  Future<ManagedChild> create({
    required String displayName,
    required String locale,
  });

  /// A one-time sign-in to the child's account, issued to their parent only.
  Future<String> signInToken(String childId);
}

/// Where the device keeps its accounts and their latest refresh tokens.
///
/// Every token is a credential, so the store behind this is the platform
/// keystore, like the session itself (AUTH-030).
abstract interface class AccountVault {
  Future<DeviceAccountList> read();
  Future<void> write(DeviceAccountList list);
}

/// The device's accounts and each one's latest refresh token.
@immutable
class DeviceAccountList {
  const DeviceAccountList({this.accounts = const [], this.tokens = const {}});

  final List<DeviceAccount> accounts;

  /// Latest refresh token by account id.
  final Map<String, String> tokens;
}
