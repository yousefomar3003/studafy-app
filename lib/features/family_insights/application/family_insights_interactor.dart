import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/family_insights.dart';

class FamilyInsightsInteractor {
  const FamilyInsightsInteractor({
    required this.repository,
    required this.telemetry,
  });

  final FamilyInsightsRepository repository;
  final Telemetry telemetry;

  Future<Result<FamilyInsights>> forStudent(String studentId) async {
    final result = await runCatching(() => repository.forStudent(studentId));
    // Never the child's name, marks or notes: this is a telemetry event, and
    // a log line is the wrong place for somebody's school record.
    result.fold(
      onSuccess: (_) => telemetry.event('family_insights_viewed', const {}),
      onFailure: (failure) =>
          telemetry.event('family_insights_failed', {'code': failure.code}),
    );
    return result;
  }
}
