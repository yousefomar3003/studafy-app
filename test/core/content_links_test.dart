import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/content_links.dart';

import '../support/localized_app.dart';

/// Links a teacher adds to what they post: only real https addresses, and a
/// reader is always shown where one goes before it opens.
void main() {
  test('only https links with a real host are accepted', () {
    expect(safeLink('https://example.com/worksheet'), isNotNull);
    expect(safeLink('  https://khanacademy.org  '), isNotNull);
    expect(safeLink('http://example.com'), isNull);
    expect(safeLink('javascript:alert(1)'), isNull);
    expect(safeLink('https://localhost'), isNull);
    expect(safeLink('https://user:pass@example.com'), isNull);
    expect(safeLink('example.com'), isNull);
  });

  test('links go on their own lines beneath the text', () {
    final links = [
      Uri.parse('https://a.example'),
      Uri.parse('https://b.example'),
    ];
    expect(
      textWithLinks('Read chapter 2. ', links),
      'Read chapter 2.\n\nhttps://a.example\nhttps://b.example',
    );
    expect(textWithLinks('', links), 'https://a.example\nhttps://b.example');
    expect(textWithLinks(' Notes ', const []), 'Notes');
  });

  testWidgets('a teacher adds a link, and a bad one is refused', (
    tester,
  ) async {
    List<Uri> added = const [];
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(body: LinksField(onChanged: (l) => added = l)),
      ),
    );
    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'http://insecure.example');
    await tester.tap(find.widgetWithText(FilledButton, 'Add link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('starting with https://'), findsOne);

    await tester.enterText(find.byType(TextField), 'https://example.com/a');
    await tester.tap(find.widgetWithText(FilledButton, 'Add link'));
    await tester.pumpAndSettle();
    expect(added, [Uri.parse('https://example.com/a')]);
    expect(find.text('example.com'), findsOne);
  });

  testWidgets('a reader sees where a link goes before it opens', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: LinkedText(
            'Watch this:\nhttps://video.example/lesson-2',
            openLink: (url) async {
              opened.add(url);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.tapOnText(find.textRange.ofSubstring('https://video.example'));
    await tester.pumpAndSettle();
    expect(find.text('Open this link?'), findsOne);
    expect(find.text('video.example'), findsOne);
    expect(opened, isEmpty);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://video.example/lesson-2')]);
  });
}
