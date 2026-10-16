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

  test('dates and times shown in the app keep Western digits', () {
    // MaterialLocalizations and intl give Arabic-Indic digits under `ar`;
    // the app shows 0-9 in both languages (core/studafy_formatting.dart).
    // Every screen formats through that file, which converts the digits.
    final direct = RegExp(
      r'\.format(MediumDate|FullDate|ShortDate|CompactDate|ShortMonthDay|'
      r'MonthYear|TimeOfDay|Year|Hour|Minute|Decimal)\(|'
      r'\b(DateFormat|NumberFormat)\.(?!EEEE\(|MMM\()[A-Za-z]+\(',
    );
    final offences = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.contains('/generated/') ||
          path.endsWith('core/studafy_formatting.dart') ||
          // The Material localizations override: it calls Flutter's
          // formatters in order to rewrite their digits.
          path.endsWith('core/studafy_material_localizations.dart')) {
        continue;
      }
      for (final match in direct.allMatches(file.readAsStringSync())) {
        offences.add('$path: ${match.group(0)}');
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'use the studafy* formatters in core/studafy_formatting.dart:\n'
          '${offences.join('\n')}',
    );
  });

  test('the built-in pickers get the Western-digit Arabic localizations', () {
    // showDatePicker, showDateRangePicker, showTimePicker and friends format
    // with MaterialLocalizations, not the studafy* formatters. The override
    // only applies if it is registered ahead of Flutter's Material delegate,
    // since the first delegate that supports a locale wins. The test
    // scaffold must match, or the picker tests prove nothing about the app.
    for (final path in ['lib/main.dart', 'test/support/localized_app.dart']) {
      final source = File(path).readAsStringSync();
      final ours = source.indexOf(
        'StudafyArabicMaterialLocalizations.delegate',
      );
      final flutters = source.indexOf('GlobalMaterialLocalizations.delegate');
      expect(ours, isNot(-1), reason: '$path does not register it');
      expect(
        ours,
        lessThan(flutters),
        reason: '$path registers it after Flutter\'s, so it is never used',
      );
    }
  });

  test('no screen uses a Cupertino date or time picker', () {
    // Cupertino pickers format with CupertinoLocalizations, which the
    // Western-digit override does not cover, so they would show ٠-٩ in
    // Arabic. Adding one means overriding those localizations too
    // (core/studafy_material_localizations.dart shows how).
    final picker = RegExp(r'\bCupertino(DatePicker|TimerPicker)\b');
    final offences = <String>[
      for (final file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') &&
            picker.hasMatch(file.readAsStringSync()))
          file.path,
    ];

    expect(
      offences,
      isEmpty,
      reason:
          'Cupertino pickers need Western-digit CupertinoLocalizations '
          'first:\n${offences.join('\n')}',
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
