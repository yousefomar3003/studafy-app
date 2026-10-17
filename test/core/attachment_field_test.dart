import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_lesson_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

import '../support/localized_app.dart';

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

  @override
  Future<DownloadedFile> download(String fileId) async =>
      throw StateError('not used here');
}

/// Uploads that can also say how the scan went, as the real API does.
class _ScanningUploads extends _Uploads implements FileScanStatusSource {
  _ScanningUploads(this.statuses) : super(scanState: 'quarantined');

  /// What each successive status check answers; the last one repeats.
  final List<FileScanStatus> statuses;
  int checks = 0;

  @override
  Future<FileScanStatus> scanStatus(String fileId) async {
    final status =
        statuses[checks < statuses.length ? checks : statuses.length - 1];
    checks += 1;
    return status;
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

  testWidgets('no two attachment boxes ever send the same upload id', (
    tester,
  ) async {
    // The id is the upload's idempotency key, and the server remembers
    // keys: one that repeats across boxes refused every later photo (409).
    final uploads = _Uploads();
    await tester.pumpWidget(field(uploads, picked: _picked()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    // A new box, as in the next chat or a reopened screen.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(field(uploads, picked: _picked()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    final ids = [for (final command in uploads.commands) command.attemptId];
    expect(ids, hasLength(2));
    expect(ids.toSet(), hasLength(2));
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

  testWidgets('a picker that cannot hand the file over says so', (
    tester,
  ) async {
    final uploads = _Uploads();
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: AttachmentField(
            purpose: FilePurpose.assignmentSubmission,
            schoolId: 'school-1',
            uploads: uploads,
            source: (_, _) async =>
                throw PlatformException(code: 'no_valid_image_uri'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    expect(uploads.commands, isEmpty);
    expect(
      find.text("That photo couldn't be opened. Try another one."),
      findsOneWidget,
    );
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

  group('a camera or gallery photo', () {
    final takenAt = DateTime(2026, 10, 17, 14, 32, 5);
    PickedAttachment photo() => PickedAttachment(
      // What the picker calls it - Android's, here.
      displayName: 'scaled_ac4a0881-3601-463b.jpg',
      mediaType: 'image/jpeg',
      bytes: Uint8List(2048),
      photoTakenAt: takenAt,
    );

    test('is named by when it was picked', () {
      expect(photoAttachmentName(takenAt), 'Photo 2026-10-17 14.32.jpg');
      expect(
        photoAttachmentName(DateTime(2026, 1, 2, 3, 4), extension: 'png'),
        'Photo 2026-01-02 03.04.png',
      );
    });

    for (final (locale, expected) in [
      (const Locale('en'), 'Photo 2026-10-17 14.32.jpg'),
      (const Locale('ar'), 'صورة 2026-10-17 14.32.jpg'),
    ]) {
      testWidgets(
        'is sent and shown as "$expected" in ${locale.languageCode}',
        (tester) async {
          final uploads = _Uploads();
          await tester.pumpWidget(
            localizedApp(
              locale: locale,
              home: Scaffold(
                body: AttachmentField(
                  purpose: FilePurpose.assignmentSubmission,
                  schoolId: 'school-1',
                  uploads: uploads,
                  source: (_, _) async => photo(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final state = tester.state<AttachmentFieldState>(
            find.byType(AttachmentField),
          );
          await state.add(AttachmentKind.photo);
          await tester.pumpAndSettle();

          expect(uploads.commands.single.displayName, expected);
          expect(find.text(expected), findsOne);
          expect(find.textContaining('scaled_'), findsNothing);
        },
      );
    }

    test('a file chosen by name keeps it', () {
      final file = _picked(name: 'Unit 2 worksheet.pdf');
      expect(file.localized(lookupAppL10n(const Locale('ar'))), same(file));
    });
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

  testWidgets('the photo, camera or document sheet is as tall as its row', (
    tester,
  ) async {
    final key = GlobalKey<AttachmentFieldState>();
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: AttachmentField(
            key: key,
            purpose: FilePurpose.assignmentSubmission,
            schoolId: 'school-1',
            uploads: _Uploads(),
            source: (_, _) async => null,
            showAddButtons: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(key.currentState!.chooseAndAdd());
    await tester.pumpAndSettle();

    expect(find.text('Camera'), findsOneWidget);
    // Was half the screen, mostly empty, below the three choices.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(screen.height / 3),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  });

  testWidgets('a teacher files a note with its attachment', (tester) async {
    // Tall enough that the whole lesson form is built.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final uploads = _Uploads();
    final academic = _StubAcademic();
    await tester.pumpWidget(
      localizedApp(
        // Lessons are filed from the "+" menu, which opens this form.
        home: CreateLessonPage(
          repository: academic,
          classes: const [ClassOption(id: 'class-1', name: 'Biology')],
          initialClassroomId: 'class-1',
          schoolId: 'school-1',
          uploads: uploads,
          attachmentSource: (_, _) async => _picked(name: 'slides.pdf'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The lesson form does not say attachments are unavailable.
    expect(find.text('Attach file'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Lesson title'),
      'Slides',
    );
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    expect(uploads.commands.single.purpose, FilePurpose.lessonResource);
    expect(uploads.commands.single.classroomId, 'class-1');

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add lesson'));
    await tester.pumpAndSettle();
    // The file is the lesson's own, bound with it in one request.
    expect(academic.created.single.attachmentFileIds, ['file-1']);
    expect(uploads.published, isEmpty);
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

    await tester.ensureVisible(find.text('Hand in'));
    await tester.pumpAndSettle();
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

  testWidgets('a file the scan refuses says why, and offers no retry', (
    tester,
  ) async {
    // 2026-10-15: a teacher's PDF was refused as malformed while the lesson
    // screen still said "Checking", and the lesson then failed to save.
    final uploads = _ScanningUploads(const [
      FileScanStatus(scanState: 'quarantined'),
      FileScanStatus(scanState: 'deleted', failureCode: 'malformed_file'),
    ]);
    var latest = const <Attachment>[];
    await tester.pumpWidget(
      field(uploads, picked: _picked(), onChanged: (v) => latest = v),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    expect(find.text('Checking'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(latest.single.stage, AttachmentStage.failed);
    expect(find.textContaining('looks damaged or unusual'), findsOneWidget);
    expect(find.text('Checking'), findsNothing);
    expect(uploads.commands, hasLength(1));
  });

  testWidgets('a file the scan clears turns ready on its own', (tester) async {
    final uploads = _ScanningUploads(const [
      FileScanStatus(scanState: 'clean'),
    ]);
    var latest = const <Attachment>[];
    await tester.pumpWidget(
      field(uploads, picked: _picked(), onChanged: (v) => latest = v),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(latest.single.stage, AttachmentStage.ready);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('malware gets its own message', (tester) async {
    final uploads = _ScanningUploads(const [
      FileScanStatus(scanState: 'deleted', failureCode: 'malware_detected'),
    ]);
    await tester.pumpWidget(field(uploads, picked: _picked()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.textContaining('may be harmful'), findsOneWidget);
  });
}

class _StubAcademic implements AcademicRepository {
  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async => const [];

  final created = <TextResourceDraft>[];

  @override
  Future<void> createResource(TextResourceDraft draft) async =>
      created.add(draft);

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
