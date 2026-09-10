import '../../../studafy_database.dart';
import '../domain/teacher_dashboard_repository.dart';

final class PreviewTeacherDashboardRepository
    implements TeacherDashboardRepository {
  const PreviewTeacherDashboardRepository();

  @override
  Future<int> unreadNotificationCount() =>
      StudafyDatabase.instance.unreadNotificationCount();

  @override
  Future<AttendanceRoster?> attendanceRoster(String classLabel) async {
    final classId = await StudafyDatabase.instance.classIdForLabel(classLabel);
    if (classId == null) return null;
    final rows = await StudafyDatabase.instance.students(classId);
    return AttendanceRoster(
      classId: classId,
      students: [
        for (final row in rows)
          AttendanceStudent(localId: row['id'] as int, name: '${row['name']}'),
      ],
    );
  }

  @override
  Future<void> saveAttendance(
    int classId,
    DateTime day,
    Map<int, AttendanceEntry> entries,
  ) => StudafyDatabase.instance.saveAttendanceDetails(classId, day, {
    for (final entry in entries.entries)
      entry.key: <String, String?>{
        'status': entry.value.status,
        'reason': entry.value.reason,
      },
  });

  @override
  Future<bool> saveNotebook({
    required String classLabel,
    required String lesson,
    required String homework,
  }) async {
    final classId = await StudafyDatabase.instance.classIdForLabel(classLabel);
    if (classId == null) return false;
    await StudafyDatabase.instance.saveNotebook(classId, lesson, homework);
    return true;
  }
}
