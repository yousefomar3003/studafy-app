import 'package:flutter/foundation.dart';

/// What a notification is about, so a tap can open exactly that.
enum NotificationTargetKind {
  /// A conversation (a new message in it).
  conversation,

  /// A piece of set work.
  assignment,

  /// An assessment: an online test to sit, or one to mark.
  assessment,

  /// The marks of a whole assessment, published or corrected.
  assessmentGrades,

  /// One published mark.
  grade,

  /// A lesson or other class material.
  resource,

  /// A wellbeing note shared with the family.
  wellbeing,

  /// A school announcement.
  announcement,

  /// A class meeting.
  meeting,

  /// A request, approval or end of a family (guardian) link.
  guardianLink,

  /// A study plan, Family+ or AI Marking subscription; [NotificationTarget.id]
  /// is the plan's feature key.
  plan,

  /// A safety report the person made.
  report,

  /// A school's request to link with the teacher (School Portal).
  schoolLink,
}

/// The one thing a notification opens: a kind and the server's id for it.
///
/// Only ids the notification already carried in the person's own feed; a
/// push never carries any of them (it names only the notification).
@immutable
class NotificationTarget {
  const NotificationTarget(this.kind, this.id);

  final NotificationTargetKind kind;
  final String id;

  /// The `route` a notification is stored with, `kind:id`.
  String get route => '${kind.name}:$id';

  /// Reads [NotificationTarget.route] back; null for anything else.
  static NotificationTarget? parse(String? route) {
    if (route == null) return null;
    final split = route.indexOf(':');
    if (split <= 0) return null;
    final kind = NotificationTargetKind.values
        .where((value) => value.name == route.substring(0, split))
        .firstOrNull;
    final id = _plain(route.substring(split + 1));
    return kind == null || id == null ? null : NotificationTarget(kind, id);
  }

  /// What [templateKey]'s notification is about, from its server payload.
  /// Null for a kind that opens nothing beyond itself, or a payload without
  /// a usable id.
  static NotificationTarget? fromPayload(
    String templateKey,
    Map<String, dynamic> payload,
  ) {
    final (kind, field) = _routing(templateKey) ?? (null, '');
    final value = payload[field];
    final id = value is String ? _plain(value) : null;
    return kind == null || id == null ? null : NotificationTarget(kind, id);
  }

  /// What kind of thing [templateKey]'s notifications are about, whether or
  /// not this one carries the id: one stored before notifications had
  /// routes still opens the right tab.
  static NotificationTargetKind? kindOf(String templateKey) =>
      _routing(templateKey)?.$1;

  /// Each template key's kind, and the payload field holding its id
  /// (supabase/migrations: each emitter's latest payload).
  static (NotificationTargetKind, String)? _routing(
    String templateKey,
  ) => switch (templateKey) {
    'communications.message_sent' => (
      NotificationTargetKind.conversation,
      'conversationId',
    ),
    'communications.announcement_created' => (
      NotificationTargetKind.announcement,
      'id',
    ),
    'academic.assignment_published' => (
      NotificationTargetKind.assignment,
      'entityId',
    ),
    'academic.assessment_published' => (
      NotificationTargetKind.assessment,
      'entityId',
    ),
    'academic.grades_published' || 'academic.grades_corrected' => (
      NotificationTargetKind.assessmentGrades,
      'entityId',
    ),
    'academic.grade_published' => (NotificationTargetKind.grade, 'entityId'),
    'academic.resource_published' => (
      NotificationTargetKind.resource,
      'entityId',
    ),
    'academic.wellbeing_shared' => (
      NotificationTargetKind.wellbeing,
      'entityId',
    ),
    'meetings.scheduled' ||
    'meetings.failed' => (NotificationTargetKind.meeting, 'meetingId'),
    'meetings.requested' ||
    'meetings.cancelled' => (NotificationTargetKind.meeting, 'id'),
    'family.guardian_link_requested' ||
    'family.guardian_link_verified' ||
    'family.guardian_link_revoked' => (
      NotificationTargetKind.guardianLink,
      'id',
    ),
    'school_portal.link_requested' => (NotificationTargetKind.schoolLink, 'id'),
    'safety.report_resolved' ||
    'safety.report_escalated' => (NotificationTargetKind.report, 'reportId'),
    _ when templateKey.startsWith('billing.') => (
      NotificationTargetKind.plan,
      'featureKey',
    ),
    _ => null,
  };

  /// Ids and feature keys only: the payload comes from the server, but is
  /// still kept to plain ids before it reaches a screen.
  static String? _plain(String value) {
    final id = value.trim();
    final valid =
        id.isNotEmpty &&
        id.length <= 64 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
    return valid ? id : null;
  }
}
