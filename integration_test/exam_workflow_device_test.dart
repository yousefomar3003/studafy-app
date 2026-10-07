import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/academic/data/api_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/academic/presentation/assessment_builder_page.dart';
import 'package:studafy/features/academic/presentation/assessment_marking_page.dart';
import 'package:studafy/features/academic/presentation/assessment_page.dart';

import '../test/support/localized_app.dart';

/// The online exam, end to end, on a simulator or phone (ADR-0040): the real
/// screens, the real repositories and HTTP transport, a real API and a real
/// database - never the hosted one. Automated, so it is not a person's
/// hands-on check; it runs the same taps a person would.
///
/// Run against a local API on a throwaway Supabase stack seeded with the
/// synthetic school below:
///
///   flutter drive --driver test_driver/iphone_smoke.dart \
///     --target integration_test/exam_workflow_device_test.dart \
///     --dart-define=E2E_API_URL=http://127.0.0.1:8090 \
///     --dart-define=E2E_SUPABASE_URL=http://127.0.0.1:55721 \
///     --dart-define=E2E_ANON_KEY=... \
///     --dart-define=E2E_PASSWORD=... -d DEVICE_ID
///
/// The accounts are dev.teacher, dev.student and dev.parent at
/// synthetic.studafy.test, all with the one password passed in.
const _apiUrl = String.fromEnvironment('E2E_API_URL');
const _supabaseUrl = String.fromEnvironment('E2E_SUPABASE_URL');
const _anonKey = String.fromEnvironment('E2E_ANON_KEY');
const _password = String.fromEnvironment('E2E_PASSWORD');

const _school = '7e570000-0000-4000-8000-0000000000b1';
const _classId = '7e570000-0000-4000-8000-0000000000d1';
const _student = '7e570000-0000-4000-8000-0000000000e1';

Future<String> _signIn(String who) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password'),
    );
    request.headers
      ..set('apikey', _anonKey)
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'email': 'dev.$who@synthetic.studafy.test',
        'password': _password,
      }),
    );
    final response = await request.close();
    final body = jsonDecode(
      await response.transform(utf8.decoder).join(),
    ) as Map<String, dynamic>;
    return body['access_token'] as String;
  } finally {
    client.close();
  }
}

/// Each signed-in account's transport, so a pull to refresh can clear that
/// account's recent reads - as AppDependencies wires it in the app.
final _transports = <ApiAcademicRepository, V1HttpTransport>{};

ApiAcademicRepository _repository(String token) {
  final transport = V1HttpTransport(
    baseUri: Uri.parse(_apiUrl),
    accessToken: () async => token,
    refreshSession: () async => false,
    onSessionLost: () {},
  );
  final repository = ApiAcademicRepository(
    V1ApiClient(transport),
    context: ActiveContextController.instance,
  );
  _transports[repository] = transport;
  return repository;
}

/// The account on screen: its context, and whose reads a pull refreshes.
void _use(ApiAcademicRepository repository, StudafyRole role) {
  _actAs(role);
  StudafyRefreshIndicator.forgetRecentReads =
      _transports[repository]!.forgetRecentReads;
}

void _actAs(StudafyRole role) {
  final context = ActiveContextController.instance;
  context.selectedStudent = null;
  context.membership = role == StudafyRole.parent
      ? null
      : SchoolMembership(
          id: 'device-${role.name}',
          schoolId: _school,
          schoolName: 'Device Test School',
          role: role,
          active: true,
        );
  if (role == StudafyRole.parent) {
    context.selectedStudent = const StudentSummary(
      id: _student,
      studafyId: 'STU-DEV-0001',
      displayName: 'Dev Student',
      verified: true,
      schoolId: _school,
    );
  }
}

/// Real requests take real time: pump until [finder] shows, or fail.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
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

/// Scrolls the page until [finder] is on screen, as a person would: a long
/// form builds only what is in view.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // The page's own list, not the scroller inside a multi-line field.
    final page = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: page,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  // Close the on-screen keyboard first, as a person would: on a device it
  // covers the lower half of the page.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 400));
  // And let a confirmation at the bottom go first: it sits over the save
  // button there.
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (find.byType(SnackBar).evaluate().isNotEmpty &&
      DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _type(WidgetTester tester, Finder finder, String text) async {
  // One field at a time, as a person types: close the keyboard, bring the
  // field into view, type, and check it took.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 400));
  await _reveal(tester, finder);
  await tester.enterText(finder, text);
  await tester.pump(const Duration(milliseconds: 400));
  final field = tester.widget<TextField>(finder);
  if (field.controller?.text != text) {
    await tester.enterText(finder, text);
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(tester.widget<TextField>(finder).controller?.text, text);
}

/// Pushes [page] from a blank screen, as a list would, so back works.
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
  final binding = _binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an online exam from building to corrected, published results', (
    tester,
  ) async {
    expect(_apiUrl, isNotEmpty, reason: 'E2E_API_URL is not set');
    expect(_password, isNotEmpty, reason: 'E2E_PASSWORD is not set');
    // Typing goes through the test text input, not the system keyboard: the
    // real keyboard reflows the page under the test's taps. Every screen,
    // request and tap is still the device's own.
    tester.testTextInput.register();
    final teacher = _repository(await _signIn('teacher'));
    final studentToken = await _signIn('student');
    final student = _repository(studentToken);
    final parent = _repository(await _signIn('parent'));
    final title = 'Forces quiz ${DateTime.now().millisecondsSinceEpoch}';

    // 1. The teacher builds and publishes the exam.
    _actAs(StudafyRole.teacher);
    await _open(
      tester,
      AssessmentBuilderPage(
        repository: teacher,
        classes: const [ClassOption(id: _classId, name: 'Physics 10A')],
        schoolId: _school,
      ),
    );
    await _waitFor(tester, find.widgetWithText(TextField, 'Title'));
    await _type(tester, find.widgetWithText(TextField, 'Title'), title);
    await _tap(tester, find.byType(DropdownButtonFormField<QuestionKind>));
    await _tap(tester, find.text('True or false').last);
    await _type(
      tester,
      find.widgetWithText(TextField, 'Question').first,
      'A force is a push or a pull.',
    );
    await _tap(tester, find.text('True').first);
    await _tap(tester, find.text('Add question'));
    await _tap(tester, find.byType(DropdownButtonFormField<QuestionKind>).last);
    await _tap(tester, find.text('Essay').last);
    await _type(
      tester,
      find.widgetWithText(TextField, 'Question').last,
      "Explain Newton's first law.",
    );
    await _type(tester, find.widgetWithText(TextField, 'Points').last, '3');
    await tester.pump();
    await binding.takeScreenshot('01-teacher-builds-exam');
    await _tap(tester, find.widgetWithText(FilledButton, 'Publish'));
    await _waitFor(tester, find.text('open'));
    final exam = (await teacher.load(
      AcademicFeed.assessments,
      classroomId: _classId,
    )).firstWhere((record) => record.title == title);
    expect(exam.state, 'published');
    expect(exam.online?.questionCount, 2);

    // 2. The student opens it, answers and submits.
    _actAs(StudafyRole.student);
    await _open(
      tester,
      AssessmentPage(repository: student, assessmentId: exam.id, title: title),
    );
    await _waitFor(tester, find.text('Start'));
    await _tap(tester, find.text('Start'));
    await _waitFor(tester, find.text('A force is a push or a pull.'));
    await _tap(tester, find.text('True'));
    await _type(
      tester,
      find.byType(TextField).last,
      'An object keeps its motion unless a force acts on it.',
    );
    await tester.pump();
    await binding.takeScreenshot('02-student-answers');
    await _tap(tester, find.text('Submit answers').first);
    await _waitFor(tester, find.text('Submit your answers?'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Submit answers'),
      ),
    );
    await _waitFor(tester, find.text('Your attempts'));
    await binding.takeScreenshot('03-student-submitted');
    // A student cannot read the class's submissions.
    await expectLater(student.attempts(exam.id), throwsA(anything));

    // 3. The teacher sees everyone - the one who submitted and the one who
    // did not - reviews the answers and saves a draft.
    _actAs(StudafyRole.teacher);
    Widget marking() => AssessmentMarkingPage(
      repository: teacher,
      assessmentId: exam.id,
      title: title,
      classroomId: _classId,
    );
    await _open(tester, marking());
    await _waitFor(tester, find.text('Submitted · not graded'));
    expect(find.text('Not submitted'), findsWidgets);
    expect(find.text('Dev Absentee'), findsOneWidget);
    await binding.takeScreenshot('04-teacher-submissions');
    await _tap(tester, find.text('Dev Student'));
    await _waitFor(tester, find.text("Explain Newton's first law."));
    expect(find.text("Student's answer"), findsNWidgets(2));
    final essay = find.widgetWithText(TextField, 'Score (out of 3)');
    await _type(tester, essay, '9');
    await _tap(tester, find.widgetWithText(FilledButton, 'Save draft'));
    await _waitFor(tester, find.text('Enter a score from 0 to 3.'));
    await _type(tester, essay, '2');
    await _type(
      tester,
      find.widgetWithText(TextField, 'Feedback for the student'),
      'Good start.',
    );
    await tester.pump();
    // A second tap while the first save runs is ignored, not sent twice.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    await _reveal(tester, find.widgetWithText(FilledButton, 'Save draft'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save draft'));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Save draft'),
      warnIfMissed: false,
    );
    await _waitFor(tester, find.textContaining('Saved as a draft.'));
    await binding.takeScreenshot('05-teacher-draft-saved');
    // The draft is private - read from a second session, as from another
    // phone: the student's own app reuses a read from the last few seconds.
    _actAs(StudafyRole.student);
    expect((await _repository(studentToken).results(exam.id)).grade, isNull);
    _actAs(StudafyRole.teacher);

    // 4. The one who never submitted is marked absent.
    await _open(tester, marking());
    await _waitFor(tester, find.text('Graded · not published'));
    await _tap(tester, find.text('Dev Absentee'));
    await _waitFor(tester, find.text('Mark absent'));
    await _type(
      tester,
      find.widgetWithText(TextField, 'Notes (optional)'),
      'Away on a school trip',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Mark absent'));
    await _waitFor(tester, find.text('Absent'));

    // 5. Publish.
    await _tap(tester, find.widgetWithText(FilledButton, 'Publish grades'));
    await _waitFor(tester, find.text('Publish grades?'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Publish'));
    await _waitFor(tester, find.text('Absent · published'));
    expect(find.text('Published'), findsOneWidget);
    await binding.takeScreenshot('06-teacher-published');

    // 6. The student and their parent see the result and the feedback.
    _use(student, StudafyRole.student);
    await _open(
      tester,
      AssessmentPage(repository: student, assessmentId: exam.id, title: title),
    );
    // Pulled to refresh, as a student checking for the result would.
    await _waitFor(tester, find.text('Grade'));
    await binding.takeScreenshot('07a-student-before-refresh');
    await tester.fling(find.byType(ListView).last, const Offset(0, 500), 1500);
    await tester.pump(const Duration(seconds: 2));
    await binding.takeScreenshot('07b-student-after-refresh');
    await _waitFor(tester, find.text('3 of 4'));
    expect(find.text('Good start.'), findsOneWidget);
    await binding.takeScreenshot('07-student-result');
    _use(parent, StudafyRole.parent);
    await _open(
      tester,
      AssessmentPage(
        repository: parent,
        assessmentId: exam.id,
        title: title,
        studentId: _student,
        childName: 'Dev Student',
      ),
    );
    await _waitFor(tester, find.text('3 of 4'));
    expect(find.text('Start'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    await binding.takeScreenshot('08-parent-result');
    // A parent reads only their own child.
    await expectLater(
      parent.results(
        exam.id,
        studentId: '7e570000-0000-4000-8000-0000000000e2',
      ),
      throwsA(anything),
    );

    // 7. Feedback alone changes without a reason.
    _actAs(StudafyRole.teacher);
    await _open(tester, marking());
    await _waitFor(tester, find.text('Published'));
    await _tap(tester, find.text('Dev Student'));
    await _waitFor(tester, find.text("Explain Newton's first law."));
    await _type(
      tester,
      find.widgetWithText(TextField, 'Feedback for the student'),
      'Good start. Name the law in full next time.',
    );
    await tester.pump();
    await _tap(tester, find.widgetWithText(FilledButton, 'Save changes'));
    await _waitFor(
      tester,
      find.text(
        'Saved. Nothing about the published grade needed a correction.',
      ),
    );
    expect(find.text('Correct a published grade'), findsNothing);

    // 8. A changed mark needs a reason.
    await _type(
      tester,
      find.widgetWithText(TextField, 'Score (out of 3)'),
      '3',
    );
    await tester.pump();
    await _tap(tester, find.widgetWithText(FilledButton, 'Save changes'));
    await _waitFor(tester, find.text('Correct a published grade'));
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Second reading: the law is stated fully.',
    );
    await tester.pump();
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save correction'),
      ),
    );
    await _waitFor(tester, find.textContaining('Correction saved.'));
    await binding.takeScreenshot('09-teacher-correction');
    _actAs(StudafyRole.student);
    // Read as the student, fresh: their app reuses a read for a few seconds.
    final corrected = await _repository(studentToken).results(exam.id);
    expect(corrected.grade?.score, 4);
    expect(
      corrected.grade?.feedback,
      'Good start. Name the law in full next time.',
    );

    // 9. The published absence is corrected, with a reason.
    _actAs(StudafyRole.teacher);
    await _open(tester, marking());
    await _waitFor(tester, find.text('Absent · published'));
    await _tap(tester, find.text('Dev Absentee'));
    await _waitFor(tester, find.text('Not graded (excused)'));
    await _tap(tester, find.text('Not graded (excused)'));
    await _type(
      tester,
      find.widgetWithText(TextField, 'Reason for the change'),
      'Excused by the school office.',
    );
    await tester.pump();
    await _tap(tester, find.widgetWithText(FilledButton, 'Save correction'));
    await _waitFor(tester, find.text('Not graded · published'));
    await binding.takeScreenshot('10-absence-corrected');

    // 10. Reopened from scratch, everything is as it was left.
    await _open(tester, marking());
    await _waitFor(tester, find.text('Not graded · published'));
    expect(find.text('Published'), findsOneWidget);
  });
}
