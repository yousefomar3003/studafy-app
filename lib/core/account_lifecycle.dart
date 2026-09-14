import 'package:flutter/foundation.dart';

/// Account-lifecycle value types shared by the session and account slices
/// (AUTH-030).
///
/// They live in core rather than in either feature because both need them and
/// features may not import one another: deletion is requested through the
/// session's authenticated surface but presented by the account screen.

/// What deleting this account does, as computed by the server.
///
/// [retainedSchoolRecords] is shown to the user rather than hidden. A student
/// cannot delete records the school owns, and stating that with counts is the
/// difference between a lawful retention boundary and what a store reviewer
/// reads as a deletion flow that does not work.
@immutable
class DeletionImpact {
  const DeletionImpact({
    required this.schools,
    required this.retainedSchoolRecords,
    required this.deletedPersonalRecords,
    required this.gracePeriodDays,
  });

  final List<String> schools;
  final Map<String, int> retainedSchoolRecords;
  final Map<String, int> deletedPersonalRecords;
  final int gracePeriodDays;

  int get retainedTotal =>
      retainedSchoolRecords.values.fold(0, (sum, value) => sum + value);
}

/// A scheduled deletion request.
@immutable
class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.state,
    required this.executeAfter,
  });

  final String id;
  final String state;
  final DateTime executeAfter;

  /// Whether the user can still stop it from inside the app.
  bool get isCancellable => state == 'grace_period';
}
