import 'package:flutter/foundation.dart';

/// Branded identifiers (ARC-011). All are String-backed because the
/// authoritative backend uses UUID keys; legacy SQLite integer ids are
/// converted only inside data adapters, never in presentation code.
@immutable
class UserId {
  const UserId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is UserId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

@immutable
class SchoolId {
  const SchoolId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is SchoolId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

@immutable
class TermId {
  const TermId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is TermId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

@immutable
class MembershipId {
  const MembershipId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is MembershipId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

@immutable
class StudentId {
  const StudentId(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is StudentId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

@immutable
class ClassroomId {
  const ClassroomId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is ClassroomId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
