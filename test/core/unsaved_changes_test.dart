import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/unsaved_changes.dart';

import '../support/localized_app.dart';
import '../support/system_back.dart';

/// A page with a field; leaving it asks only when something was typed.
class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _text,
    builder: (_, page) =>
        UnsavedChangesScope(unsaved: _text.text.isNotEmpty, child: page!),
    child: Scaffold(
      appBar: AppBar(title: const Text('Form')),
      body: TextField(controller: _text),
    ),
  );
}

Future<void> _open(
  WidgetTester tester, {
  Locale? locale,
  TargetPlatform? platform,
}) async {
  await tester.pumpWidget(
    localizedApp(
      locale: locale,
      theme: platform == null ? null : ThemeData(platform: platform),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const _Form())),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with nothing typed, back simply leaves', (tester) async {
    await _open(tester);

    await systemBack(tester);

    expect(find.text('Form'), findsNothing);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('with something typed, back asks and can keep editing', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'half an answer');
    await tester.pump();

    await systemBack(tester);
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Form'), findsOneWidget);
    expect(find.text('half an answer'), findsOneWidget);
  });

  testWidgets('discarding leaves the page', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'half an answer');
    await tester.pump();

    // The app bar's back arrow goes the same way as the system's.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Form'), findsNothing);
  });

  testWidgets('the question reads in Arabic', (tester) async {
    await _open(tester, locale: const Locale('ar'));
    await tester.enterText(find.byType(TextField), 'نص');
    await tester.pump();

    await systemBack(tester);

    expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
    expect(find.text('متابعة التعديل'), findsOneWidget);
  });

  group('iOS swipe-back', () {
    Future<void> swipeBack(WidgetTester tester) async {
      await tester.dragFrom(const Offset(4, 300), const Offset(600, 0));
      await tester.pumpAndSettle();
    }

    testWidgets('still leaves a page with nothing on it', (tester) async {
      await _open(tester, platform: TargetPlatform.iOS);

      await swipeBack(tester);

      expect(find.text('Form'), findsNothing);
    });

    testWidgets('cannot swipe typed work away', (tester) async {
      await _open(tester, platform: TargetPlatform.iOS);
      await tester.enterText(find.byType(TextField), 'half an answer');
      await tester.pump();

      await swipeBack(tester);

      expect(find.text('Form'), findsOneWidget);
      expect(find.text('half an answer'), findsOneWidget);
    });
  });
}
