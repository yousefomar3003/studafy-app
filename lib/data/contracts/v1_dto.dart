import 'package:flutter/foundation.dart';

import '../../core/ids.dart';

/// Dart mirror of the TypeScript `V1MeResponse` contract
/// (packages/contracts/src/v1/me.ts). Field names use snake_case to match
/// the wire format exactly; the drift test validates parity.
@immutable
class V1MembershipDto {
  const V1MembershipDto({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    required this.active,
  });

  factory V1MembershipDto.fromJson(Map<String, dynamic> json) =>
      V1MembershipDto(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        schoolName: json['school_name'] as String,
        role: json['role'] as String,
        active: json['active'] as bool,
      );

  final String id;
  final String schoolId;
  final String schoolName;
  final String role;
  final bool active;

  Map<String, Object?> toJson() => {
    'id': id,
    'school_id': schoolId,
    'school_name': schoolName,
    'role': role,
    'active': active,
  };
}

@immutable
class V1MeResponseDto {
  const V1MeResponseDto({
    required this.id,
    required this.displayName,
    required this.email,
    required this.memberships,
    required this.environment,
    required this.activeTermId,
  });

  factory V1MeResponseDto.fromJson(Map<String, dynamic> json) =>
      V1MeResponseDto(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        email: json['email'] as String,
        memberships: [
          for (final row
              in (json['memberships'] as List<dynamic>)
                  .cast<Map<String, dynamic>>())
            V1MembershipDto.fromJson(row),
        ],
        environment: json['environment'] as String,
        activeTermId: json['active_term_id'] as String?,
      );

  final String id;
  final String displayName;
  final String email;
  final List<V1MembershipDto> memberships;
  final String environment;
  final String? activeTermId;

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'email': email,
    'memberships': [for (final m in memberships) m.toJson()],
    'environment': environment,
    'active_term_id': activeTermId,
  };
}

@immutable
class V1ClassroomDto {
  const V1ClassroomDto({
    required this.id,
    required this.name,
    required this.grade,
    required this.section,
    required this.room,
    required this.studentCount,
    required this.weeklySessions,
    required this.termName,
  });

  factory V1ClassroomDto.fromJson(Map<String, dynamic> json) => V1ClassroomDto(
    id: json['id'] as String,
    name: json['name'] as String,
    grade: json['grade'] as String,
    section: json['section'] as String,
    room: json['room'] as String?,
    studentCount: json['student_count'] as int,
    weeklySessions: json['weekly_sessions'] as int?,
    termName: json['term_name'] as String?,
  );

  final String id;
  final String name;
  final String grade;
  final String section;
  final String? room;
  final int studentCount;
  final int? weeklySessions;
  final String? termName;

  ClassroomId get classroomId => ClassroomId(id);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'grade': grade,
    'section': section,
    'room': room,
    'student_count': studentCount,
    'weekly_sessions': weeklySessions,
    'term_name': termName,
  };
}

@immutable
class V1ClassroomListResponseDto {
  const V1ClassroomListResponseDto({required this.classrooms});

  factory V1ClassroomListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomListResponseDto(
        classrooms: [
          for (final row
              in (json['classrooms'] as List<dynamic>)
                  .cast<Map<String, dynamic>>())
            V1ClassroomDto.fromJson(row),
        ],
      );

  final List<V1ClassroomDto> classrooms;

  Map<String, Object?> toJson() => {
    'classrooms': [for (final c in classrooms) c.toJson()],
  };
}
