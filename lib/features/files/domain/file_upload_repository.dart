import 'dart:typed_data';

enum FilePurpose {
  profileImage('profile_image'),
  lessonResource('lesson_resource'),
  assignmentMaterial('assignment_material'),
  assignmentSubmission('assignment_submission'),
  paperScan('paper_scan');

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

abstract interface class FileUploadRepository {
  Future<QuarantinedFile> upload(FileUploadCommand command);
}
