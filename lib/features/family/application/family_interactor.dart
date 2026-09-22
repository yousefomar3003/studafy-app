import '../../../core/failures.dart';
import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/family.dart';

/// Family use cases for the guardian home. Presentation calls this, never
/// a repository (ARC-011). Telemetry carries counts only, never a child's
/// name or id.
class FamilyInteractor {
  FamilyInteractor({
    required this.family,
    required this.approvals,
    required this.confirmRecentAuth,
    required this.telemetry,
  });

  final FamilyRepository family;
  final PurchaseApprovalRepository approvals;

  /// Proves a recent sign-in for the approval purpose and arms a one-time
  /// grant for the next request. Supplied by the composition root.
  final Future<void> Function() confirmRecentAuth;
  final Telemetry telemetry;

  Future<Result<List<GuardianChild>>> children() => runCatching(() async {
    final list = await family.children();
    telemetry.event('family_children_loaded', {'count': list.length});
    return list;
  });

  Future<Result<LocatedStudent?>> locate(
    String studafyId, {
    String? captchaToken,
  }) {
    final code = studafyId.trim();
    if (code.isEmpty) {
      return Future.value(
        const Result.failure(Failure.validation('Enter the Studafy ID.')),
      );
    }
    return runCatching(() => family.locate(code, captchaToken: captchaToken));
  }

  Future<Result<GuardianChild>> requestLink(String studentId) => runCatching(
    () async {
      final link = await family.requestLink(studentId, relationship: 'parent');
      telemetry.event('guardian_link_requested', const {});
      return link;
    },
  );

  Future<Result<ChildProgress>> progress(String studentId) =>
      runCatching(() => family.progress(studentId));

  /// Pending approvals, or an empty list when billing is not available in
  /// this environment: the home screen shows nothing rather than an error.
  Future<List<PurchaseApprovalRequest>> pendingApprovals() async {
    try {
      final list = await approvals.pending();
      return [
        for (final item in list)
          if (item.isPending) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<Result<void>> decide(String approvalId, {required bool approve}) =>
      runCatching(() async {
        await confirmRecentAuth();
        await approvals.decide(approvalId, approve: approve);
        telemetry.event('purchase_approval_decided', {'approved': approve});
      });
  Future<Result<StudentFamily>> studentFamily() => runCatching(() {
    final repository = family;
    if (repository is! StudentFamilyRepository) {
      throw const Failure.unsupported('Family requests are unavailable.');
    }
    return (repository as StudentFamilyRepository).studentFamily();
  });
  Future<Result<void>> decideGuardian(String linkId, String decision) =>
      runCatching(() {
        if (!['approve', 'decline', 'revoke'].contains(decision)) {
          throw const Failure.validation('Invalid decision.');
        }
        final repository = family;
        if (repository is! StudentFamilyRepository) {
          throw const Failure.unsupported('Family requests are unavailable.');
        }
        return (repository as StudentFamilyRepository).decideGuardian(
          linkId,
          decision,
        );
      });
}
