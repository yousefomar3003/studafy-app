import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import 'signed_upload_transport.dart';

/// Fetches a delivery link's bytes with the caller's session attached.
typedef DeliveryFetcher = Future<Uint8List> Function(Uri url);

class ApiFileUploadRepository
    implements FileUploadRepository, FileScanStatusSource {
  ApiFileUploadRepository(this._api, this._uploads, {this.fetch});

  final V1ApiClient _api;
  final SignedUploadTransport _uploads;

  /// Null in a build that cannot fetch delivered bytes; opening then fails
  /// with a clear error rather than a silent no-op.
  final DeliveryFetcher? fetch;
  final Map<String, ({String intent, String complete})> _keys = {};

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    final keys = _keys.putIfAbsent(
      command.attemptId,
      () => (
        intent: 'file-intent-${command.attemptId}',
        complete: 'file-complete-${command.attemptId}',
      ),
    );
    final intent = await _switchedOn(
      () => _api.createUploadIntent(
        V1CreateUploadIntentRequestDto(
          schoolId: command.schoolId,
          purpose: command.purpose.wireValue,
          displayName: command.displayName,
          expectedSizeBytes: command.bytes.length,
          declaredMediaType: command.mediaType,
          sha256: sha256.convert(command.bytes).toString(),
          classroomId: command.classroomId,
          assignmentId: command.assignmentId,
          studentId: command.studentId,
          gradeResultId: command.gradeResultId,
        ),
        idempotencyKey: keys.intent,
      ),
    );
    if (intent.method != 'PUT') {
      throw const FormatException('Unsupported signed upload method.');
    }
    await _uploads.put(
      signedUrl: Uri.parse(intent.uploadUrl),
      requiredHeaders: intent.requiredHeaders.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      bytes: command.bytes,
    );
    final completed = await _api.completeUpload(
      const V1CompleteUploadRequestDto(),
      uploadId: intent.session.id,
      idempotencyKey: keys.complete,
    );
    _keys.remove(command.attemptId);
    return QuarantinedFile(
      id: completed.file.id,
      uploadId: completed.session.id,
      displayName: completed.file.displayName,
      sizeBytes: completed.file.sizeBytes,
      scanState: completed.file.scanState,
    );
  }

  @override
  Future<FileScanStatus> scanStatus(String fileId) async {
    final file = await _api.getFileStatus(fileId: fileId);
    return FileScanStatus(
      scanState: file.scanState,
      failureCode: file.failureCode,
    );
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) async {
    final published = await _api.publishFile(
      V1PublishFileRequestDto(audience: audience.wireValue),
      fileId: fileId,
      // Keyed on the file and the audience so a retry after a dropped
      // response republishes nothing, and a deliberate change of audience is
      // still a distinct command.
      idempotencyKey: 'file-publish-$fileId-${audience.wireValue}',
    );
    return published.resource.id;
  }

  @override
  Future<DownloadedFile> download(String fileId) async {
    final fetch = this.fetch;
    if (fetch == null) throw const FileServiceUnavailable();
    final grant = await _switchedOn(
      () => _api.createFileDownloadIntent(
        const V1DownloadIntentRequestDto(),
        fileId: fileId,
        // Fresh every time: a grant is single-use, so replaying an earlier
        // response would hand back a link that has already been spent.
        idempotencyKey: newIdempotencyKey('file-download'),
      ),
    );
    final bytes = await fetch(Uri.parse(grant.downloadUrl));
    return DownloadedFile(
      displayName: grant.displayName,
      mediaType: grant.mediaType,
      bytes: bytes,
    );
  }

  /// The codes a server sends when its file pipeline is switched off or its
  /// storage is not configured - as opposed to a dropped connection.
  static const _switchedOffCodes = {
    'SERVICE_UNAVAILABLE',
    'STORAGE_UNAVAILABLE',
    'FILE_DELIVERY_DISABLED',
  };

  static Future<T> _switchedOn<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on V1ApiException catch (error) {
      // Delivery being off is a 409; the others are 503s.
      if (_switchedOffCodes.contains(error.code) &&
          (error.status == 503 || error.code == 'FILE_DELIVERY_DISABLED')) {
        throw const FileServiceUnavailable();
      }
      rethrow;
    }
  }
}
