import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/studafy_formatting.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// The plans keep their Latin names in Arabic ("Family+", "Studafy Plus",
/// "Studafy Max"). Inside a right-to-left line the bidirectional algorithm
/// reorders a neutral character at a name's edge: "Family+" was drawn as
/// "+Family". Every such name in Arabic copy sits in a left-to-right isolate
/// (U+2066 … U+2069).
void main() {
  const lri = '\u2066';
  const pdi = '\u2069';

  /// Texts whose exact words a consent records (their SHA-256 is published,
  /// see policy_consent_version_test.dart and ai_consent_version_test.dart):
  /// they are isolated as they are shown, not edited.
  const hashed = {
    'policyTermsBody',
    'policyPrivacyBody',
    'aiConsentNoticeBody',
  };

  test('every plan name in the Arabic copy is isolated left to right', () {
    final arb = jsonDecode(
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final bare = <String>[];
    for (final MapEntry(:key, :value) in arb.entries) {
      if (key.startsWith('@') || hashed.contains(key) || value is! String) {
        continue;
      }
      for (final name in studafyPlanNames) {
        var at = value.indexOf(name);
        while (at >= 0) {
          final end = at + name.length;
          final isolated =
              at > 0 &&
              value[at - 1] == lri &&
              end < value.length &&
              value[end] == pdi;
          if (!isolated) bare.add('$key: $name');
          at = value.indexOf(name, end);
        }
      }
    }
    expect(bare, isEmpty);
  });

  test('the hashed texts are isolated as they are shown', () {
    final ar = lookupAppL10n(const Locale('ar'));
    for (final text in [ar.policyTermsBody, ar.policyPrivacyBody]) {
      final shown = studafyIsolatePlanNames(text);
      for (final name in studafyPlanNames) {
        expect(
          shown.contains(name),
          text.contains(name),
          reason: 'the words stay the same: $name',
        );
        if (text.contains(name)) {
          expect(shown, contains('$lri$name$pdi'));
        }
      }
      // Isolating twice changes nothing.
      expect(studafyIsolatePlanNames(shown), shown);
    }
    expect(studafyPlanName('Family+'), '${lri}Family+$pdi');
  });

  /// Where the first and last characters of [name] are drawn, inside an
  /// Arabic sentence laid out right to left.
  (double, double) firstAndLast(String sentence, String name) {
    final painter = TextPainter(
      text: TextSpan(text: sentence),
      textDirection: TextDirection.rtl,
    )..layout();
    final start = sentence.indexOf(name);
    final end = start + name.length - 1;
    double left(int i) => painter
        .getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))
        .single
        .left;
    final result = (left(start), left(end));
    painter.dispose();
    return result;
  }

  test('an isolated name reads left to right inside an Arabic line', () {
    for (final name in studafyPlanNames) {
      final (first, last) = firstAndLast(
        'يشمل ${studafyPlanName(name)} لديك',
        name,
      );
      expect(first, lessThan(last), reason: name);
    }
    // The bug the isolates fix: bare, the "+" is drawn before the name.
    final (first, last) = firstAndLast('يشمل Family+ لديك', 'Family+');
    expect(first, greaterThan(last));
  });

  testWidgets('the Arabic Family+ tab label is isolated', (tester) async {
    final ar = lookupAppL10n(const Locale('ar'));
    expect(ar.insightsTitle, '${lri}Family+$pdi');
    final (first, last) = firstAndLast(ar.insightsTitle, 'Family+');
    expect(first, lessThan(last));
  });
}
