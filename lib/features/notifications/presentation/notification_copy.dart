import '../../../l10n/generated/app_l10n.dart';

/// The words for a notification the server sent.
///
/// The server sends a stable key (`notification.<area>.<event>.title` or
/// `.detail`), never text, so a notification reads in the reader's language
/// and no account data travels in it. An unknown key - a newer server than
/// this app - reads as a generic update rather than as the raw key.
String notificationCopy(AppL10n l10n, String key) => switch (key) {
  'notification.account.inactive_deletion_warning.title' =>
    l10n.notificationCopyAccountInactiveDeletionWarningTitle,
  'notification.account.inactive_deletion_warning.detail' =>
    l10n.notificationCopyAccountInactiveDeletionWarningDetail,
  'notification.academic.assessment_published.title' =>
    l10n.notificationCopyAcademicAssessmentPublishedTitle,
  'notification.academic.assessment_published.detail' =>
    l10n.notificationCopyAcademicAssessmentPublishedDetail,
  'notification.academic.assignment_published.title' =>
    l10n.notificationCopyAcademicAssignmentPublishedTitle,
  'notification.academic.assignment_published.detail' =>
    l10n.notificationCopyAcademicAssignmentPublishedDetail,
  'notification.academic.grade_published.title' =>
    l10n.notificationCopyAcademicGradePublishedTitle,
  'notification.academic.grade_published.detail' =>
    l10n.notificationCopyAcademicGradePublishedDetail,
  'notification.academic.grades_published.title' =>
    l10n.notificationCopyAcademicGradesPublishedTitle,
  'notification.academic.grades_published.detail' =>
    l10n.notificationCopyAcademicGradesPublishedDetail,
  'notification.academic.grades_corrected.title' =>
    l10n.notificationCopyAcademicGradesCorrectedTitle,
  'notification.academic.grades_corrected.detail' =>
    l10n.notificationCopyAcademicGradesCorrectedDetail,
  'notification.academic.resource_published.title' =>
    l10n.notificationCopyAcademicResourcePublishedTitle,
  'notification.academic.resource_published.detail' =>
    l10n.notificationCopyAcademicResourcePublishedDetail,
  'notification.academic.wellbeing_shared.title' =>
    l10n.notificationCopyAcademicWellbeingSharedTitle,
  'notification.academic.wellbeing_shared.detail' =>
    l10n.notificationCopyAcademicWellbeingSharedDetail,
  'notification.billing.subscription_active.title' =>
    l10n.notificationCopyBillingSubscriptionActiveTitle,
  'notification.billing.subscription_active.detail' =>
    l10n.notificationCopyBillingSubscriptionActiveDetail,
  'notification.billing.subscription_renewed.title' =>
    l10n.notificationCopyBillingSubscriptionRenewedTitle,
  'notification.billing.subscription_renewed.detail' =>
    l10n.notificationCopyBillingSubscriptionRenewedDetail,
  'notification.billing.payment_problem.title' =>
    l10n.notificationCopyBillingPaymentProblemTitle,
  'notification.billing.payment_problem.detail' =>
    l10n.notificationCopyBillingPaymentProblemDetail,
  'notification.billing.subscription_ended.title' =>
    l10n.notificationCopyBillingSubscriptionEndedTitle,
  'notification.billing.subscription_ended.detail' =>
    l10n.notificationCopyBillingSubscriptionEndedDetail,
  'notification.system.push_test.title' =>
    l10n.notificationCopySystemPushTestTitle,
  'notification.system.push_test.detail' =>
    l10n.notificationCopySystemPushTestDetail,
  'notification.meetings.scheduled.title' =>
    l10n.notificationCopyMeetingsScheduledTitle,
  'notification.meetings.scheduled.detail' =>
    l10n.notificationCopyMeetingsScheduledDetail,
  'notification.meetings.failed.title' =>
    l10n.notificationCopyMeetingsFailedTitle,
  'notification.meetings.failed.detail' =>
    l10n.notificationCopyMeetingsFailedDetail,
  'notification.communications.announcement_created.title' =>
    l10n.notificationCopyCommunicationsAnnouncementCreatedTitle,
  'notification.communications.announcement_created.detail' =>
    l10n.notificationCopyCommunicationsAnnouncementCreatedDetail,
  'notification.communications.message_sent.title' =>
    l10n.notificationCopyCommunicationsMessageSentTitle,
  'notification.communications.message_sent.detail' =>
    l10n.notificationCopyCommunicationsMessageSentDetail,
  'notification.family.guardian_link_requested.title' =>
    l10n.notificationCopyFamilyGuardianLinkRequestedTitle,
  'notification.family.guardian_link_requested.detail' =>
    l10n.notificationCopyFamilyGuardianLinkRequestedDetail,
  'notification.family.guardian_link_revoked.title' =>
    l10n.notificationCopyFamilyGuardianLinkRevokedTitle,
  'notification.family.guardian_link_revoked.detail' =>
    l10n.notificationCopyFamilyGuardianLinkRevokedDetail,
  'notification.family.guardian_link_verified.title' =>
    l10n.notificationCopyFamilyGuardianLinkVerifiedTitle,
  'notification.family.guardian_link_verified.detail' =>
    l10n.notificationCopyFamilyGuardianLinkVerifiedDetail,
  'notification.invitations.issued.title' =>
    l10n.notificationCopyInvitationsIssuedTitle,
  'notification.invitations.issued.detail' =>
    l10n.notificationCopyInvitationsIssuedDetail,
  'notification.meetings.cancelled.title' =>
    l10n.notificationCopyMeetingsCancelledTitle,
  'notification.meetings.cancelled.detail' =>
    l10n.notificationCopyMeetingsCancelledDetail,
  'notification.meetings.requested.title' =>
    l10n.notificationCopyMeetingsRequestedTitle,
  'notification.meetings.requested.detail' =>
    l10n.notificationCopyMeetingsRequestedDetail,
  'notification.school_admin.classroom_staff_assigned.title' =>
    l10n.notificationCopySchoolAdminClassroomStaffAssignedTitle,
  'notification.school_admin.classroom_staff_assigned.detail' =>
    l10n.notificationCopySchoolAdminClassroomStaffAssignedDetail,
  'notification.school_admin.classroom_staff_removed.title' =>
    l10n.notificationCopySchoolAdminClassroomStaffRemovedTitle,
  'notification.school_admin.classroom_staff_removed.detail' =>
    l10n.notificationCopySchoolAdminClassroomStaffRemovedDetail,
  'notification.school_admin.membership_granted.title' =>
    l10n.notificationCopySchoolAdminMembershipGrantedTitle,
  'notification.school_admin.membership_granted.detail' =>
    l10n.notificationCopySchoolAdminMembershipGrantedDetail,
  'notification.school_admin.student_enrolled.title' =>
    l10n.notificationCopySchoolAdminStudentEnrolledTitle,
  'notification.school_admin.student_enrolled.detail' =>
    l10n.notificationCopySchoolAdminStudentEnrolledDetail,
  'notification.school_admin.student_transferred.title' =>
    l10n.notificationCopySchoolAdminStudentTransferredTitle,
  'notification.school_admin.student_transferred.detail' =>
    l10n.notificationCopySchoolAdminStudentTransferredDetail,
  'notification.school_admin.student_withdrawn.title' =>
    l10n.notificationCopySchoolAdminStudentWithdrawnTitle,
  'notification.school_admin.student_withdrawn.detail' =>
    l10n.notificationCopySchoolAdminStudentWithdrawnDetail,
  'notification.support_access.approved.title' =>
    l10n.notificationCopySupportAccessApprovedTitle,
  'notification.support_access.approved.detail' =>
    l10n.notificationCopySupportAccessApprovedDetail,
  'notification.support_access.requested.title' =>
    l10n.notificationCopySupportAccessRequestedTitle,
  'notification.support_access.requested.detail' =>
    l10n.notificationCopySupportAccessRequestedDetail,
  'notification.support_access.revoked.title' =>
    l10n.notificationCopySupportAccessRevokedTitle,
  'notification.support_access.revoked.detail' =>
    l10n.notificationCopySupportAccessRevokedDetail,
  'notification.support_access.started.title' =>
    l10n.notificationCopySupportAccessStartedTitle,
  'notification.support_access.started.detail' =>
    l10n.notificationCopySupportAccessStartedDetail,
  'notification.generic.title' => l10n.notificationCopyGenericTitle,
  'notification.generic.detail' => l10n.notificationCopyGenericDetail,
  _ when key.endsWith('.detail') => l10n.notificationCopyGenericDetail,
  _ => l10n.notificationCopyGenericTitle,
};
