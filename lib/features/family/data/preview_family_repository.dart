import '../domain/family.dart';

/// Synthetic-only family data: one verified child, so the demo exercises
/// the same screens a real guardian sees.
class PreviewFamilyRepository
    implements FamilyRepository, PurchaseApprovalRepository {
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
  Future<LocatedStudent?> locate(String studafyId) async =>
      studafyId.toUpperCase() == 'STU-DEMO-2'
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
}
