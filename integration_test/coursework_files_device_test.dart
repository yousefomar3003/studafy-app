import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/attachment_policy.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/academic/data/api_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/create_lesson_page.dart';
import 'package:studafy/features/academic/presentation/submissions_page.dart';
import 'package:studafy/features/academic/presentation/submit_work_page.dart';
import 'package:studafy/features/files/data/api_file_upload_repository.dart';
import 'package:studafy/features/files/data/signed_upload_transport.dart';

import '../test/support/localized_app.dart';

/// Files on lessons and hand-ins, end to end, on a simulator or phone: the
/// real screens, repositories, HTTP transport and signed storage upload, a
/// real API, worker and Storage - never the hosted ones. Only the system
/// file picker is replaced, by files passed in below.
///
/// Seed a local stack with a teacher, a student who joined their class and
/// a published assignment, then:
///
///   flutter drive --driver test_driver/iphone_smoke.dart \
///     --target integration_test/coursework_files_device_test.dart \
///     --dart-define-from-file=SEED_DEFINES_JSON -d DEVICE_ID
const _apiUrl = String.fromEnvironment('E2E_API_URL');
const _supabaseUrl = String.fromEnvironment('E2E_SUPABASE_URL');
const _anonKey = String.fromEnvironment('E2E_ANON_KEY');
const _password = String.fromEnvironment('E2E_PASSWORD');
const _teacherEmail = String.fromEnvironment('E2E_TEACHER_EMAIL');
const _studentEmail = String.fromEnvironment('E2E_STUDENT_EMAIL');
const _school = String.fromEnvironment('E2E_SCHOOL_ID');
const _classId = String.fromEnvironment('E2E_CLASSROOM_ID');
const _assignmentId = String.fromEnvironment('E2E_ASSIGNMENT_ID');
const _pdf = String.fromEnvironment('E2E_PDF_BASE64');
const _docx = String.fromEnvironment('E2E_DOCX_BASE64');
const _png = String.fromEnvironment('E2E_PNG_BASE64');

Future<String> _signIn(String email) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password'),
    );
    request.headers
      ..set('apikey', _anonKey)
      ..contentType = ContentType.json;
    request.write(jsonEncode({'email': email, 'password': _password}));
    final response = await request.close();
    final body = jsonDecode(
      await response.transform(utf8.decoder).join(),
    ) as Map<String, dynamic>;
    return body['access_token'] as String;
  } finally {
    client.close();
  }
}

/// One signed-in account: its academic repository and its file pipeline,
/// wired as AppDependencies wires them.
({ApiAcademicRepository academic, ApiFileUploadRepository files}) _account(
  String token,
) {
  final transport = V1HttpTransport(
    baseUri: Uri.parse(_apiUrl),
    accessToken: () async => token,
    refreshSession: () async => false,
    onSessionLost: () {},
  );
  final api = V1ApiClient(transport);
  return (
    academic: ApiAcademicRepository(
      api,
      context: ActiveContextController.instance,
    ),
    files: ApiFileUploadRepository(
      api,
      IoSignedUploadTransport(),
      fetch: transport.getBytes,
    ),
  );
}

void _actAs(StudafyRole role) {
  final context = ActiveContextController.instance;
  context.selectedStudent = null;
  context.membership = SchoolMembership(
    id: 'device-${role.name}',
    schoolId: _school,
    schoolName: 'Device School',
    role: role,
    active: true,
  );
}

/// Stands in for the system picker: hands over the next queued file.
AttachmentSource _picker(List<PickedAttachment> queue) =>
    (kind, policy) async => queue.isEmpty ? null : queue.removeAt(0);

PickedAttachment _file(String name, String mediaType, String base64) =>
    PickedAttachment(
      displayName: name,
      mediaType: mediaType,
      bytes: Uint8List.fromList(base64Decode(base64)),
    );

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      await _binding.takeScreenshot('zz-timed-out');
      throw TestFailure('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Waits until no attachment row is still uploading, then fails on any row
/// that did not make it.
Future<void> _uploadsSettle(WidgetTester tester, String step) async {
  final end = DateTime.now().add(const Duration(seconds: 30));
  while (find.text('Uploading').evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) break;
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pump(const Duration(milliseconds: 300));
  if (find.text('Failed').evaluate().isNotEmpty ||
      find.text('That file could not be uploaded.').evaluate().isNotEmpty) {
    await _binding.takeScreenshot('$step-upload-failed');
    throw TestFailure('$step: an attachment failed to upload');
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _type(WidgetTester tester, Finder finder, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Pushes [page] from a blank screen so it can pop back to 'open'.
Future<void> _open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    localizedApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => page)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump(const Duration(milliseconds: 500));
}

late final IntegrationTestWidgetsFlutterBinding _binding;

void main() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('files on a lesson and a hand-in reach the teacher', (
    tester,
  ) async {
    expect(_apiUrl, isNotEmpty, reason: 'E2E_API_URL is not set');
    // Android screenshots need the surface turned into an image first.
    if (Platform.isAndroid) await _binding.convertFlutterSurfaceToImage();
    tester.testTextInput.register();
    final teacher = _account(await _signIn(_teacherEmail));
    final student = _account(await _signIn(_studentEmail));

    // 1. The teacher adds a lesson with a PDF and a Word file.
    _actAs(StudafyRole.teacher);
    await _open(
      tester,
      CreateLessonPage(
        repository: teacher.academic,
        classes: const [ClassOption(id: _classId, name: 'Science')],
        initialClassroomId: _classId,
        schoolId: _school,
        uploads: teacher.files,
        attachmentSource: _picker([
          _file('notes.pdf', 'application/pdf', _pdf),
          _file('slides.docx', AttachmentPolicy.docx, _docx),
        ]),
      ),
    );
    await _waitFor(tester, find.widgetWithText(TextField, 'Lesson title'));
    await _type(
      tester,
      find.widgetWithText(TextField, 'Lesson title'),
      'Plants',
    );
    await _type(
      tester,
      find.widgetWithText(TextField, 'Lesson notes'),
      'Read the attached notes.',
    );
    await _tap(tester, find.text('Attach file').first);
    await _uploadsSettle(tester, '1-lesson-pdf');
    await _tap(tester, find.text('Attach file').first);
    await _uploadsSettle(tester, '1-lesson-docx');
    await _binding.takeScreenshot('1-lesson-ready');
    await _tap(tester, find.text('Add lesson'));
    await _waitFor(tester, find.text('open'));
    expect(
      find.text('The lesson could not be added. Please try again.'),
      findsNothing,
    );

    // 2. The student hands in with a PDF and a photo.
    _actAs(StudafyRole.student);
    await _open(
      tester,
      SubmitWorkPage(
        repository: student.academic,
        assignmentId: _assignmentId,
        assignmentTitle: 'Device worksheet',
        uploads: student.files,
        schoolId: _school,
        attachmentSource: _picker([
          _file('answers.pdf', 'application/pdf', _pdf),
          _file('photo.png', 'image/png', _png),
        ]),
      ),
    );
    await _waitFor(tester, find.byType(TextField).first);
    await _type(
      tester,
      find.byType(TextField).first,
      'My answers are attached.',
    );
    await _tap(tester, find.text('Attach file').first);
    await _uploadsSettle(tester, '2-handin-pdf');
    await _tap(tester, find.text('Photo').first);
    await _uploadsSettle(tester, '2-handin-photo');
    await _binding.takeScreenshot('2-handin-ready');
    await _tap(tester, find.text('Hand in'));
    await _waitFor(tester, find.text('open'));
    expect(
      find.text('Could not hand in your work. Please try again.'),
      findsNothing,
    );

    // 3. The teacher sees the student handed in.
    _actAs(StudafyRole.teacher);
    await _open(
      tester,
      SubmissionsPage(
        repository: teacher.academic,
        assignmentId: _assignmentId,
        assignmentTitle: 'Device worksheet',
        classroomId: _classId,
      ),
    );
    await _waitFor(tester, find.text('Device Student'));
    await _binding.takeScreenshot('3-submissions');
    await _tap(tester, find.text('Device Student'));
    await _waitFor(tester, find.textContaining('answers.pdf'));
    await _binding.takeScreenshot('3-handin-files');
  });
}
