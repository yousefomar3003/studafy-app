import '../domain/file_upload_repository.dart';

class UnavailableFileUploadRepository implements FileUploadRepository {
  const UnavailableFileUploadRepository();

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) {
    throw StateError(
      'Remote file uploads remain unavailable until FILE-051 security processing lands.',
    );
  }
}
