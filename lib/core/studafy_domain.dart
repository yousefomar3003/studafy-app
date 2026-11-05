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
    this.accountKind,
    this.platformOperator = false,
    this.schoolPortal = false,
  });

  final String id;
  final String displayName;
  final String email;
  final List<SchoolMembership> memberships;

  /// Which kind of account this is, as the server decided it; null when
  /// nothing has yet (and from older servers).
  final AccountKind? accountKind;

  /// The server says this account is a platform operator (GET /v1/me), so
  /// the account screen offers the safety-report review. Never inferred on
  /// the device; it opens nothing by itself, since the server checks every
  /// review step again.
  final bool platformOperator;

  /// The server's School Portal is on (GET /v1/me): a teacher is offered
  /// their Studafy ID for schools and the schools' link requests. The
  /// routes behind it are refused by the server while it is off.
  final bool schoolPortal;

  /// The kind the server reported, or else what the memberships show.
  AccountKind? get effectiveKind {
    if (accountKind != null) return accountKind;
    final active = memberships.where((m) => m.active);
    if (active.any((m) => m.role != StudafyRole.student)) {
      return AccountKind.adult;
    }
    if (active.any((m) => m.role == StudafyRole.student)) {
      return AccountKind.student;
    }
    return null;
  }
}

/// One kind of account per email (2026-10-01): a student account is a
/// student only; an adult account may be a teacher, a parent, or both.
enum AccountKind {
  student,
  adult;

  static AccountKind? parse(String? value) => switch (value) {
    'student' => AccountKind.student,
    'adult' => AccountKind.adult,
    _ => null,
  };

  /// Whether this kind of account may act as [role].
  bool allows(StudafyRole role) => switch (this) {
    AccountKind.student => role == StudafyRole.student,
    AccountKind.adult => role != StudafyRole.student,
  };

  /// The kind a person signing in as [role] makes a new account.
  static AccountKind forRole(StudafyRole role) =>
      role == StudafyRole.student ? AccountKind.student : AccountKind.adult;
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

  /// The role this session was opened as, which [role] cannot say for an
  /// account with no membership: every parent, and a student before their
  /// first class. Switching accounts on the device returns to it.
  StudafyRole? signedInAs;

  /// The school the app is acting in, or null when there is none.
  ///
  /// Not the same thing as [membership]. A guardian has no membership and
  /// never will, so anything school-scoped that reads `membership.schoolId`
  /// is permanently null for them; their school is whichever child they are
  /// looking at. Staff have no selected child, so this is their membership.
  String? get activeSchoolId =>
      membership?.schoolId ?? selectedStudent?.schoolId;

  /// Every school the app reads for this person, the active one first.
  ///
  /// There is no school administrator: each teacher has a workspace of their
  /// own, and a class is in its teacher's. A student in two teachers' classes
  /// therefore holds two student memberships, and sees both together - their
  /// classes, work, marks and announcements - not only the active one's.
  /// Anyone else acts in one school, so it is [activeSchoolId] alone.
  List<String> get schoolIds {
    final active = membership;
    if (active == null || active.role != StudafyRole.student) {
      return [?activeSchoolId];
    }
    return {
      active.schoolId,
      for (final item in profile?.memberships ?? const <SchoolMembership>[])
        if (item.active && item.role == StudafyRole.student) item.schoolId,
    }.toList();
  }

  /// Which school each of a student's classes is in, as their class lists
  /// said. A class's own reads and uploads go to its own school.
  final Map<String, String> _classroomSchools = {};

  /// Notes the school [classroomId] belongs to; it notifies nobody.
  void rememberClassroomSchool(String classroomId, String schoolId) =>
      _classroomSchools[classroomId] = schoolId;

  /// The school of a student's class [classroomId] when a class list has
  /// said; null for anyone but a student, and for a class not listed yet.
  String? schoolOfClassroom(String? classroomId) =>
      membership?.role == StudafyRole.student
      ? _classroomSchools[classroomId]
      : null;

  /// The school a file for [classroomId] is uploaded to: the class's own,
  /// or else the active one.
  String? schoolFor(String? classroomId) =>
      schoolOfClassroom(classroomId) ?? activeSchoolId;

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
    signedInAs = target;
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
    StudafyRole? signedInAs,
  }) {
    // Another account's classes are not this one's.
    if (profile?.id != authenticatedProfile.id) _classroomSchools.clear();
    profile = authenticatedProfile;
    membership = activeMembership;
    this.signedInAs = signedInAs ?? activeMembership?.role;
    selectedStudent = student;
    activeTermId = termId;
    notifyListeners();
  }

  void signOut() {
    _classroomSchools.clear();
    profile = null;
    membership = null;
    signedInAs = null;
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
