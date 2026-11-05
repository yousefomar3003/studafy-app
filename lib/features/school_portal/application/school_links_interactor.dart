import 'package:flutter/foundation.dart';

import '../../../core/result.dart';
import '../../../core/telemetry.dart';
import '../domain/school_links.dart';

/// The teacher's School Portal use cases. Presentation calls this, never
/// the repository (ARC-011). Telemetry carries decisions and counts only,
/// never a school's or person's name.
class SchoolLinksInteractor {
  SchoolLinksInteractor({required this.links, required this.telemetry});

  final SchoolLinksRepository links;
  final Telemetry telemetry;

  /// The last list read, for the "visible to" banner on the Today and
  /// Classes tabs. Null until first read; every change below re-reads it.
  final ValueNotifier<List<SchoolLink>?> current = ValueNotifier(null);

  /// The school the teacher's classes are visible to now, if any.
  SchoolLink? get linked =>
      current.value?.where((link) => link.isLinked).firstOrNull;

  Future<Result<List<SchoolLink>>> load() => runCatching(() async {
    final list = await links.list();
    current.value = list;
    return list;
  });

  Future<Result<void>> decide(
    SchoolLink link, {
    required bool accept,
    bool replaceCurrent = false,
  }) => runCatching(() async {
    await links.decide(link.id, accept: accept, replaceCurrent: replaceCurrent);
    telemetry.event('school_link_decided', {
      'decision': accept ? 'accept' : 'decline',
      'replaced': accept && replaceCurrent,
    });
    await _refresh();
  });

  Future<Result<void>> unlink(SchoolLink link) => runCatching(() async {
    await links.unlink(link.id);
    telemetry.event('school_unlinked', const {});
    await _refresh();
  });

  Future<Result<void>> report(
    SchoolLink link, {
    required SchoolReportReason reason,
    String? details,
  }) => runCatching(() async {
    await links.report(link.id, reason: reason, details: details);
    telemetry.event('school_reported', {'reason': reason.code});
  });

  /// A failed re-read leaves the last list; the change itself succeeded.
  Future<void> _refresh() async {
    try {
      current.value = await links.list();
    } on Object {
      return;
    }
  }
}
