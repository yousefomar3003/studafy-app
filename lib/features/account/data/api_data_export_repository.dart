import 'dart:convert';

import '../../../core/failures.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/data_export.dart';

/// `/v1/account/export-*` adapter. The recent-auth grant comes from the
/// session slice through [confirmRecentAuth], armed immediately before the
/// request so it is spent on exactly that call.
class ApiDataExportRepository implements DataExportRepository {
  ApiDataExportRepository(this._client, {required this.confirmRecentAuth});

  final V1ApiClient _client;
  final Future<void> Function() confirmRecentAuth;

  @override
  Future<DataExportStatus?> status() => _guard(() async {
    final response = await _client.getExportStatus();
    final request = response.request;
    return request == null ? null : _status(request);
  });

  @override
  Future<DataExportStatus> request() => _guard(() async {
    await confirmRecentAuth();
    return _status(
      await _client.requestDataExport(const V1RequestDataExportRequestDto()),
    );
  });

  @override
  Future<String> download() => _guard(() async {
    final document = await _client.downloadDataExport();
    return const JsonEncoder.withIndent('  ').convert(document.toJson());
  });

  static DataExportStatus _status(V1DataExportRequestDto dto) =>
      DataExportStatus(
        id: dto.id,
        state: dataExportStateFromWire(dto.status),
        requestedAt: DateTime.parse(dto.requestedAt),
        readyAt: dto.readyAt == null ? null : DateTime.parse(dto.readyAt!),
        expiresAt: dto.expiresAt == null
            ? null
            : DateTime.parse(dto.expiresAt!),
      );

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on V1ApiException catch (error) {
      if (error.isUnauthenticated) throw Failure.unauthorized;
      if (error.isReauthRequired) {
        throw const Failure('REAUTH_REQUIRED', 'REAUTH_REQUIRED');
      }
      if (error.code == 'NOT_FOUND') throw Failure.notFound;
      throw Failure.unknown;
    }
  }
}
