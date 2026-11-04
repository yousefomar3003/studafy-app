import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/studafy_theme.dart';
import 'package:studafy/app/student_shell.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_design.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/academic/data/api_academic_repository.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/data/api_classroom_repository.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/study/data/preview_study_repository.dart';

import '../support/localized_app.dart';
import '../support/session_repository_fake.dart';

/// No school administrator (this release): every teacher's workspace is a
/// school of its own, so a student in two teachers' classes holds two
/// student memberships. They see every class and all its work together,
/// each class read from its own school - not only the school they joined
/// last (2026-11-04: "when I join a class, the old class gets removed").

const _schoolA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _schoolB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _classA = 'aaaaaaaa-0000-4000-8000-000000000001';
const _classB = 'bbbbbbbb-0000-4000-8000-000000000002';

const _memberA = SchoolMembership(
  id: 'membership-a',
  schoolId: _schoolA,
  schoolName: 'Ms Rana',
  role: StudafyRole.student,
  active: true,
);
const _memberB = SchoolMembership(
  id: 'membership-b',
  schoolId: _schoolB,
  schoolName: 'Mr Omar',
  role: StudafyRole.student,
  active: true,
);

UserProfile _profile(List<SchoolMembership> memberships) => UserProfile(
  id: 'student-1',
  displayName: 'Layla Hassan',
  email: 'layla@example.test',
  memberships: memberships,
  accountKind: AccountKind.student,
);

/// The two teachers' schools, as the server answers a student in both.
class _TwoSchools implements V1JsonTransport {
  final gets = <String>[];

  /// Schools whose reads fail, as an unreachable workspace would.
  final failing = <String>{};

  /// Schools the student is in, as far as the server goes.
  final joined = <String>{_schoolA, _schoolB};

  static String? _query(String path, String name) =>
      Uri.parse(path).queryParameters[name];

  @override
  Future<Map<String, dynamic>> get(String path) async {
    gets.add(path);
    final school = _query(path, 'schoolId');
    if (school != null && failing.contains(school)) {
      throw StateError('school $school unreachable');
    }
    if (school != null && !joined.contains(school)) {
      throw StateError('not a member of $school');
    }
    final a = school == _schoolA;
    final classroom = _query(path, 'classroomId');
    if (path.startsWith('/v1/classrooms?')) {
      return _page([
        {
          'id': a ? _classA : _classB,
          'schoolId': school,
          'termId': '33333333-3333-4333-8333-333333333333',
          'name': a ? 'Biology' : 'History',
          'grade': '10',
          'section': 'A',
          'room': null,
          'status': 'active',
          'version': 1,
          'studentCount': 20,
          'weeklySessions': 2,
          'termName': 'Term 1',
        },
      ]);
    }
    if (path.startsWith('/v1/resources?')) {
      // A class's lessons are only in its own school.
      final mine = classroom == (a ? _classA : _classB);
      return _page([
        if (mine)
          {
            'id': a
                ? '11111111-0000-4000-8000-00000000000a'
                : '11111111-0000-4000-8000-00000000000b',
            'schoolId': school,
            'classroomId': classroom,
            'title': a ? 'Cells and tissues' : 'The Roman Republic',
            'resourceType': 'lesson_note',
            'body': 'Read it.',
            'state': 'published',
            'version': 1,
            'publishedAt': a ? '2026-11-01T08:00:00Z' : '2026-11-02T08:00:00Z',
          },
      ]);
    }
    if (path.startsWith('/v1/assignments?')) {
      return _page([
        {
          'id': a
              ? '22222222-0000-4000-8000-00000000000a'
              : '22222222-0000-4000-8000-00000000000b',
          'classroomId': a ? _classA : _classB,
          'title': a ? 'Label a cell' : 'Essay on Rome',
          'instructions': 'Hand it in.',
          'dueAt': '2026-12-01T10:00:00Z',
          'closesAt': null,
          'state': 'published',
          'version': 1,
          'publishedAt': a ? '2026-11-01T08:00:00Z' : '2026-11-03T08:00:00Z',
        },
      ]);
    }
    return _page(const []);
  }

  static Map<String, dynamic> _page(List<Object?> items) => {
    'items': items,
    'nextCursor': null,
  };

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async => throw UnimplementedError(path);

  /// The reads of [prefix] that named [schoolId].
  List<String> readsOf(String prefix, String schoolId) => [
    for (final path in gets)
      if (path.startsWith(prefix) && _query(path, 'schoolId') == schoolId) path,
  ];
}

void _signIn(List<SchoolMembership> memberships, SchoolMembership active) =>
    ActiveContextController.instance.hydrate(
      authenticatedProfile: _profile(memberships),
      activeMembership: active,
    );

({ApiClassroomRepository classes, ApiAcademicRepository academic}) _repos(
  _TwoSchools server,
) {
  final client = V1ApiClient(server);
  final context = ActiveContextController.instance;
  return (
    classes: ApiClassroomRepository(client, context: context),
    academic: ApiAcademicRepository(client, context: context),
  );
}

Widget _shell(_TwoSchools server) {
  final repos = _repos(server);
  return localizedApp(
    locale: const Locale('en'),
    theme: studafyTheme(),
    home: StudentShell(
      academic: repos.academic,
      classes: ClassListInteractor(
        repository: repos.classes,
        telemetry: const NoopTelemetry(),
      ),
      study: PreviewStudyRepository(),
    ),
  );
}

/// Tall enough that Today's classes and work are all on screen.
Future<void> _pump(WidgetTester tester, _TwoSchools server) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_shell(server));
  await tester.pumpAndSettle();
}

Future<void> _openTab(WidgetTester tester, int tab) async {
  await tester.tap(find.byType(StudafyNavDestination).at(tab));
  await tester.pumpAndSettle();
}

/// The session as far as signing in again after a join goes.
class _Session extends FakeSessionRepositoryBase {
  _Session(this.profile);

  UserProfile profile;

  @override
  Future<UserProfile?> currentProfile() async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(ActiveContextController.instance.signOut);

  group('the repositories', () {
    test('list the classes of every school, each with its school', () async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools();
      final classes = await _repos(server).classes.listClasses();

      expect([for (final c in classes) c.name], ['Biology', 'History']);
      expect([for (final c in classes) c.schoolId], [_schoolA, _schoolB]);
      expect(server.readsOf('/v1/classrooms', _schoolA), hasLength(1));
      expect(server.readsOf('/v1/classrooms', _schoolB), hasLength(1));
    });

    test(
      'read a class from its own school, even before it is listed',
      () async {
        _signIn([_memberA, _memberB], _memberA);
        final server = _TwoSchools();
        final academic = _repos(server).academic;

        // Not listed yet: the repository finds the class's school first.
        final history = await academic.load(
          AcademicFeed.content,
          classroomId: _classB,
        );
        expect(history.single.title, 'The Roman Republic');
        final biology = await academic.load(
          AcademicFeed.content,
          classroomId: _classA,
        );
        expect(biology.single.title, 'Cells and tissues');

        final resources = [
          for (final path in server.gets)
            if (path.startsWith('/v1/resources'))
              Uri.parse(path).queryParameters,
        ];
        expect(resources, [
          containsPair('schoolId', _schoolB),
          containsPair('schoolId', _schoolA),
        ]);
        expect(resources[0], containsPair('classroomId', _classB));
        expect(resources[1], containsPair('classroomId', _classA));
      },
    );

    test('merge a feed from every school, newest first', () async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools();
      final work = await _repos(server).academic.load(AcademicFeed.assignments);

      expect(
        [for (final r in work) r.title],
        ['Essay on Rome', 'Label a cell'],
      );
    });

    test('show what one school answered when the other fails', () async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools()..failing.add(_schoolB);
      final repos = _repos(server);

      final work = await repos.academic.load(AcademicFeed.assignments);
      expect([for (final r in work) r.title], ['Label a cell']);
      final classes = await repos.classes.listClasses();
      expect([for (final c in classes) c.name], ['Biology']);
    });

    test('fail only when every school fails', () async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools()..failing.addAll([_schoolA, _schoolB]);

      await expectLater(
        _repos(server).academic.load(AcademicFeed.assignments),
        throwsStateError,
      );
    });

    test('a student in one school reads only that school', () async {
      _signIn([_memberA], _memberA);
      final server = _TwoSchools();
      final repos = _repos(server);
      await repos.classes.listClasses();
      await repos.academic.load(AcademicFeed.assignments);

      expect(server.readsOf('/v1/', _schoolB), isEmpty);
      expect(server.gets, hasLength(2));
    });

    test('a teacher still reads their own workspace alone', () async {
      const teacher = SchoolMembership(
        id: 'membership-t',
        schoolId: _schoolA,
        schoolName: 'Ms Rana',
        role: StudafyRole.teacher,
        active: true,
      );
      ActiveContextController.instance.hydrate(
        authenticatedProfile: const UserProfile(
          id: 'teacher-1',
          displayName: 'Rana',
          email: 'rana@example.test',
          memberships: [teacher],
        ),
        activeMembership: teacher,
      );
      final server = _TwoSchools();
      final repos = _repos(server);
      await repos.classes.listClasses();
      await repos.academic.load(AcademicFeed.content, classroomId: _classA);

      expect(ActiveContextController.instance.schoolIds, [_schoolA]);
      expect(server.readsOf('/v1/', _schoolB), isEmpty);
    });
  });

  group('the student app', () {
    testWidgets('lists both teachers\' classes and opens each in its school', (
      tester,
    ) async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools();
      await _pump(tester, server);

      // Today: the classes and the work of both teachers.
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Essay on Rome'), findsOneWidget);
      expect(find.text('Label a cell'), findsOneWidget);

      await _openTab(tester, 1);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      for (final (name, school, classroom, lesson) in [
        ('Biology', _schoolA, _classA, 'Cells and tissues'),
        ('History', _schoolB, _classB, 'The Roman Republic'),
      ]) {
        server.gets.clear();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(find.text(lesson), findsWidgets, reason: name);
        final lessons = server.readsOf('/v1/resources', school);
        expect(lessons, isNotEmpty, reason: name);
        expect(
          Uri.parse(lessons.first).queryParameters['classroomId'],
          classroom,
        );
        // Never the other teacher's school for this class.
        expect(
          server.gets.where((p) => p.startsWith('/v1/resources')),
          hasLength(lessons.length),
          reason: name,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      // Work: both teachers' assignments.
      await _openTab(tester, 2);
      expect(find.text('Essay on Rome'), findsWidgets);
      expect(find.text('Label a cell'), findsWidgets);
    });

    testWidgets('one school failing still shows the other\'s', (tester) async {
      _signIn([_memberA, _memberB], _memberA);
      final server = _TwoSchools()..failing.add(_schoolB);
      await _pump(tester, server);

      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Label a cell'), findsOneWidget);
      expect(find.text('History'), findsNothing);

      await _openTab(tester, 2);
      expect(find.text('Label a cell'), findsWidgets);
    });

    testWidgets('joining another teacher\'s class keeps the old one', (
      tester,
    ) async {
      _signIn([_memberA], _memberA);
      final server = _TwoSchools()..joined.remove(_schoolB);
      await _pump(tester, server);
      await _openTab(tester, 1);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('History'), findsNothing);

      // The join, as the app completes it: the server made a membership in
      // the new teacher's school, and the profile is read again. The server
      // lists the new membership first.
      server.joined.add(_schoolB);
      final session = SessionInteractor(
        repository: _Session(_profile([_memberB, _memberA])),
        context: ActiveContextController.instance,
        telemetry: const NoopTelemetry(),
        runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
      );
      final outcome = await session.completeRemoteLogin(
        role: StudafyRole.student,
        consentAccepted: false,
        locale: 'en',
      );
      expect(outcome.require, LoginOutcome.ready);
      await tester.pumpAndSettle();

      // Still in the school they were in, and both classes shown.
      expect(ActiveContextController.instance.membership?.id, 'membership-a');
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });
  });

  test('a new student takes the membership the server lists first', () async {
    ActiveContextController.instance.signOut();
    final session = SessionInteractor(
      repository: _Session(_profile([_memberB, _memberA])),
      context: ActiveContextController.instance,
      telemetry: const NoopTelemetry(),
      runtimePolicy: const RuntimePolicy(StudafyEnvironment.development),
    );
    await session.completeRemoteLogin(
      role: StudafyRole.student,
      consentAccepted: false,
      locale: 'en',
    );
    expect(ActiveContextController.instance.membership?.id, 'membership-b');
    expect(ActiveContextController.instance.schoolIds, [_schoolB, _schoolA]);
  });

  test("a class's uploads go to its own school", () {
    _signIn([_memberA, _memberB], _memberA);
    final context = ActiveContextController.instance;
    context.rememberClassroomSchool(_classB, _schoolB);
    expect(context.schoolFor(_classB), _schoolB);
    // A class not listed yet: the active school, as before.
    expect(context.schoolFor('unknown'), _schoolA);
  });
}
