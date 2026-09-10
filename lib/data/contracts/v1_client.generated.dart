// GENERATED CODE — DO NOT EDIT.
// Source: packages/contracts/openapi/v1.json
// Regenerate: bun run generate:dart-client

abstract interface class V1JsonTransport {
  Future<Map<String, dynamic>> get(String path);
}

class V1ApiClient {
  const V1ApiClient(this._transport);

  final V1JsonTransport _transport;

  Future<V1MeResponseDto> getMe() async =>
      V1MeResponseDto.fromJson(await _transport.get('/v1/me'));

  Future<V1ClassroomListResponseDto> listClassrooms() async =>
      V1ClassroomListResponseDto.fromJson(
        await _transport.get('/v1/classrooms'),
      );
}

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
          for (final item in json['memberships'] as List<dynamic>)
            V1MembershipDto.fromJson(item as Map<String, dynamic>),
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
    'memberships': [for (final item in memberships) item.toJson()],
    'environment': environment,
    'active_term_id': activeTermId,
  };
}

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

class V1ClassroomListResponseDto {
  const V1ClassroomListResponseDto({required this.classrooms});

  factory V1ClassroomListResponseDto.fromJson(Map<String, dynamic> json) =>
      V1ClassroomListResponseDto(
        classrooms: [
          for (final item in json['classrooms'] as List<dynamic>)
            V1ClassroomDto.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<V1ClassroomDto> classrooms;

  Map<String, Object?> toJson() => {
    'classrooms': [for (final item in classrooms) item.toJson()],
  };
}
