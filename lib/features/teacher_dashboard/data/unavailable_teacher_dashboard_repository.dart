import '../domain/teacher_dashboard_repository.dart';

final class UnavailableTeacherDashboardRepository
    implements TeacherDashboardRepository {
  const UnavailableTeacherDashboardRepository();

  Never get _unavailable => throw const TeacherDashboardUnavailable();

  @override
  Future<int> unreadNotificationCount() async => _unavailable;

  @override
  Future<AttendanceRoster?> attendanceRoster(String classLabel) async =>
      _unavailable;

  @override
  Future<void> saveAttendance(
    int classId,
    DateTime day,
    Map<int, AttendanceEntry> entries,
  ) async => _unavailable;

  @override
  Future<bool> saveNotebook({
    required String classLabel,
    required String lesson,
    required String homework,
  }) async => _unavailable;
}
