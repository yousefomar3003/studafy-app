import '../../../core/file_upload_repository.dart';

/// Synthetic-only adapter. It has no SQLite or remote-storage side effects.
class PreviewFileUploadRepository implements FileUploadRepository {
  const PreviewFileUploadRepository();

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async =>
      QuarantinedFile(
        id: 'preview-file-${command.attemptId}',
        uploadId: 'preview-upload-${command.attemptId}',
        displayName: command.displayName,
        sizeBytes: command.bytes.length,
        scanState: 'quarantined',
      );

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) async => 'preview-resource-$fileId';
}
