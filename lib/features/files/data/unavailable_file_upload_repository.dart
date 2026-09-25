import '../../../core/file_upload_repository.dart';

class UnavailableFileUploadRepository implements FileUploadRepository {
  const UnavailableFileUploadRepository();

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) {
    throw StateError(
      // Reached only where there is no API client to send to, or in a
      // production build, where the worker has no malware provider and
      // would fail the scan closed anyway.
      'Remote file uploads are unavailable in this build.',
    );
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) =>
      throw StateError('Remote file publishing is unavailable in this build.');
}
