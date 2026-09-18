import '../core/studafy_domain.dart';
export '../features/parent/domain/parent_subscription_repository.dart';

abstract interface class StudafyRepository {
  Future<UserProfile?> currentProfile();
  Future<List<StudentSummary>> linkedStudents();
  Future<int> unreadNotificationCount();
  Future<void> markAllNotificationsRead();
  Future<void> requestAccountDeletion({required String confirmation});
}

abstract interface class MeetingRepository {
  Future<Uri> createGoogleMeet({
    required String classroomId,
    required String title,
    required DateTime startsAt,
    required Duration duration,
    required MeetingAudience audience,
  });

  Future<void> cancelMeeting(String meetingId);
}

enum MeetingAudience { students, guardians, both }
