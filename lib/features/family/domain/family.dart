import 'package:flutter/foundation.dart';

enum GuardianLinkStatus { pending, verified, declined, revoked }

GuardianLinkStatus guardianLinkStatusFromWire(String value) => switch (value) {
  'verified' => GuardianLinkStatus.verified,
  'declined' => GuardianLinkStatus.declined,
  'revoked' => GuardianLinkStatus.revoked,
  _ => GuardianLinkStatus.pending,
};

/// A child the signed-in guardian has asked to be linked to. Only a
/// verified link grants access to the child's records.
@immutable
class GuardianChild {
  const GuardianChild({
    required this.linkId,
    required this.studentId,
    required this.studentName,
    required this.schoolId,
    required this.schoolName,
    required this.status,
    this.expiresAt,
  });

  final String linkId;
  final String studentId;
  final String studentName;
  final String schoolId;
  final String schoolName;
  final GuardianLinkStatus status;
  final DateTime? expiresAt;

  bool get isVerified =>
      status == GuardianLinkStatus.verified &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

/// The uniform answer to "who has this Studafy ID?". Not found and found
/// have the same shape so the lookup is not an enumeration oracle.
@immutable
class LocatedStudent {
  const LocatedStudent({required this.studentId, required this.displayName});

  final String studentId;
  final String displayName;
}

/// A child's progress, computed from published grades and attendance the
/// guardian is authorised to read. Null means there is no data yet.
@immutable
class ChildProgress {
  const ChildProgress({
    required this.gradedCount,
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    this.averagePercent,
  });

  final int gradedCount;
  final double? averagePercent;
  final int present;
  final int late;
  final int absent;
  final int excused;

  int get sessions => present + late + absent + excused;

  /// Present or late, over sessions that were not excused.
  double? get attendancePercent {
    final counted = present + late + absent;
    if (counted == 0) return null;
    return (present + late) * 100 / counted;
  }
}

/// A child's request that a guardian approve a subscription (DL-048).
@immutable
class PurchaseApprovalRequest {
  const PurchaseApprovalRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.featureKey,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String featureKey;
  final String status;
  final DateTime expiresAt;

  bool get isPending => status == 'requested';
}

abstract interface class FamilyRepository {
  Future<List<GuardianChild>> children();

  /// Null when no student has that Studafy ID.
  Future<LocatedStudent?> locate(String studafyId, {String? captchaToken});

  Future<GuardianChild> requestLink(String studentId, {String? relationship});

  Future<ChildProgress> progress(String studentId);
}

/// Guardian purchase approvals. Deciding requires a fresh recent-auth
/// grant, which the application layer obtains first.
abstract interface class PurchaseApprovalRepository {
  Future<List<PurchaseApprovalRequest>> pending();

  Future<void> decide(String approvalId, {required bool approve});
}

class StudentIdentity {
  const StudentIdentity({
    required this.id,
    required this.studafyId,
    required this.name,
  });
  final String id;
  final String studafyId;
  final String name;
}

class StudentGuardianRequest {
  const StudentGuardianRequest({
    required this.id,
    required this.guardianId,
    required this.guardianName,
    required this.status,
  });
  final String id;
  final String guardianId;
  final String guardianName;
  final GuardianLinkStatus status;
}

class StudentFamily {
  const StudentFamily({required this.identities, required this.requests});
  final List<StudentIdentity> identities;
  final List<StudentGuardianRequest> requests;
}

abstract interface class StudentFamilyRepository {
  Future<StudentFamily> studentFamily();
  Future<void> decideGuardian(String linkId, String decision);
}
