class AttendanceStudent {
  const AttendanceStudent({required this.localId, required this.name});

  final int localId;
  final String name;
}

class AttendanceRoster {
  const AttendanceRoster({required this.classId, required this.students});

  final int classId;
  final List<AttendanceStudent> students;
}

class AttendanceEntry {
  const AttendanceEntry({required this.status, this.reason});

  final String status;
  final String? reason;

  AttendanceEntry copyWith({String? status, String? reason}) =>
      AttendanceEntry(status: status ?? this.status, reason: reason);
}

abstract interface class TeacherDashboardRepository {
  Future<int> unreadNotificationCount();

  Future<AttendanceRoster?> attendanceRoster(String classLabel);

  Future<void> saveAttendance(
    int classId,
    DateTime day,
    Map<int, AttendanceEntry> entries,
  );

  Future<bool> saveNotebook({
    required String classLabel,
    required String lesson,
    required String homework,
  });
}

class TeacherDashboardUnavailable implements Exception {
  const TeacherDashboardUnavailable();

  @override
  String toString() =>
      'Teacher records are unavailable until the server repository is enabled.';
}
