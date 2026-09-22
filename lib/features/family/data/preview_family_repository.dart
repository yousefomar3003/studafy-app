import '../domain/family.dart';

/// Synthetic-only family data: one verified child, so the demo exercises
/// the same screens a real guardian sees.
class PreviewFamilyRepository
    implements
        FamilyRepository,
        PurchaseApprovalRepository,
        StudentFamilyRepository {
  final List<GuardianChild> _children = [
    const GuardianChild(
      linkId: 'demo-link-1',
      studentId: 'demo-student',
      studentName: 'Layla Hassan',
      schoolId: 'demo-school',
      schoolName: 'Al-Noor International',
      status: GuardianLinkStatus.verified,
    ),
  ];

  @override
  Future<List<GuardianChild>> children() async => List.of(_children);

  @override
  Future<LocatedStudent?> locate(
    String studafyId, {
    String? captchaToken,
  }) async => studafyId.toUpperCase() == 'STU-DEMO-2'
      ? const LocatedStudent(studentId: 'demo-student-2', displayName: 'Omar')
      : null;

  @override
  Future<GuardianChild> requestLink(
    String studentId, {
    String? relationship,
  }) async {
    final child = GuardianChild(
      linkId: 'demo-link-${_children.length + 1}',
      studentId: studentId,
      studentName: 'Omar',
      schoolId: 'demo-school',
      schoolName: 'Al-Noor International',
      status: GuardianLinkStatus.pending,
    );
    _children.add(child);
    return child;
  }

  @override
  Future<ChildProgress> progress(String studentId) async => const ChildProgress(
    gradedCount: 6,
    averagePercent: 84.5,
    present: 38,
    late: 2,
    absent: 1,
    excused: 1,
  );

  @override
  Future<List<PurchaseApprovalRequest>> pending() async => const [];

  @override
  Future<void> decide(String approvalId, {required bool approve}) async {}
  final List<StudentGuardianRequest> _requests = [
    const StudentGuardianRequest(
      id: 'preview-parent-request',
      guardianId: 'demo-parent',
      guardianName: 'Nadia Hassan',
      status: GuardianLinkStatus.pending,
    ),
  ];
  @override
  Future<StudentFamily> studentFamily() async => StudentFamily(
    identities: const [
      StudentIdentity(
        id: 'demo-student',
        studafyId: 'STU-DEMO-1',
        name: 'Layla Hassan',
      ),
    ],
    requests: List.of(_requests),
  );
  @override
  Future<void> decideGuardian(String linkId, String decision) async {
    final index = _requests.indexWhere((r) => r.id == linkId);
    if (index < 0) throw StateError('Missing request');
    final r = _requests[index];
    _requests[index] = StudentGuardianRequest(
      id: r.id,
      guardianId: r.guardianId,
      guardianName: r.guardianName,
      status: decision == 'approve'
          ? GuardianLinkStatus.verified
          : decision == 'decline'
          ? GuardianLinkStatus.declined
          : GuardianLinkStatus.revoked,
    );
  }
}
