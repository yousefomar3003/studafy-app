import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/academic_overview_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';
import 'package:studafy/core/attachment_field.dart';

import 'support/localized_app.dart';

/// The attachment control is the one place a person hands the app bytes, so
/// what it refuses matters as much as what it uploads.
class _Uploads implements FileUploadRepository {
  _Uploads({this.scanState = 'clean', this.fail = false, this.hold = false});

  final String scanState;
  final bool fail;

  /// Keeps the upload pending so a test can look at the form mid-flight.
  final bool hold;
  final _gate = Completer<void>();

  void release() => _gate.complete();
  final List<FileUploadCommand> commands = [];
  final List<String> published = [];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    commands.add(command);
    if (hold) await _gate.future;
    if (fail) throw StateError('upload refused');
    return QuarantinedFile(
      id: 'file-${commands.length}',
      uploadId: 'upload-${commands.length}',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: scanState,
    );
  }

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) async {
    published.add(fileId);
    return 'resource-$fileId';
  }
}

PickedAttachment _picked({
  String name = 'homework.pdf',
  String mediaType = 'application/pdf',
  int size = 2048,
}) => PickedAttachment(
  displayName: name,
  mediaType: mediaType,
  bytes: Uint8List(size),
);

void main() {
  Widget field(
    _Uploads uploads, {
    PickedAttachment? picked,
    ValueChanged<List<Attachment>>? onChanged,
    int maximumCount = 5,
  }) => localizedApp(
    home: Scaffold(
      body: AttachmentField(
        purpose: FilePurpose.assignmentSubmission,
        schoolId: 'school-1',
        uploads: uploads,
        maximumCount: maximumCount,
        source: (_, _) async => picked,
        onChanged: onChanged,
      ),
    ),
  );

  testWidgets('uploads a picked file and reports its server id', (
    tester,
  ) async {
    final uploads = _Uploads();
    var latest = const <Attachment>[];
    await tester.pumpWidget(
      field(uploads, picked: _picked(), onChanged: (v) => latest = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands.single.purpose, FilePurpose.assignmentSubmission);
    expect(uploads.commands.single.schoolId, 'school-1');
    expect(latest.single.fileId, 'file-1');
    expect(latest.single.stage, AttachmentStage.ready);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('a quarantined file is attached but not yet ready', (
    tester,
  ) async {
    final uploads = _Uploads(scanState: 'pending');
    var latest = const <Attachment>[];
    await tester.pumpWidget(
      field(uploads, picked: _picked(), onChanged: (v) => latest = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(latest.single.stage, AttachmentStage.quarantined);
    expect(find.text('Checking'), findsOneWidget);
  });

  testWidgets('refuses a disallowed type without contacting the server', (
    tester,
  ) async {
    final uploads = _Uploads();
    await tester.pumpWidget(
      field(
        uploads,
        picked: _picked(name: 'macro.docx', mediaType: 'application/msword'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands, isEmpty);
    expect(find.textContaining('Only PDF and photos'), findsOneWidget);
  });

  testWidgets('refuses a file over the purpose cap', (tester) async {
    final uploads = _Uploads();
    await tester.pumpWidget(
      field(uploads, picked: _picked(size: 10 * 1024 * 1024 + 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands, isEmpty);
    expect(find.textContaining('larger than'), findsOneWidget);
  });

  testWidgets('sanitises the filename before it is sent', (tester) async {
    final uploads = _Uploads();
    await tester.pumpWidget(
      field(uploads, picked: _picked(name: '../../etc/passwd.pdf')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands.single.displayName, 'passwd.pdf');
  });

  testWidgets('a failed upload is shown and carries no file id', (
    tester,
  ) async {
    final uploads = _Uploads(fail: true);
    var latest = const <Attachment>[];
    await tester.pumpWidget(
      field(uploads, picked: _picked(), onChanged: (v) => latest = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(latest.single.stage, AttachmentStage.failed);
    expect(latest.single.fileId, isNull);
    // The server's reason is never surfaced.
    expect(find.textContaining('upload refused'), findsNothing);
  });

  testWidgets('stops offering the control at the cap', (tester) async {
    final uploads = _Uploads();
    await tester.pumpWidget(field(uploads, picked: _picked(), maximumCount: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(find.text('Attach file'), findsNothing);
    expect(find.textContaining('Up to 1'), findsOneWidget);
  });

  testWidgets('a teacher files a note and publishes its attachment', (
    tester,
  ) async {
    final uploads = _Uploads();
    await tester.pumpWidget(
      localizedApp(
        home: AcademicOverviewPage(
          repository: _StubAcademic(),
          classroomId: 'class-1',
          schoolId: 'school-1',
          teacherTools: true,
          initialFeed: AcademicFeed.content,
          availableFeeds: const [AcademicFeed.content],
          uploads: uploads,
          attachmentSource: (_, _) async => _picked(name: 'slides.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.note_add_outlined));
    await tester.pumpAndSettle();
    // The dialog no longer says attachments are unavailable.
    expect(find.text('Attach file'), findsOneWidget);

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    expect(uploads.commands.single.purpose, FilePurpose.lessonResource);
    expect(uploads.commands.single.classroomId, 'class-1');

    await tester.tap(find.text('Save to school'));
    await tester.pumpAndSettle();
    expect(uploads.published, ['file-1']);
  });
  testWidgets('a student hands work in with an attachment', (tester) async {
    final uploads = _Uploads();
    final academic = _SubmitSpy();
    await tester.pumpWidget(
      localizedApp(
        home: SubmitWorkPage(
          repository: academic,
          assignmentId: 'assignment-1',
          assignmentTitle: 'Trigonometry',
          schoolId: 'school-1',
          studentId: 'student-1',
          uploads: uploads,
          attachmentSource: (_, _) async => _picked(name: 'working.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Here is my working.');
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands.single.purpose, FilePurpose.assignmentSubmission);
    // The upload intent needs both, or the server refuses the purpose.
    expect(uploads.commands.single.assignmentId, 'assignment-1');
    expect(uploads.commands.single.studentId, 'student-1');

    await tester.tap(find.text('Hand in'));
    await tester.pumpAndSettle();
    expect(academic.attachments, ['file-1']);
  });

  testWidgets('the send button waits for an upload in flight', (tester) async {
    final uploads = _Uploads(hold: true);
    final academic = _SubmitSpy();
    await tester.pumpWidget(
      localizedApp(
        home: SubmitWorkPage(
          repository: academic,
          assignmentId: 'assignment-1',
          assignmentTitle: 'Trigonometry',
          schoolId: 'school-1',
          studentId: 'student-1',
          uploads: uploads,
          attachmentSource: (_, _) async => _picked(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Working.');
    await tester.tap(find.text('Attach file'));
    await tester.pump();

    // Still uploading: handing in now would file the work without the file.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    uploads.release();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}

class _StubAcademic implements AcademicRepository {
  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => const [];

  @override
  Future<void> createResource(TextResourceDraft draft) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SubmitSpy implements AcademicRepository {
  List<String>? attachments;

  @override
  Future<void> submitAssignment(
    String assignmentId,
    String answer, {
    List<String> attachmentFileIds = const [],
    String? studentId,
  }) async {
    attachments = attachmentFileIds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
