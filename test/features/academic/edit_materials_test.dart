import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

import '../../support/localized_app.dart';

/// A teacher changing the material on work already set. That a file taken
/// off stays with the school, and who may still open it, is proven against
/// SQL in supabase/tests/coursework_files.sql.
class _MaterialsFake implements AcademicRepository {
  final updates = <(String, int, List<String>)>[];

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => [
    const AcademicRecord(
      id: 'work-1',
      title: 'Worksheet 3',
      detail: 'Do page 2',
      state: 'published',
      version: 4,
      classroomId: 'class-1',
      attachments: [
        StoredAttachment(
          id: 'file-1',
          displayName: 'worksheet.pdf',
          sizeBytes: 10,
          scanState: 'clean',
          mediaType: 'application/pdf',
        ),
      ],
    ),
  ];

  @override
  Future<void> updateAssignmentMaterials(
    String assignmentId,
    int expectedVersion, {
    List<String> detachFileIds = const [],
    List<String> attachmentFileIds = const [],
    List<LinkDraft> addLinks = const [],
    List<String> removeLinkIds = const [],
  }) async => updates.add((assignmentId, expectedVersion, detachFileIds));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  // "Reading for the AI helper" is about the AI study tools: shown only on a
  // server that runs them (2026-10-16).
  for (final aiReading in [false, true]) {
    testWidgets('the AI reading sheet is offered only with the AI tools on '
        '($aiReading)', (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          localizedApp(
            locale: locale,
            home: AcademicOverviewPage(
              repository: _LessonFake(),
              classroomId: 'class-1',
              teacherTools: true,
              aiReading: aiReading,
              initialFeed: AcademicFeed.content,
              availableFeeds: const [AcademicFeed.content],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byTooltip(lookupAppL10n(locale).readingTitle),
          aiReading ? findsOneWidget : findsNothing,
          reason: locale.languageCode,
        );
      }
    });
  }

  testWidgets(
    'a teacher takes a file off set work, keeping it for the school',
    (tester) async {
      final fake = _MaterialsFake();
      await tester.pumpWidget(
        localizedApp(
          home: AcademicOverviewPage(
            repository: fake,
            classroomId: 'class-1',
            teacherTools: true,
            availableFeeds: const [AcademicFeed.assignments],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Change the material'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Files you take off are kept for the school but no longer shown to '
          'the class.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'worksheet.pdf'),
          matching: find.text('Remove'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Removed when you save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (id, version, detached) = fake.updates.single;
      expect((id, version), ('work-1', 4));
      expect(detached, ['file-1']);
      expect(find.text('Material updated.'), findsOneWidget);
    },
  );
}

/// A lesson with a file, in a class's Teaching list.
class _LessonFake implements AcademicRepository {
  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => [
    const AcademicRecord(
      id: 'lesson-1',
      title: 'Fractions',
      detail: 'Read the notes',
      state: 'published',
      version: 1,
      classroomId: 'class-1',
      attachments: [
        StoredAttachment(
          id: 'file-1',
          displayName: 'notes.pdf',
          sizeBytes: 10,
          scanState: 'clean',
          mediaType: 'application/pdf',
        ),
      ],
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}
