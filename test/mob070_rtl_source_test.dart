import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MOB-070 (ADR-0028): a source-level ratchet for right-to-left correctness.
///
/// Widget tests only cover screens someone remembered to write a test for.
/// This walks the real-build presentation code instead, so a `fromLTRB` added
/// to a screen with no Arabic test still fails the build.
///
/// `lib/legacy/` and the synthetic-only parent screens are excluded on
/// purpose: they are unreachable outside synthetic builds and MOB-070 removes
/// them. That exclusion is recorded as a bounded decision, not a permanent
/// one — when those modules go, delete the exclusions with them.
void main() {
  /// Directories whose screens a real school user can actually reach.
  const inScope = <String>[
    'lib/features/session/presentation',
    'lib/features/account/presentation',
    'lib/features/academic/presentation',
    'lib/features/classes/presentation',
    'lib/features/teacher_dashboard/presentation',
    'lib/features/messaging/presentation',
    'lib/features/family/presentation',
    'lib/features/notifications/presentation',
    'lib/app',
    'lib/core',
  ];

  /// Patterns that pin a layout to one direction, with what to use instead.
  const directionPinning = <String, String>{
    'EdgeInsets.fromLTRB(': 'EdgeInsetsDirectional.fromSTEB',
    'EdgeInsets.only(left:': 'EdgeInsetsDirectional.only(start:',
    'EdgeInsets.only(right:': 'EdgeInsetsDirectional.only(end:',
    'Alignment.centerLeft': 'AlignmentDirectional.centerStart',
    'Alignment.centerRight': 'AlignmentDirectional.centerEnd',
    'Alignment.topLeft': 'AlignmentDirectional.topStart',
    'Alignment.topRight': 'AlignmentDirectional.topEnd',
    'Alignment.bottomLeft': 'AlignmentDirectional.bottomStart',
    'Alignment.bottomRight': 'AlignmentDirectional.bottomEnd',
    'Positioned(left:': 'PositionedDirectional',
    'Positioned(right:': 'PositionedDirectional',
    'TextAlign.left': 'TextAlign.start',
    'TextAlign.right': 'TextAlign.end',
  };

  List<File> sources() => [
    for (final path in inScope)
      if (Directory(path).existsSync())
        ...Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
  ];

  test('no reachable screen pins its layout to left-to-right', () {
    final offences = <String>[];
    for (final file in sources()) {
      final source = file.readAsStringSync();
      for (final entry in directionPinning.entries) {
        if (source.contains(entry.key)) {
          offences.add('${file.path}: ${entry.key} → use ${entry.value}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason: 'these would not mirror in Arabic:\n${offences.join('\n')}',
    );
  });

  test('no reachable screen hardcodes a one-way chevron', () {
    // Material mirrors AppBar's leading and BackButton for itself, but not
    // these: in Arabic they point backwards. `forwardChevron(context)` in
    // core/studafy_design.dart picks the right one.
    final offences = <String>[];
    for (final file in sources()) {
      if (file.path.endsWith('core/studafy_design.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('Icons.chevron_right') ||
          source.contains('Icons.chevron_left')) {
        offences.add(file.path);
      }
    }

    expect(
      offences,
      isEmpty,
      reason: 'use forwardChevron(context):\n${offences.join('\n')}',
    );
  });

  test('copy is never looked up by a runtime value', () {
    // The one shape that would break "we never translate user content":
    // handing the lookup a value instead of a key written in the source. A
    // key may interpolate the app's own vocabulary — `'role.\${role.name}'`
    // is fine — but `t(failure.message)` would try to translate text a person
    // or the server wrote. The generated class has no string-keyed form at
    // all, so only the legacy table can express this.
    final offences = <String>[];
    final legacyLookup = RegExp(r'\.text\(\s*([^)]*)\)');
    for (final file in sources()) {
      final source = file.readAsStringSync();
      for (final match in legacyLookup.allMatches(source)) {
        final argument = match.group(1)!.trim();
        final isLiteral = argument.startsWith("'") || argument.startsWith('"');
        if (!isLiteral) {
          offences.add('${file.path}: .text($argument)');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'a copy key must be a literal, never a runtime value:\n'
          '${offences.join('\n')}',
    );
  });
}
