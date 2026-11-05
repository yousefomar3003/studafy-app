import 'package:flutter/foundation.dart';

/// A school's request to link with this teacher, or the link itself
/// (Studafy School Portal, docs/planning/school-portal.md section 6).
///
/// While linked, the school's administrators can read - never change -
/// every class the teacher teaches. Only the teacher accepts, declines or
/// ends a link.
enum SchoolLinkStatus {
  pending,
  linked,
  declined,
  cancelled,
  expired,
  unlinked,
}

/// What a school calls itself on its page.
enum SchoolKind { public, private, international, other }

/// Why a teacher reports a school.
enum SchoolReportReason { notMySchool, fakeSchool, pressure, other }

extension SchoolReportReasonCode on SchoolReportReason {
  /// The server's name for the reason.
  String get code => switch (this) {
    SchoolReportReason.notMySchool => 'not_my_school',
    SchoolReportReason.fakeSchool => 'fake_school',
    SchoolReportReason.pressure => 'pressure',
    SchoolReportReason.other => 'other',
  };
}

@immutable
class SchoolLinkOrg {
  const SchoolLinkOrg({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.kind,
    required this.active,
  });

  final String id;

  /// User content: shown through `UserContentText`.
  final String name;
  final String city;
  final String country;
  final SchoolKind kind;

  /// False once the school's page is suspended or closed.
  final bool active;
}

/// The school administrator who sent the request.
@immutable
class SchoolLinkRequester {
  const SchoolLinkRequester({
    required this.name,
    required this.email,
    required this.jobTitle,
  });

  final String name;
  final String? email;
  final String? jobTitle;
}

@immutable
class SchoolLink {
  const SchoolLink({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.org,
    this.requestedBy,
    this.decidedAt,
    this.endedAt,
  });

  final String id;
  final SchoolLinkStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final DateTime? endedAt;
  final SchoolLinkOrg org;
  final SchoolLinkRequester? requestedBy;

  bool get isPending => status == SchoolLinkStatus.pending;
  bool get isLinked => status == SchoolLinkStatus.linked;
}

/// An announcement from a school, to the reader's class, their child's or
/// their own (as a teacher). The school only reaches classes linked with it.
@immutable
class SchoolAnnouncement {
  const SchoolAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.school,
    required this.createdAt,
  });

  final String id;

  /// User content: shown through `UserContentText`.
  final String title;
  final String body;
  final String school;
  final DateTime createdAt;
}

/// A teacher's school links, newest request first; and, for anyone, the
/// school announcements that reach them.
abstract interface class SchoolLinksRepository {
  Future<List<SchoolLink>> list();

  Future<List<SchoolAnnouncement>> announcements();

  /// Accepts or declines a waiting request. Accepting while linked with
  /// another school fails with `LINKED_ELSEWHERE` unless [replaceCurrent]:
  /// a teacher links with one school at a time.
  Future<void> decide(
    String linkId, {
    required bool accept,
    bool replaceCurrent = false,
  });

  /// Ends a link; the school stops seeing the classes at once.
  Future<void> unlink(String linkId);

  Future<void> report(
    String linkId, {
    required SchoolReportReason reason,
    String? details,
  });
}
