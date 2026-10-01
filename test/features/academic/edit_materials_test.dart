import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';

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
  }) async => updates.add((assignmentId, expectedVersion, detachFileIds));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
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
      await tester.tap(find.widgetWithText(CheckboxListTile, 'worksheet.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Will be taken off'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final (id, version, detached) = fake.updates.single;
      expect((id, version), ('work-1', 4));
      expect(detached, ['file-1']);
      expect(find.text('Material updated.'), findsOneWidget);
    },
  );
}
