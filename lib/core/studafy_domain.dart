import 'package:flutter/foundation.dart';

import 'runtime_environment.dart';

enum StudafyRole { schoolAdmin, teacher, parent, student }

@immutable
class SchoolMembership {
  const SchoolMembership({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    required this.active,
  });

  final String id;
  final String schoolId;
  final String schoolName;
  final StudafyRole role;
  final bool active;
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.memberships,
  });

  final String id;
  final String displayName;
  final String email;
  final List<SchoolMembership> memberships;
}

@immutable
class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.studafyId,
    required this.displayName,
    required this.verified,
    this.schoolId,
  });

  final String id;
  final String studafyId;
  final String displayName;
  final bool verified;

  /// The school this child is enrolled in, where the caller knows it.
  ///
  /// It is how a guardian gets a school at all: they hold no membership, so
  /// without their child's school nothing school-scoped - messaging contacts
  /// above all - has anywhere to point.
  final String? schoolId;
}

/// The single source of truth for role, school, term, and selected child.
///
/// Feature pages listen to this controller instead of keeping independent
/// child indexes. A future remote repository can hydrate the same API after
/// Supabase authentication without changing navigation code.
class ActiveContextController extends ChangeNotifier {
  ActiveContextController._();

  static final ActiveContextController instance = ActiveContextController._();

  UserProfile? profile;
  SchoolMembership? membership;
  StudentSummary? selectedStudent;
  String? activeTermId;

  StudafyRole? get role => membership?.role;

  /// The school the app is acting in, or null when there is none.
  ///
  /// Not the same thing as [membership]. A guardian has no membership and
  /// never will, so anything school-scoped that reads `membership.schoolId`
  /// is permanently null for them; their school is whichever child they are
  /// looking at. Staff have no selected child, so this is their membership.
  String? get activeSchoolId =>
      membership?.schoolId ?? selectedStudent?.schoolId;

  void startDemoRole(StudafyRole role) {
    // SEC-001/ARC-011: demo identities exist only in synthetic builds. Any
    // other environment refuses, so production can never hydrate demo data.
    if (!StudafyRuntime.policy.isSynthetic) return;
    const schoolId = 'demo-school';
    membership = SchoolMembership(
      id: 'demo-${role.name}',
      schoolId: schoolId,
      schoolName: 'Al-Noor International',
      role: role,
      active: true,
    );
    profile = UserProfile(
      id: 'demo-user',
      displayName: switch (role) {
        StudafyRole.schoolAdmin => 'School Administrator',
        StudafyRole.teacher => 'Rana Haddad',
        StudafyRole.parent => 'Nadia Hassan',
        StudafyRole.student => 'Layla Hassan',
      },
      email: 'demo@studafy.app',
      memberships: [membership!],
    );
    activeTermId = 'demo-term-2026';
    notifyListeners();
  }

  void selectStudent(StudentSummary? student) {
    // The school is part of the comparison, not just the id: re-selecting
    // the same child with their school now known is a real change, and
    // skipping it would leave a guardian without one.
    if (selectedStudent?.id == student?.id &&
        selectedStudent?.schoolId == student?.schoolId) {
      return;
    }
    selectedStudent = student;
    notifyListeners();
  }

  void switchMembership(SchoolMembership next) {
    membership = next;
    selectedStudent = null;
    notifyListeners();
  }

  bool canSwitchTo(StudafyRole target) =>
      profile?.memberships.any((item) => item.active && item.role == target) ??
      false;

  void switchRole(StudafyRole target) {
    final next = profile?.memberships
        .where((item) => item.active && item.role == target)
        .firstOrNull;
    if (next == null) {
      // ARC-011: outside synthetic builds a missing membership is a denial,
      // never a demo fallback. The role stays unchanged.
      if (StudafyRuntime.policy.isSynthetic) startDemoRole(target);
      return;
    }
    switchMembership(next);
  }

  /// Publishes the signed-in identity.
  ///
  /// [activeMembership] is nullable because signing in and belonging somewhere
  /// are separate facts. A brand-new account has proved who it is and has no
  /// class yet; that is the state onboarding runs in, and it is the normal
  /// first minute for every real user rather than an error. A parent stays in
  /// it permanently - guardians are linked to a student, never enrolled - so
  /// nothing here may treat a null membership as a failed login.
  ///
  /// [role] is derived from the membership, so it too is null until then, and
  /// every reader of [membership] already guards for that.
  void hydrate({
    required UserProfile authenticatedProfile,
    SchoolMembership? activeMembership,
    StudentSummary? student,
    String? termId,
  }) {
    profile = authenticatedProfile;
    membership = activeMembership;
    selectedStudent = student;
    activeTermId = termId;
    notifyListeners();
  }

  void signOut() {
    profile = null;
    membership = null;
    selectedStudent = null;
    activeTermId = null;
    notifyListeners();
  }
}

enum InsightConfidence { insufficient, low, medium, high }

@immutable
class InsightEvidence {
  const InsightEvidence({
    required this.label,
    required this.value,
    required this.recordCount,
    this.sourceRoute,
  });

  final String label;
  final String value;
  final int recordCount;
  final String? sourceRoute;
}

@immutable
class InsightMetric {
  const InsightMetric({
    required this.id,
    required this.title,
    required this.value,
    required this.confidence,
    required this.evidence,
    required this.updatedAt,
    this.change,
    this.explanation,
  });

  final String id;
  final String title;
  final double value;
  final double? change;
  final InsightConfidence confidence;
  final List<InsightEvidence> evidence;
  final DateTime updatedAt;
  final String? explanation;
}

enum GradePublicationState { draft, reviewed, published }
