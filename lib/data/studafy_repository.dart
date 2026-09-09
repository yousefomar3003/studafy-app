import 'package:flutter/foundation.dart';

import '../core/studafy_domain.dart';

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

abstract interface class SubscriptionRepository {
  Future<SubscriptionEntitlement> entitlement();
  Future<void> purchaseInsightsMonthly();
  Future<void> restorePurchases();
}

@immutable
class SubscriptionEntitlement {
  const SubscriptionEntitlement({
    required this.active,
    required this.source,
    this.expiresAt,
  });

  final bool active;
  final String source;
  final DateTime? expiresAt;
}

abstract interface class PaperGradingRepository {
  Future<AiGradingDraft> proposeGrade({
    required String submissionId,
    required Uri privateScan,
    required GradingStrictness strictness,
  });

  Future<void> reviewDraft({
    required String draftId,
    required List<QuestionSuggestion> finalScores,
    required String reviewerId,
  });

  Future<void> publishGradeResult({required String gradeResultId});
}

enum GradingStrictness { strict, balanced, lenient }
