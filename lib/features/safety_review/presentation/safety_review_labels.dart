import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/safety_review.dart';

/// The words and marks the review screens use for a report's facts. Never
/// colour alone: every priority is written out too.

String safetyKindLabel(AppL10n l10n, SafetyReviewKind kind) => switch (kind) {
  SafetyReviewKind.message => l10n.safetyReviewKindMessage,
  SafetyReviewKind.conversation => l10n.safetyReviewKindConversation,
  SafetyReviewKind.user => l10n.safetyReviewKindUser,
};

IconData safetyKindIcon(SafetyReviewKind kind) => switch (kind) {
  SafetyReviewKind.message => Icons.chat_bubble_outline_rounded,
  SafetyReviewKind.conversation => Icons.forum_outlined,
  SafetyReviewKind.user => Icons.person_outline_rounded,
};

String safetyPriorityLabel(AppL10n l10n, SafetyReviewPriority priority) =>
    switch (priority) {
      SafetyReviewPriority.critical => l10n.safetyReviewPriorityCritical,
      SafetyReviewPriority.high => l10n.safetyReviewPriorityHigh,
      SafetyReviewPriority.medium => l10n.safetyReviewPriorityMedium,
      SafetyReviewPriority.low => l10n.safetyReviewPriorityLow,
    };

/// Dark enough on the pill's pale wash for the contrast check.
Color safetyPriorityColor(SafetyReviewPriority priority) => switch (priority) {
  SafetyReviewPriority.critical || SafetyReviewPriority.high => studafyDanger,
  SafetyReviewPriority.medium => studafyNavy,
  SafetyReviewPriority.low => studafyInk,
};

IconData safetyPriorityIcon(SafetyReviewPriority priority) =>
    switch (priority) {
      SafetyReviewPriority.critical => Icons.priority_high_rounded,
      SafetyReviewPriority.high => Icons.warning_amber_rounded,
      SafetyReviewPriority.medium => Icons.remove_rounded,
      SafetyReviewPriority.low => Icons.low_priority_rounded,
    };

String safetyStatusLabel(AppL10n l10n, String status) => switch (status) {
  'submitted' => l10n.safetyReviewStatusSubmitted,
  'queued' => l10n.safetyReviewStatusQueued,
  'under_review' => l10n.safetyReviewStatusUnderReview,
  'on_hold' => l10n.safetyReviewStatusOnHold,
  'escalated' => l10n.safetyReviewStatusEscalated,
  'resolved' => l10n.safetyReviewStatusResolved,
  'withdrawn' => l10n.safetyReviewStatusWithdrawn,
  _ => status,
};

String safetyOutcomeLabel(AppL10n l10n, SafetyReviewOutcome outcome) =>
    switch (outcome) {
      SafetyReviewOutcome.upheld => l10n.safetyReviewOutcomeUpheld,
      SafetyReviewOutcome.partial => l10n.safetyReviewOutcomePartial,
      SafetyReviewOutcome.notUpheld => l10n.safetyReviewOutcomeNotUpheld,
      SafetyReviewOutcome.noAction => l10n.safetyReviewOutcomeNoAction,
    };

String safetyOutcomeDetail(AppL10n l10n, SafetyReviewOutcome outcome) =>
    switch (outcome) {
      SafetyReviewOutcome.upheld => l10n.safetyReviewOutcomeUpheldDetail,
      SafetyReviewOutcome.partial => l10n.safetyReviewOutcomePartialDetail,
      SafetyReviewOutcome.notUpheld => l10n.safetyReviewOutcomeNotUpheldDetail,
      SafetyReviewOutcome.noAction => l10n.safetyReviewOutcomeNoActionDetail,
    };

/// A resolution as the server writes it, in words.
String safetyResolutionLabel(AppL10n l10n, String resolution) {
  for (final outcome in SafetyReviewOutcome.values) {
    if (outcome.wire == resolution) return safetyOutcomeLabel(l10n, outcome);
  }
  return resolution;
}

String safetyEventLabel(AppL10n l10n, String event) => switch (event) {
  'submitted' => l10n.safetyReviewEventSubmitted,
  'queued' => l10n.safetyReviewEventQueued,
  'triage' => l10n.safetyReviewEventTriage,
  'resolve' => l10n.safetyReviewEventResolve,
  'appeal' => l10n.safetyReviewEventAppeal,
  'escalate' => l10n.safetyReviewEventEscalate,
  _ => event,
};

/// The label for a field captured with the report, or the field's own name
/// for one this screen does not know.
String safetySnapshotLabel(AppL10n l10n, String key) => switch (key) {
  'messageBody' => l10n.safetyReviewSnapshotMessage,
  'subject' => l10n.safetyReviewSnapshotSubject,
  'createdAt' => l10n.safetyReviewSnapshotSentAt,
  'senderId' => l10n.safetyReviewSnapshotSender,
  'conversationId' => l10n.safetyReviewSnapshotConversation,
  'state' => l10n.safetyReviewSnapshotState,
  _ => key,
};

String safetyEvidenceLabel(AppL10n l10n, String kind) => switch (kind) {
  'message' => l10n.safetyReviewEvidenceMessage,
  'attachment' => l10n.safetyReviewEvidenceAttachment,
  _ => l10n.safetyReviewEvidenceNote,
};

/// "Filed 3 hours ago", with Arabic's plural forms.
String safetyFiledAgo(AppL10n l10n, DateTime filedAt, DateTime now) {
  final age = now.difference(filedAt);
  if (age.inMinutes < 1) return l10n.safetyReviewFiledJustNow;
  if (age.inHours < 1) return l10n.safetyReviewFiledMinutes(age.inMinutes);
  if (age.inDays < 1) return l10n.safetyReviewFiledHours(age.inHours);
  return l10n.safetyReviewFiledDays(age.inDays);
}

/// The message for a step that did not go through.
({String title, String body}) safetyErrorText(
  AppL10n l10n,
  SafetyReviewError error,
) => switch (error) {
  SafetyReviewError.noGrant => (
    title: l10n.safetyReviewGrantEndedTitle,
    body: l10n.safetyReviewGrantEndedBody,
  ),
  SafetyReviewError.secondApproverRequired => (
    title: l10n.safetyReviewSecondApproverTitle,
    body: l10n.safetyReviewSecondApproverBody,
  ),
  SafetyReviewError.changed => (
    title: l10n.safetyReviewChangedTitle,
    body: l10n.safetyReviewChangedBody,
  ),
  SafetyReviewError.notEnrolled => (
    title: l10n.safetyReviewNotEnrolledTitle,
    body: l10n.safetyReviewNotEnrolledBody,
  ),
  SafetyReviewError.notOperator => (
    title: l10n.safetyReviewNotOperator,
    body: l10n.safetyReviewListFooter,
  ),
  SafetyReviewError.wrongCode => (
    title: l10n.safetyReviewCodeTitle,
    body: l10n.safetyReviewWrongCode,
  ),
  SafetyReviewError.stepUpRequired => (
    title: l10n.safetyReviewCodeTitle,
    body: l10n.safetyReviewCodeBody,
  ),
  SafetyReviewError.unavailable => (
    title: l10n.safetyReviewLoadFailed,
    body: l10n.safetyReviewUnavailable,
  ),
};
