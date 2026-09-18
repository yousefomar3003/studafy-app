import 'package:crypto/crypto.dart';

import '../../../data/contracts/v1_client.generated.dart';
import '../domain/file_upload_repository.dart';
import 'signed_upload_transport.dart';

class ApiFileUploadRepository implements FileUploadRepository {
  ApiFileUploadRepository(this._api, this._uploads);

  final V1ApiClient _api;
  final SignedUploadTransport _uploads;
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
    final intent = await _api.createUploadIntent(
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
}
