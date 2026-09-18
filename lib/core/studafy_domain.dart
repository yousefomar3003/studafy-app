import 'package:flutter/foundation.dart';

import 'runtime_environment.dart';

enum StudafyRole { teacher, parent, student }

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
  });

  final String id;
  final String studafyId;
  final String displayName;
  final bool verified;
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
    if (selectedStudent?.id == student?.id) return;
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

  void hydrate({
    required UserProfile authenticatedProfile,
    required SchoolMembership activeMembership,
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
