import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/data/contracts/v1_http_transport.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/data/api_classroom_repository.dart';
import 'package:studafy/features/classes/presentation/join_class_page.dart';
import 'package:studafy/features/school_portal/application/school_links_interactor.dart';
import 'package:studafy/features/school_portal/data/api_school_links_repository.dart';
import 'package:studafy/features/school_portal/presentation/school_announcements_page.dart';
import 'package:studafy/features/school_portal/presentation/school_link_banner.dart';
import 'package:studafy/features/school_portal/presentation/schools_page.dart';

import '../test/support/localized_app.dart';

/// The School Portal from the phone's side, end to end, on a simulator or
/// phone (docs/planning/school-portal.md, sections 6 and 13a.7): the real
/// screens, repositories and HTTP transport, a real API with
/// SCHOOL_PORTAL_ENABLED and a real database - never the hosted one. The
/// school's side is the portal's own API, called as the website calls it.
///
///   1. A school asks dev.teacher to link by their Studafy ID; the teacher
///      reads the request and accepts it. The school sees both classes.
///   2. The school groups both classes; the teacher approves each.
///   3. dev.student2 (in Science) types the group's code in "Join a class"
///      and joins Physics 10A; typing it again joins nothing more.
///   4. The school writes to parents: dev.parent reads it, dev.student not.
///   5. The teacher unlinks: the school sees nothing, and the code joins
///      nobody into anything.
///   6. The school asks again; the teacher declines, and the school cannot
///      ask again for 30 days.
///
/// Run on a freshly seeded throwaway stack (scripts/seed-device-tests.ts),
/// against a local API started with SCHOOL_PORTAL_ENABLED=true and a
/// CLASS_JOIN_CODE_KEY:
///
///   flutter drive --driver test_driver/iphone_smoke.dart \
///     --target integration_test/school_portal_device_test.dart \
///     --dart-define-from-file=build/device-tests/defines.json -d DEVICE_ID
const _apiUrl = String.fromEnvironment('E2E_API_URL');
const _supabaseUrl = String.fromEnvironment('E2E_SUPABASE_URL');
const _anonKey = String.fromEnvironment('E2E_ANON_KEY');
const _password = String.fromEnvironment('E2E_PASSWORD');

const _physics = '7e570000-0000-4000-8000-0000000000d1';
const _science = '7e570000-0000-4000-8000-0000000000d2';

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

V1ApiClient _client(String token) => V1ApiClient(
  V1HttpTransport(
    baseUri: Uri.parse(_apiUrl),
    accessToken: () async => token,
    refreshSession: () async => false,
    onSessionLost: () {},
  ),
);

SchoolLinksInteractor _links(String token) => SchoolLinksInteractor(
  links: ApiSchoolLinksRepository(_client(token)),
  telemetry: const NoopTelemetry(),
);

/// One request as the website makes it; commands carry an idempotency key.
Future<(int, Map<String, dynamic>)> _call(
  String token,
  String method,
  String path, [
  Map<String, Object?>? body,
]) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse('$_apiUrl$path'));
    request.headers.set('Authorization', 'Bearer $token');
    if (body != null) {
      request.headers
        ..contentType = ContentType.json
        ..set('Idempotency-Key', _key());
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return (
      response.statusCode,
      text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>,
    );
  } finally {
    client.close();
  }
}

var _keys = 0;
String _key() =>
    'portal-device-${DateTime.now().microsecondsSinceEpoch}-${_keys++}';

/// The account on screen, as sign-in hydrates it.
void _actAs(String id, String name, StudafyRole role, {bool adult = true}) {
  ActiveContextController.instance.hydrate(
    authenticatedProfile: UserProfile(
      id: id,
      displayName: name,
      email: '$name@synthetic.studafy.test',
      memberships: const [],
      accountKind: adult ? AccountKind.adult : AccountKind.student,
      schoolPortal: true,
    ),
    signedInAs: role,
  );
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
      await _binding.takeScreenshot('portal-zz-timed-out');
      throw TestFailure('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  // A confirmation at the bottom goes first, as on a phone.
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (find.byType(SnackBar).evaluate().isNotEmpty &&
      DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Pushes [page] from a blank screen, as the app would, so back works.
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

  testWidgets('a school links, groups classes, writes, and is let go', (
    tester,
  ) async {
    expect(_apiUrl, isNotEmpty, reason: 'E2E_API_URL is not set');
    expect(_password, isNotEmpty, reason: 'E2E_PASSWORD is not set');
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    tester.testTextInput.register();

    final principal = await _signIn('principal');
    final teacher = await _signIn('teacher');
    final student2 = await _signIn('student2');
    final student = await _signIn('student');
    final parent = await _signIn('parent');

    // The school's page, made on the website.
    final (made, org) = await _call(
      principal,
      'POST',
      '/v1/school-portal/orgs',
      {
        'name': 'Cedar Grove School',
        'country': 'Jordan',
        'city': 'Amman',
        'kind': 'private',
        'jobTitle': 'Principal',
        'adult': true,
        'agreementVersion': '2026-11-06',
      },
    );
    expect(made, 201, reason: '$org');
    final orgPath = '/v1/school-portal/orgs/${org['id']}';

    // 1. Asked by the Studafy ID the teacher's Account shows (TC-…).
    final (_, profile) = await _call(teacher, 'GET', '/v1/account/profile');
    final studafyId = 'TC-${profile['publicId']}';
    var (status, asked) = await _call(
      principal,
      'POST',
      '$orgPath/link-requests',
      {'studafyId': studafyId},
    );
    expect(status, 201, reason: '$asked');
    expect(
      (asked['teacher'] as Map)['email'],
      isNull,
      reason: 'the school has no email before the teacher accepts',
    );
    var (_, classes) = await _call(principal, 'GET', '$orgPath/classes');
    expect(classes['classes'], isEmpty, reason: 'nothing before accepting');

    _actAs(
      '7e570000-0000-4000-8000-0000000000a1',
      'Dev Teacher',
      StudafyRole.teacher,
    );
    final teacherLinks = _links(teacher);
    await _open(tester, SchoolsPage(links: teacherLinks));
    await _waitFor(tester, find.text('Waiting for your answer'));
    expect(find.textContaining('Cedar Grove School'), findsWidgets);
    await binding.takeScreenshot('portal-01-teacher-sees-request');
    await _tap(tester, find.text('Review'));
    await _waitFor(tester, find.text('What the school will see'));
    expect(find.text('Dev Principal'), findsOneWidget);
    await binding.takeScreenshot('portal-02-request-what-is-shared');
    await tester.scrollUntilVisible(find.text('Accept'), 250);
    await _tap(tester, find.text('Accept'));
    await _waitFor(tester, find.widgetWithText(FilledButton, 'Accept'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Accept').last);
    await _waitFor(
      tester,
      find.text('Linked. The school can now see your classes.'),
    );
    await binding.takeScreenshot('portal-03-linked');

    (_, classes) = await _call(principal, 'GET', '$orgPath/classes');
    final names = [
      for (final c in classes['classes'] as List) (c as Map)['name'],
    ]..sort();
    expect(names, ['Physics 10A', 'Science']);
    final (_, roster) = await _call(
      principal,
      'GET',
      '$orgPath/classes/$_physics/roster',
    );
    expect([
      for (final s in roster['students'] as List) (s as Map)['name'],
    ], contains('Dev Student'));
    final (_, linkedTeachers) = await _call(
      principal,
      'GET',
      '$orgPath/teachers',
    );
    expect(
      ((linkedTeachers['teachers'] as List).first as Map)['email'],
      'dev.teacher@synthetic.studafy.test',
      reason: 'once linked, the school has the email',
    );

    // The Today and Classes banner names the school.
    await _open(
      tester,
      Scaffold(
        body: SafeArea(child: SchoolLinkBanner(links: teacherLinks)),
      ),
    );
    await teacherLinks.load();
    await _waitFor(tester, find.textContaining('Your classes are visible to'));
    await binding.takeScreenshot('portal-04-banner');

    // 2. A group with both classes; the teacher approves each.
    final (groupMade, group) = await _call(
      principal,
      'POST',
      '$orgPath/groups',
      {'name': 'Grade 10'},
    );
    expect(groupMade, 201, reason: '$group');
    final groupPath = '$orgPath/groups/${group['id']}';
    for (final id in [_physics, _science]) {
      final (added, body) = await _call(
        principal,
        'POST',
        '$groupPath/classes',
        {'classroomId': id},
      );
      expect(added, 201, reason: '$body');
    }
    final code = group['code'] as String;

    await _open(tester, SchoolsPage(links: _links(teacher)));
    await _waitFor(tester, find.text('Class groups'));
    expect(find.text('Approve'), findsNWidgets(2));
    await binding.takeScreenshot('portal-05-group-requests');
    await _tap(tester, find.text('Approve').first);
    await _waitFor(
      tester,
      find.text('Approve'),
      timeout: const Duration(seconds: 25),
    );
    await _tap(tester, find.text('Approve').first);
    await _waitFor(tester, find.text('Take out of the group'));
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (find.text('Take out of the group').evaluate().length < 2 &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Take out of the group'), findsNWidgets(2));
    await binding.takeScreenshot('portal-06-groups-approved');

    // 3. One code, typed by a student in Science only.
    _actAs(
      '7e570000-0000-4000-8000-0000000000a4',
      'Device Student',
      StudafyRole.student,
      adult: false,
    );
    final joinPage = JoinClassPage(
      classes: ClassListInteractor(
        repository: ApiClassroomRepository(
          _client(student2),
          context: ActiveContextController.instance,
        ),
        telemetry: const NoopTelemetry(),
      ),
    );
    await _open(tester, joinPage);
    await _waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), code);
    await tester.pump(const Duration(milliseconds: 300));
    await _tap(tester, find.text('Join class'));
    await _waitFor(tester, find.textContaining('You joined 1 class in'));
    expect(find.text('Physics 10A'), findsWidgets);
    await binding.takeScreenshot('portal-07-student-joined-by-group-code');
    final (_, physicsNow) = await _call(
      principal,
      'GET',
      '$orgPath/classes/$_physics/roster',
    );
    expect(
      [for (final s in physicsNow['students'] as List) (s as Map)['name']],
      contains('Device Student'),
      reason: 'the school sees the new student on the class list',
    );
    // Again: already in both, so nothing more.
    await _open(tester, joinPage);
    await _waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), code);
    await _tap(tester, find.text('Join class'));
    await tester.pump(const Duration(seconds: 2));
    await _waitFor(tester, find.textContaining("You're already in this class"));
    expect(find.textContaining('You joined'), findsNothing);
    await binding.takeScreenshot('portal-08-code-again-joins-nothing');

    // 4. To parents: the parent reads it, the student does not.
    final (sent, sentBody) = await _call(
      principal,
      'POST',
      '$orgPath/announcements',
      {
        'title': 'Parents evening',
        'body': 'Thursday at 5 in the hall.',
        'audience': 'parents',
      },
    );
    expect(sent, 201, reason: '$sentBody');
    _actAs(
      '7e570000-0000-4000-8000-0000000000a3',
      'Dev Parent',
      StudafyRole.parent,
    );
    await _open(tester, SchoolAnnouncementsPage(links: _links(parent)));
    await _waitFor(tester, find.text('Parents evening'));
    expect(find.text('Cedar Grove School'), findsOneWidget);
    await binding.takeScreenshot('portal-09-parent-reads-announcement');
    _actAs(
      '7e570000-0000-4000-8000-0000000000a2',
      'Dev Student',
      StudafyRole.student,
      adult: false,
    );
    await _open(tester, SchoolAnnouncementsPage(links: _links(student)));
    await _waitFor(tester, find.text('No announcements from a school yet.'));

    // 5. The teacher unlinks on the Schools page.
    _actAs(
      '7e570000-0000-4000-8000-0000000000a1',
      'Dev Teacher',
      StudafyRole.teacher,
    );
    await _open(tester, SchoolsPage(links: _links(teacher)));
    await _waitFor(tester, find.text('Linked now'));
    await _tap(tester, find.text('Unlink'));
    await _waitFor(tester, find.widgetWithText(FilledButton, 'Unlink'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Unlink'));
    await _waitFor(
      tester,
      find.text('Unlinked. The school can no longer see your classes.'),
    );
    await binding.takeScreenshot('portal-10-unlinked');
    (_, classes) = await _call(principal, 'GET', '$orgPath/classes');
    expect(classes['classes'], isEmpty, reason: 'the school sees nothing');
    final (rosterAfter, _) = await _call(
      principal,
      'GET',
      '$orgPath/classes/$_physics/roster',
    );
    expect(rosterAfter, 404);
    // Dev Student is in Physics only; the code would have added Science.
    _actAs(
      '7e570000-0000-4000-8000-0000000000a2',
      'Dev Student',
      StudafyRole.student,
      adult: false,
    );
    await _open(
      tester,
      JoinClassPage(
        classes: ClassListInteractor(
          repository: ApiClassroomRepository(
            _client(student),
            context: ActiveContextController.instance,
          ),
          telemetry: const NoopTelemetry(),
        ),
      ),
    );
    await _waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), code);
    await _tap(tester, find.text('Join class'));
    await tester.pump(const Duration(seconds: 2));
    await _waitFor(tester, find.textContaining('No class has this code'));
    expect(find.textContaining('You joined'), findsNothing);
    await binding.takeScreenshot('portal-11-code-after-unlink-joins-nothing');

    // 6. Asked again, declined, and not again for 30 days.
    (status, asked) = await _call(principal, 'POST', '$orgPath/link-requests', {
      'studafyId': studafyId,
    });
    expect(status, 201, reason: '$asked');
    _actAs(
      '7e570000-0000-4000-8000-0000000000a1',
      'Dev Teacher',
      StudafyRole.teacher,
    );
    await _open(tester, SchoolsPage(links: _links(teacher)));
    await _waitFor(tester, find.text('Review'));
    await _tap(tester, find.text('Review'));
    await _waitFor(tester, find.text('What the school will see'));
    await tester.scrollUntilVisible(find.text('Decline'), 250);
    await _tap(tester, find.text('Decline'));
    await _waitFor(tester, find.widgetWithText(FilledButton, 'Decline'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Decline'));
    await _waitFor(tester, find.text('Request declined.'));
    await binding.takeScreenshot('portal-12-declined');
    final (again, refused) = await _call(
      principal,
      'POST',
      '$orgPath/link-requests',
      {'studafyId': studafyId},
    );
    expect(again, 409);
    expect(refused['code'], 'SCHOOL_LINK_RECENTLY_DECLINED');
    final (_, afterDecline) = await _call(
      principal,
      'GET',
      '$orgPath/teachers',
    );
    expect(
      [for (final t in afterDecline['teachers'] as List) (t as Map)['email']],
      everyElement(isNull),
      reason: 'the school keeps no email of a teacher who is not linked',
    );
  });
}
