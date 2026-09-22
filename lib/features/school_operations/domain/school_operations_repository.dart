import 'package:flutter/foundation.dart';

class ManagedClassroom {
  const ManagedClassroom({required this.id, required this.name});
  final String id;
  final String name;
}

@immutable
class SchoolTerm {
  const SchoolTerm({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.status,
  });
  final String id;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final String status;
}

@immutable
class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.displayName,
    required this.studafyId,
  });
  final String id;
  final String displayName;
  final String studafyId;
}

@immutable
class ClassroomStaffMember {
  const ClassroomStaffMember({
    required this.assignmentId,
    required this.userId,
    required this.displayName,
    required this.role,
  });
  final String assignmentId;
  final String userId;
  final String displayName;
  final String role;
}

@immutable
class ManagedMeeting {
  const ManagedMeeting({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.state,
    required this.version,
    required this.recipientCount,
    this.meetUrl,
  });
  final String id;
  final String classroomId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String audience;
  final String state;
  final int version;
  final int recipientCount;
  final Uri? meetUrl;
}

abstract interface class SchoolOperationsRepository {
  Future<List<SchoolTerm>> listTerms();
  Future<SchoolTerm> createTerm({
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
  });

  Future<List<RosterStudent>> listStudents(String classroomId);
  Future<RosterStudent> createStudent({
    required String displayName,
    String? userId,
  });
  Future<void> enrollStudent({
    required String classroomId,
    required String studentId,
  });
  Future<void> withdrawStudent({
    required String classroomId,
    required String studentId,
  });
  Future<void> transferStudent({
    required String classroomId,
    required String studentId,
    required String targetClassroomId,
  });

  Future<List<ClassroomStaffMember>> listStaff(String classroomId);
  Future<void> assignStaff({
    required String classroomId,
    required String userId,
    required String role,
  });
  Future<void> removeStaff({
    required String classroomId,
    required String assignmentId,
  });

  Future<String> verifyGuardianLink({
    required String linkId,
    int? expiresInDays,
  });
  Future<String> revokeGuardianLink(String linkId);

  Future<ManagedMeeting> requestMeeting({
    required String classroomId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    required String audience,
  });
  Future<ManagedMeeting> getMeeting(String meetingId);
  Future<ManagedMeeting> cancelMeeting({
    required String meetingId,
    required int expectedVersion,
  });
}
