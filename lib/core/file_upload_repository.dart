import 'dart:typed_data';

enum FilePurpose {
  profileImage('profile_image'),
  lessonResource('lesson_resource'),
  assignmentMaterial('assignment_material'),
  assignmentSubmission('assignment_submission'),
  paperScan('paper_scan'),
  messageAttachment('message_attachment'),
  announcementAttachment('announcement_attachment');

  const FilePurpose(this.wireValue);
  final String wireValue;
}

class FileUploadCommand {
  const FileUploadCommand({
    required this.attemptId,
    required this.schoolId,
    required this.purpose,
    required this.displayName,
    required this.mediaType,
    required this.bytes,
    this.classroomId,
    this.assignmentId,
    this.studentId,
    this.gradeResultId,
  });

  final String attemptId;
  final String schoolId;
  final FilePurpose purpose;
  final String displayName;
  final String mediaType;
  final Uint8List bytes;
  final String? classroomId;
  final String? assignmentId;
  final String? studentId;
  final String? gradeResultId;
}

class QuarantinedFile {
  const QuarantinedFile({
    required this.id,
    required this.uploadId,
    required this.displayName,
    required this.sizeBytes,
    required this.scanState,
  });

  final String id;
  final String uploadId;
  final String displayName;
  final int sizeBytes;
  final String scanState;
}

/// An attachment as it arrives on something already stored.
///
/// Carries no URL and never will: opening one is a separate, single-use grant
/// the server issues to the person asking. [scanState] is what decides whether
/// it can be opened at all - anything other than `clean` is still in the
/// pipeline, or was refused by it.
class StoredAttachment {
  const StoredAttachment({
    required this.id,
    required this.displayName,
    required this.sizeBytes,
    required this.scanState,
    this.mediaType,
  });

  final String id;
  final String displayName;
  final int sizeBytes;
  final String scanState;
  final String? mediaType;

  bool get isReady => scanState == 'clean';
}

abstract interface class FileUploadRepository {
  Future<QuarantinedFile> upload(FileUploadCommand command);

  /// Turns an uploaded `lesson_resource` into class material.
  ///
  /// The class is not a parameter: it was fixed when the upload intent was
  /// issued and the server reads it from the file object, so a caller cannot
  /// publish someone else's upload into a class of their choosing.
  ///
  /// Returns the resource id. Throws if the file is not publishable - most
  /// often because the scan has not cleared it yet.
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  });
}

enum FileAudience {
  students('students'),
  guardians('guardians'),
  both('both');

  const FileAudience(this.wireValue);
  final String wireValue;
}
