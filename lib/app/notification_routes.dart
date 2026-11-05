import 'dart:async';

import 'package:flutter/material.dart';

import '../core/feedback.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/messaging/presentation/conversations_page.dart';
import '../features/notifications/domain/notification.dart';
import '../l10n/generated/app_l10n.dart';

/// A record a tapped notification asks a feed to open. Compared by
/// identity, so tapping the same notification twice opens it twice.
class FeedTarget {
  FeedTarget(this.feed, this.id);

  /// The feed the record is in.
  final AcademicFeed feed;

  /// The record (or the assessment or assignment a mark is for); null opens
  /// the feed only.
  final String? id;
}

/// Where one role's shell can take a notification. Null for a place that
/// role does not have; [openNotificationIn] then falls back further.
class NotificationDestinations {
  const NotificationDestinations({
    this.feed,
    this.lessons,
    this.messages,
    this.announcements,
    this.meetings,
    this.family,
    this.plans,
    this.reports,
    this.schoolLinks,
    this.schoolAnnouncements,
  });

  /// Shows [FeedTarget.feed] and opens [FeedTarget.id] in it, as a tap on
  /// its row would; the feed says when the record is gone.
  final void Function(FeedTarget target)? feed;

  /// The class material, for a new lesson ([lessons] is given its id).
  final void Function(String? resourceId)? lessons;

  /// The inbox, when a conversation cannot be opened directly.
  final VoidCallback? messages;
  final VoidCallback? announcements;
  final VoidCallback? meetings;
  final VoidCallback? family;

  /// The plan page for a subscription notification, given its feature key.
  final void Function(String? featureKey)? plans;
  final VoidCallback? reports;

  /// A school's link request, given its id (teachers only).
  final void Function(String? linkId)? schoolLinks;

  /// Announcements from schools (any role).
  final VoidCallback? schoolAnnouncements;
}

/// Opens exactly what [item] is about, in the shell [destinations] are for:
/// the conversation, the piece of work or test, the mark, and so on, falling
/// back to the tab it is in. Returns false when this role has nowhere to
/// take it; the caller then shows the notifications list (or, from the
/// list, says there is nothing more to open).
///
/// Only ids the person's own feed carried are used, and every screen reads
/// what it shows through the API as the person signed in - a notification
/// cannot open anything they could not reach themselves.
bool openNotificationIn(
  BuildContext context,
  NotificationItem item,
  NotificationDestinations destinations,
) {
  final target = item.target;
  final kind = target?.kind ?? NotificationTarget.kindOf(item.templateKey);
  final id = target?.id;
  bool feed(AcademicFeed feed) {
    final open = destinations.feed;
    if (open == null) return false;
    open(FeedTarget(feed, id));
    return true;
  }

  bool call(VoidCallback? open) {
    if (open == null) return false;
    open();
    return true;
  }

  switch (kind) {
    case NotificationTargetKind.conversation:
      final inbox = destinations.messages;
      if (inbox == null) return false;
      if (id == null) return call(inbox);
      unawaited(_openConversation(context, id, inbox));
      return true;
    case NotificationTargetKind.assignment:
      return feed(AcademicFeed.assignments);
    case NotificationTargetKind.assessment:
      return feed(AcademicFeed.assessments);
    case NotificationTargetKind.assessmentGrades:
    case NotificationTargetKind.grade:
      return feed(AcademicFeed.grades);
    case NotificationTargetKind.wellbeing:
      return feed(AcademicFeed.wellbeing);
    case NotificationTargetKind.resource:
      final lessons = destinations.lessons;
      if (lessons != null) {
        lessons(id);
        return true;
      }
      return feed(AcademicFeed.content);
    case NotificationTargetKind.announcement:
      return call(destinations.announcements ?? destinations.messages);
    case NotificationTargetKind.meeting:
      return call(destinations.meetings);
    case NotificationTargetKind.guardianLink:
      return call(destinations.family);
    case NotificationTargetKind.plan:
      final plans = destinations.plans;
      if (plans == null) return false;
      plans(id);
      return true;
    case NotificationTargetKind.report:
      return call(destinations.reports);
    case NotificationTargetKind.schoolAnnouncement:
      return call(destinations.schoolAnnouncements);
    case NotificationTargetKind.schoolLink:
      final links = destinations.schoolLinks;
      if (links == null) return false;
      links(id);
      return true;
    case null:
      return false;
  }
}

Future<void> _openConversation(
  BuildContext context,
  String id,
  VoidCallback inbox,
) async {
  if (await openConversationById(context, id)) return;
  if (!context.mounted) return;
  // Deleted, left, or not this account's: the inbox, and why.
  inbox();
  showNotificationGone(context);
}

/// Says that what a notification was about is no longer there.
void showNotificationGone(BuildContext context) =>
    ScaffoldMessenger.of(context)
        .showMessage(AppL10n.of(context).notificationGone);
