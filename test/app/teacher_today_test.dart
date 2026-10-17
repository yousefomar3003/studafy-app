import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/teacher_today_page.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/academic/domain/academic_repository.dart';
import 'package:studafy/features/classes/application/class_list_interactor.dart';
import 'package:studafy/features/classes/domain/classroom.dart';
import 'package:studafy/features/classes/domain/classroom_repository.dart';
import 'package:studafy/features/notifications/application/notifications_interactor.dart';
import 'package:studafy/features/notifications/domain/notification.dart';
import 'package:studafy/features/notifications/domain/notifications_repository.dart';
import 'package:studafy/features/notifications/presentation/notifications_scope.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// The teacher home in real builds must show the signed-in teacher's own
/// classes, never the demo greeting, lessons or student names.
class _Classes implements ClassroomRepository {
  _Classes({this.studentCount = 24});

  final int studentCount;

  @override
  Future<List<ClassroomSummary>> listClasses() async => [
    ClassroomSummary(
      id: const ClassroomId('class-1'),
      name: 'Physics 11A',
      grade: '11',
      section: 'A',
      studentCount: studentCount,
    ),
  ];
  @override
  Future<void> createClass(NewClassDraft draft) async {}
  @override
  Future<ClassInvite> inviteLinkFor(ClassroomId id) async =>
      const ClassInvite(link: '');
  @override
  Future<ClassJoinLinkInfo?> activeJoinLink(String classroomId) async => null;
  @override
  Future<void> revokeJoinLink(String linkId) async {}
  @override
  Future<JoinedClass> joinWithLink(String token) async =>
      throw UnimplementedError();
  @override
  Future<JoinedClass> joinWithCode(String code) async =>
      throw UnimplementedError();
}

class _Notifications implements NotificationsRepository {
  @override
  Future<List<NotificationPreference>> preferences() async => const [];
  @override
  Future<NotificationPreference> updatePreference(
    NotificationPreference preference,
  ) async => preference;
  @override
  Future<NotificationPage> list({String? cursor, int pageSize = 20}) async =>
      const NotificationPage(items: [], nextCursor: null, isFromCache: false);
  @override
  Future<int> unreadCount() async => 3;
  @override
  Future<void> markRead({required List<String> ids, required bool all}) async {}
  @override
  Future<void> syncPending() async {}
}

void main() {
  tearDown(() => ActiveContextController.instance.profile = null);

  Future<void> pumpToday(
    WidgetTester tester, {
    _Classes? classes,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => NotificationsScope(
          interactor: NotificationsInteractor(
            repository: _Notifications(),
            telemetry: const NoopTelemetry(),
          ),
          child: child!,
        ),
        home: TeacherTodayPage(
          classes: ClassListInteractor(
            repository: classes ?? _Classes(),
            telemetry: const NoopTelemetry(),
          ),
          academic: _TodayAcademic(),
          onOpenClassroom: (_) async {},
          onOpenMessages: () {},
          onOpenNotifications: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the real teacher and classes, never the demo content', (
    tester,
  ) async {
    ActiveContextController.instance.profile = const UserProfile(
      id: 'teacher-1',
      displayName: 'Khaled Mansour',
      email: 'k@example.test',
      memberships: [],
    );
    await pumpToday(tester);
    expect(find.text('Hello, Khaled'), findsOneWidget);
    expect(find.text('Physics 11A'), findsOneWidget);
    // Once in the class card, once in the day's totals.
    expect(find.text('24 students'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    for (final sample in [
      'Rana',
      'Layla Hassan',
      'Photosynthesis lab report',
    ]) {
      expect(find.textContaining(sample), findsNothing);
    }
  });

  for (final (locale, count, words) in [
    (const Locale('en'), 1, '1 student'),
    (const Locale('ar'), 1, 'طالب واحد'),
    (const Locale('ar'), 2, 'طالبان'),
    (const Locale('ar'), 5, '5 طلاب'),
    (const Locale('ar'), 24, '24 طالبًا'),
  ]) {
    testWidgets('a class of $count says so in ${locale.languageCode}', (
      tester,
    ) async {
      await pumpToday(
        tester,
        classes: _Classes(studentCount: count),
        locale: locale,
      );
      // Once in the class card, once in the day's totals.
      expect(find.text(words), findsNWidgets(2));
    });
  }

  group('sections needing content', () {
    final now = DateTime.now();

    testWidgets('a taught section without a published lesson is listed; a '
        'draft is not content', (tester) async {
      _tall(tester);
      final academic = _TodayAcademic()
        ..sessions = [
          _session('none', now.subtract(const Duration(days: 1))),
          _session(
            'draft',
            now.subtract(const Duration(days: 2)),
            content: SectionContent.draft,
          ),
          _session(
            'done',
            now.subtract(const Duration(days: 3)),
            content: SectionContent.published,
          ),
          // Not taught yet.
          _session('later', now.add(const Duration(days: 1))),
        ];
      await tester.pumpWidget(
        _today(
          academic,
          onAddLesson: (_, _) async {},
          onOpenLessons: (_) async {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No lesson yet'), findsOneWidget);
      expect(
        find.text('Lesson in draft · not visible to students'),
        findsOneWidget,
      );
      expect(find.text('Add lesson'), findsOneWidget);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Physics 11A'), findsNWidgets(3));
    });

    testWidgets('adding the lesson opens the form for that class and section, '
        'and the section clears once it is published', (tester) async {
      _tall(tester);
      final academic = _TodayAcademic()
        ..sessions = [_session('s1', now.subtract(const Duration(days: 1)))];
      (ClassroomSummary, LessonSession)? opened;
      await tester.pumpWidget(
        _today(
          academic,
          onAddLesson: (classroom, section) async {
            opened = (classroom, section);
            // The teacher writes and publishes the lesson.
            academic.sessions = [
              _session(
                's1',
                now.subtract(const Duration(days: 1)),
                content: SectionContent.published,
              ),
            ];
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add lesson'));
      await tester.pumpAndSettle();
      expect(opened!.$1.id.value, 'class-1');
      expect(opened!.$2.id, 's1');
      expect(find.text('No lesson yet'), findsNothing);
      expect(
        find.text(
          'Every section you have taught has a lesson your class can see.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a draft lesson opens the class lessons to publish it', (
      tester,
    ) async {
      _tall(tester);
      final academic = _TodayAcademic()
        ..sessions = [
          _session(
            's1',
            now.subtract(const Duration(days: 1)),
            content: SectionContent.draft,
          ),
        ];
      ClassroomSummary? lessons;
      await tester.pumpWidget(
        _today(
          academic,
          onOpenLessons: (classroom) async => lessons = classroom,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(lessons!.id.value, 'class-1');
    });
  });

  group('work you have to set', () {
    final now = DateTime.now();

    testWidgets('drafts first, then set work by date; finished work and '
        'assignment marks are left out', (tester) async {
      _tall(tester);
      final academic = _TodayAcademic()
        ..assignments = [
          _assignment(
            'a-open',
            'Lab report',
            state: 'published',
            due: now.add(const Duration(days: 3)),
          ),
          _assignment(
            'a-draft',
            'Essay plan',
            state: 'draft',
            due: now.add(const Duration(days: 5)),
          ),
          _assignment(
            'a-past',
            'Old homework',
            state: 'published',
            due: now.subtract(const Duration(days: 2)),
          ),
        ]
        ..assessments = [
          _onlineExam(
            'e-soon',
            'Forces quiz',
            state: 'published',
            opens: now.add(const Duration(days: 1)),
            closes: now.add(const Duration(days: 2)),
          ),
          _paperExam('p-next', 'Midterm', on: now.add(const Duration(days: 4))),
          _paperExam(
            'p-past',
            'Last term',
            on: now.subtract(const Duration(days: 30)),
          ),
          _paperExam('mark', 'Lab report', markFor: 'a-open'),
        ];
      await tester.pumpWidget(_today(academic));
      await tester.pumpAndSettle();

      final titles = [
        for (final title in [
          'Essay plan',
          'Forces quiz',
          'Lab report',
          'Midterm',
        ])
          tester.getTopLeft(find.text(title)).dy,
      ];
      expect(titles, [...titles]..sort());
      expect(find.text('Draft · not set yet'), findsOneWidget);
      expect(find.textContaining('Opens '), findsOneWidget);
      expect(find.textContaining('Due '), findsOneWidget);
      expect(find.textContaining('Exam on '), findsOneWidget);
      expect(find.text('Physics 11A · Assignment'), findsNWidgets(2));
      expect(find.text('Physics 11A · Online exam'), findsOneWidget);
      expect(find.text('Physics 11A · Paper exam'), findsOneWidget);
      for (final gone in ['Old homework', 'Last term']) {
        expect(find.text(gone), findsNothing);
      }
      // The assignment's mark is not a second piece of work.
      expect(find.text('Lab report'), findsOneWidget);
    });

    testWidgets('finishing a draft updates it in place', (tester) async {
      _tall(tester);
      final due = now.add(const Duration(days: 2));
      final academic = _TodayAcademic()
        ..assignments = [
          _assignment('a1', 'Essay plan', state: 'draft', due: due),
        ];
      TeacherWorkItem? opened;
      await tester.pumpWidget(
        _today(
          academic,
          onOpenWork: (item) async {
            opened = item;
            academic.assignments = [
              _assignment('a1', 'Essay plan', state: 'published', due: due),
            ];
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Essay plan'));
      await tester.pumpAndSettle();
      expect(opened!.record.id, 'a1');
      expect(opened!.status, TeacherWorkStatus.draft);
      expect(find.text('Draft · not set yet'), findsNothing);
      expect(find.textContaining('Due '), findsOneWidget);
    });

    testWidgets('nothing to set says so; a failed read says it may be '
        'incomplete', (tester) async {
      _tall(tester);
      final academic = _TodayAcademic();
      await tester.pumpWidget(_today(academic));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nothing to set right now. Drafts, and work that is open or '
          'coming up, appear here.',
        ),
        findsOneWidget,
      );

      academic.fail = true;
      await tester.pumpWidget(_today(academic, visible: false));
      await tester.pumpWidget(_today(academic));
      await tester.pumpAndSettle();
      expect(find.text('Some classes could not be loaded.'), findsOneWidget);
      expect(
        find.text(
          'Some classes could not be loaded, so work may be missing here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('coming back to the tab reads again', (tester) async {
      _tall(tester);
      final academic = _TodayAcademic();
      await tester.pumpWidget(_today(academic));
      await tester.pumpAndSettle();
      final before = academic.reads;
      academic.assignments = [
        _assignment(
          'a1',
          'New worksheet',
          state: 'draft',
          due: now.add(const Duration(days: 1)),
        ),
      ];
      await tester.pumpWidget(_today(academic, visible: false));
      await tester.pumpWidget(_today(academic));
      await tester.pumpAndSettle();
      expect(academic.reads, greaterThan(before));
      expect(find.text('New worksheet'), findsOneWidget);
    });
  });

  test('a class with no such work adds nothing to the list', () {
    const classroom = ClassroomSummary(
      id: ClassroomId('c'),
      name: 'Art',
      grade: '9',
      section: 'B',
      studentCount: 3,
    );
    expect(
      teacherWorkFor(
        classroom,
        assignments: const [],
        assessments: const [],
        now: DateTime(2026, 10, 7),
      ),
      isEmpty,
    );
  });
}

/// Today aggregates from the academic surface. By default it returns
/// nothing, so the first test still asserts the class list is the teacher's
/// own; the others hand it the class's records and change them between
/// reads, as creating or publishing something would.
class _TodayAcademic implements AcademicRepository {
  List<AcademicRecord> assignments = const [];
  List<AcademicRecord> assessments = const [];
  List<LessonSession> sessions = const [];
  bool fail = false;
  int reads = 0;

  @override
  Future<List<AcademicRecord>> load(
    AcademicFeed feed, {
    String? classroomId,
    String? studentId,
  }) async {
    if (fail) throw StateError('offline');
    return switch (feed) {
      AcademicFeed.assignments => assignments,
      AcademicFeed.assessments => assessments,
      _ => const [],
    };
  }

  @override
  Future<List<LessonSession>> lessonSessions(String classroomId) async {
    reads++;
    if (fail) throw StateError('offline');
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _today(
  _TodayAcademic academic, {
  bool visible = true,
  Future<void> Function(TeacherWorkItem item)? onOpenWork,
  Future<void> Function(ClassroomSummary, LessonSession)? onAddLesson,
  Future<void> Function(ClassroomSummary)? onOpenLessons,
}) => MaterialApp(
  supportedLocales: AppL10n.supportedLocales,
  localizationsDelegates: const [
    AppL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => NotificationsScope(
    interactor: NotificationsInteractor(
      repository: _Notifications(),
      telemetry: const NoopTelemetry(),
    ),
    child: child!,
  ),
  home: TeacherTodayPage(
    classes: ClassListInteractor(
      repository: _Classes(),
      telemetry: const NoopTelemetry(),
    ),
    academic: academic,
    visible: visible,
    onOpenClassroom: (_) async {},
    onOpenNotifications: () {},
    onOpenWork: onOpenWork,
    onAddLesson: onAddLesson,
    onOpenLessons: onOpenLessons,
  ),
);

LessonSession _session(
  String id,
  DateTime startsAt, {
  SectionContent content = SectionContent.none,
}) => LessonSession(
  id: id,
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(minutes: 45)),
  filed: false,
  content: content,
);

AcademicRecord _assignment(
  String id,
  String title, {
  required String state,
  required DateTime due,
}) => AcademicRecord(
  id: id,
  title: title,
  detail: '',
  state: state,
  version: 1,
  classroomId: 'class-1',
  dueAt: due,
);

AcademicRecord _onlineExam(
  String id,
  String title, {
  required String state,
  DateTime? opens,
  DateTime? closes,
}) => AcademicRecord(
  id: id,
  title: title,
  detail: '',
  state: state,
  version: 1,
  classroomId: 'class-1',
  delivery: 'online',
  online: OnlineAssessment(
    id: id,
    classroomId: 'class-1',
    title: title,
    category: 'quiz',
    maximumScore: 10,
    state: state,
    version: 1,
    delivery: 'online',
    settings: AssessmentSettings(opensAt: opens, closesAt: closes),
  ),
);

AcademicRecord _paperExam(
  String id,
  String title, {
  DateTime? on,
  String? markFor,
}) => AcademicRecord(
  id: id,
  title: title,
  detail: '',
  state: 'draft',
  version: 1,
  classroomId: 'class-1',
  delivery: 'paper',
  scheduledAt: on,
  markedAssignmentId: markFor,
);
