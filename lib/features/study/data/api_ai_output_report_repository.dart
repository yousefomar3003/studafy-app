import '../../../core/ai_output_report.dart';
import '../../../data/contracts/v1_client.generated.dart';

/// Reporting an AI answer through the API (DL-076): `POST
/// /v1/me/output-reports`, as the signed-in account, school or not.
class ApiAiOutputReportRepository implements AiOutputReporter {
  const ApiAiOutputReportRepository(this._client);

  final V1ApiClient _client;

  @override
  Future<void> report(
    AiOutputReport report, {
    required String idempotencyKey,
  }) async {
    await _client.reportAiOutput(
      V1ReportAiOutputRequestDto(
        feature: report.feature.name,
        reason: report.reason.name,
        details: report.details,
        excerpt: aiOutputExcerpt(report.excerpt),
      ),
      idempotencyKey: idempotencyKey,
    );
  }
}

/// A synthetic build has no server: a report is accepted and goes nowhere.
class PreviewAiOutputReportRepository implements AiOutputReporter {
  const PreviewAiOutputReportRepository();

  @override
  Future<void> report(
    AiOutputReport report, {
    required String idempotencyKey,
  }) async {}
}
