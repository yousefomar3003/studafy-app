import 'package:flutter/foundation.dart';

enum FilePurpose {
  profileImage('profile_image'),
  lessonResource('lesson_resource'),
  assignmentMaterial('assignment_material'),
  assignmentSubmission('assignment_submission'),
  paperScan('paper_scan'),
  messageAttachment('message_attachment'),
  announcementAttachment('announcement_attachment'),

  /// A photo of the lesson whiteboard, for Studafy Plus to turn into notes.
  notebookPhoto('notebook_photo'),

  /// A photo a student sends the study helper (Studafy Plus).
  assistantAttachment('assistant_attachment');

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

  /// The scan refused it after it was attached (or gave up on it, or an
  /// operator contained it), so it will never open: the server keeps it on
  /// the list as `rejected`, `error` or - once its bytes are gone -
  /// `deleted`, so readers are told rather than left waiting for it.
  bool get isRemoved =>
      const {'rejected', 'error', 'deleted'}.contains(scanState);
}

/// A file's bytes, fetched for the person who asked and nobody else.
class DownloadedFile {
  const DownloadedFile({
    required this.displayName,
    required this.mediaType,
    required this.bytes,
  });

  final String displayName;
  final String mediaType;
  final Uint8List bytes;

  bool get isImage => mediaType.startsWith('image/');
}

/// The server this app talks to has file uploads or delivery switched off.
///
/// Not a fault of the file or of the connection, and retrying will not help,
/// so screens say so plainly instead of "check your connection".
class FileServiceUnavailable implements Exception {
  const FileServiceUnavailable();

  @override
  String toString() => 'FileServiceUnavailable';
}

/// Where a file stands in the scan.
///
/// A file is attachable while it is still being checked, so a screen that
/// shows it keeps asking until the scan decides; when the scan refuses it the
/// person is told why, instead of the file "checking" for ever and the form
/// failing on submit (2026-10-15).
@immutable
class FileScanStatus {
  const FileScanStatus({required this.scanState, this.failureCode});

  final String scanState;

  /// Why the scan refused the file (`malformed_file`, `malware_detected`,
  /// `encrypted_document`, ...), when it did.
  final String? failureCode;

  bool get isClean => scanState == 'clean';

  /// The scan has decided against the file; it will never become clean.
  bool get isRefused =>
      const {'rejected', 'deleted', 'error'}.contains(scanState);
}

/// Implemented by repositories that can say how a file's scan went. Kept
/// apart from [FileUploadRepository] so previews and test fakes need not.
abstract interface class FileScanStatusSource {
  Future<FileScanStatus> scanStatus(String fileId);
}

abstract interface class FileUploadRepository {
  Future<QuarantinedFile> upload(FileUploadCommand command);

  /// Fetches an attachment the caller may open.
  ///
  /// Asks for a single-use delivery grant and spends it at once, so nothing
  /// that could be replayed is ever kept. Throws when the caller may not open
  /// the file, or when it has not cleared the scan yet.
  Future<DownloadedFile> download(String fileId);

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
