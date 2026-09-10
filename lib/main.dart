import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_dependencies.dart';
import 'core/studafy_design.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'data/backend.dart';
import 'features/classes/domain/classroom.dart';
import 'features/classes/presentation/classes_page.dart';
import 'features/session/presentation/role_page.dart';
import 'features/session/presentation/splash_page.dart';
import 'studafy_database.dart';
import 'teacher_features.dart';
import 'parent_features.dart';
import 'student_features.dart';

const navy = Color(0xFF241D73),
    cyan = Color(0xFF20C6E8),
    ink = Color(0xFF171441),
    muted = Color(0xFF8D94AF),
    canvas = Color(0xFFF7F6FE);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final RuntimePolicy runtimePolicy;
  try {
    runtimePolicy = RuntimePolicy.fromEnvironment();
  } on FormatException {
    runApp(
      const StudafyConfigurationBlockedApp(
        reason: 'Invalid APP_ENV. This build has been blocked for safety.',
      ),
    );
    return;
  }
  StudafyRuntime.initialize(runtimePolicy);
  if (runtimePolicy.blocksApplicationStartup) {
    runApp(StudafyApp(runtimePolicy: runtimePolicy));
    return;
  }
  if (runtimePolicy.requiresRemoteBackend &&
      !BackendConfig.fromEnvironment.isConfigured) {
    runApp(
      const StudafyConfigurationBlockedApp(
        reason: 'Development and staging require an explicitly configured remote backend.',
      ),
    );
    return;
  }
  if (runtimePolicy.requiresRemoteBackend) {
    await StudafyBackend.initialize();
  }
  await StudafyDatabase.instance.database;
  runApp(StudafyApp(runtimePolicy: runtimePolicy));
}

class StudafyApp extends StatelessWidget {
  const StudafyApp({
    super.key,
    this.runtimePolicy = const RuntimePolicy(StudafyEnvironment.synthetic),
    this.dependencies,
  });

  final RuntimePolicy runtimePolicy;

  /// Composition root output; built lazily when omitted so plain test pumps
  /// of [StudafyApp] work without constructing adapters.
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext c) {
    final deps = dependencies ?? AppDependencies.forPolicy(runtimePolicy);
    final routes = runtimePolicy.blocksApplicationStartup
        ? <String, WidgetBuilder>{}
        : <String, WidgetBuilder>{
            '/roles': (_) => RolePage(session: deps.session),
            '/teacher': (_) => TeacherShell(dependencies: deps),
            '/parent': (_) => const ParentShell(),
            '/student': (_) => const StudentShell(),
          };
    return ListenableBuilder(
      listenable: StudafyLocaleController.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Studafy',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: navy,
            primary: navy,
            secondary: cyan,
            tertiary: const Color(0xFFFF6B6B),
            surface: Colors.white,
          ),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
            titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
            titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
            bodyMedium: TextStyle(color: ink, height: 1.35),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: .1,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              side: const BorderSide(color: Color(0xFFD8DCEC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: cyan.withValues(alpha: .08),
            selectedColor: const Color(0xFF7737EE).withValues(alpha: .15),
            side: BorderSide(color: cyan.withValues(alpha: .16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            labelStyle: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
          ),
        ),
        supportedLocales: StudafyLocalizations.supportedLocales,
        locale: StudafyLocaleController.instance.locale,
        localizationsDelegates: const [
          StudafyLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: routes,
        builder: (context, child) {
          if (!runtimePolicy.isSynthetic) {
            return child ?? const SizedBox.shrink();
          }
          return Column(
            children: [
              Material(
                color: const Color(0xFFFFE0A3),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 30,
                    child: Center(
                      child: Text(
                        'SYNTHETIC DATA — NOT FOR REAL SCHOOL USE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF5E3B00),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          );
        },
        home: runtimePolicy.blocksApplicationStartup
            ? const ProductionReadinessBlockedPage()
            : const SplashPage(),
      ),
    );
  }
}

class StudafyConfigurationBlockedApp extends StatelessWidget {
  const StudafyConfigurationBlockedApp({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ProductionReadinessBlockedPage(reason: reason),
  );
}

class ProductionReadinessBlockedPage extends StatelessWidget {
  const ProductionReadinessBlockedPage({
    super.key,
    this.reason = 'Production access is blocked until security and data-integrity gates pass.',
  });

  final String reason;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 54, color: navy),
                const SizedBox(height: 18),
                const Text(
                  'Studafy is not production-ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Reference: SEC-001',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int index = 0;

  // ARC-011 classes slice: the typed ClassesPage replaces DatabaseClassesPage.
  // The shell (composition layer) owns the legacy-workspace bridge; the
  // classes feature stays free of cross-feature imports.
  Future<void> _openClassroom(ClassroomSummary classroom) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassWorkspacePage(classData: classroom.toLegacyMap()),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final pages = [
      const TeacherHome(),
      ClassesPage(
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        header: const FeatureHeader('Classes'),
      ),
      const ContentPage(),
      const GradebookPage(),
      const CommsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: StudafyNavigationBar(
        selectedIndex: index,
        onSelected: (value) => setState(() => index = value),
        items: [
          StudafyNavItem(
            StudafyLocalizations.of(c).text('today'),
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('classes'),
            Icons.diversity_3_outlined,
            Icons.diversity_3_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('teaching'),
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('gradebook'),
            Icons.fact_check_outlined,
            Icons.fact_check_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(c).text('inbox'),
            Icons.forum_outlined,
            Icons.forum_rounded,
          ),
        ],
        accent: navy,
      ),
    );
  }
}

class TeacherHeader extends StatelessWidget {
  const TeacherHeader({super.key, this.title = 'Al-Noor International'});
  final String title;
  @override
  Widget build(BuildContext c) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StudafyLogo(size: 23),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          Badge(
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ChatsPage()),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          FutureBuilder<int>(
            future: StudafyDatabase.instance.unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              backgroundColor: Colors.red,
              label: Text('${snapshot.data ?? 0}'),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const MyStudafyPage()),
            ),
            borderRadius: BorderRadius.circular(24),
            child: const CircleAvatar(
              backgroundColor: navy,
              child: Text(
                'RH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Column(
    children: [
      const TeacherHeader(),
      Expanded(
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          child: ListView(
            key: const PageStorageKey('teacher-home-scroll'),
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning, Rana',
                          style: Theme.of(c).textTheme.headlineSmall,
                        ),
                        const Text(
                          'Thursday, August 27',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionTitle("Today's sessions"),
              const SizedBox(height: 12),
              SessionCard(
                time: '08:30–09:20',
                title: 'Biology · Grade 10 B',
                room: 'Lab 2',
                status: 'NOW',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '09:30–10:20',
                title: 'Biology · Grade 9 A',
                room: 'Lab 2',
                status: 'NEXT',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '11:00–11:50',
                title: 'Chemistry · Grade 10 A',
                room: 'Lab 1',
                completed: true,
              ),
              const SizedBox(height: 26),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionTitle('Pending grading'),
                  Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFF087D99),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    SmallRow(
                      'Photosynthesis lab report',
                      'Grade 10 B',
                      '6 to grade',
                      navy,
                    ),
                    Divider(),
                    SmallRow(
                      'Cell diagram worksheet',
                      'Grade 9 A',
                      '4 to grade',
                      cyan,
                    ),
                    Divider(),
                    SmallRow(
                      'Titration write-up',
                      'Grade 10 A',
                      '2 to grade',
                      Color(0xFF7737EE),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle('Recent submissions'),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    StudentRow(
                      'LH',
                      'Layla Hassan',
                      'Photosynthesis report · 18 min ago',
                    ),
                    Divider(),
                    StudentRow(
                      'OF',
                      'Omar Fathy',
                      'Photosynthesis report · 1 hour ago',
                    ),
                    Divider(),
                    StudentRow(
                      'MA',
                      'Mariam Adel',
                      'Cell diagram worksheet · Late',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.time,
    required this.title,
    required this.room,
    this.status,
    this.completed = false,
  });
  final String time, title, room;
  final String? status;
  final bool completed;
  @override
  Widget build(BuildContext c) => InfoCard(
    accent: status != null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              time,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            if (status != null) ...[
              const SizedBox(width: 9),
              Chip(
                label: Text(status!),
                visualDensity: VisualDensity.compact,
                backgroundColor: navy,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
              ),
            ],
          ],
        ),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: ink,
          ),
        ),
        Text(room, style: const TextStyle(color: muted)),
        const SizedBox(height: 16),
        if (!completed)
          FilledButton(
            onPressed: () => showAttendance(c, title),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Take attendance'),
          )
        else ...[
          const Wrap(
            spacing: 8,
            children: [
              Pill('Attendance recorded', true),
              Pill('Notebook missing', false),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showNotebook(c, title),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Add lesson notebook'),
          ),
        ],
      ],
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.accent = false});
  final Widget child;
  final bool accent;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border(
        left: BorderSide(color: accent ? navy : Colors.transparent, width: 4),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B171441),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext c) => Text(
    text,
    style: const TextStyle(
      color: ink,
      fontWeight: FontWeight.w800,
      fontSize: 20,
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, this.good, {super.key});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFD8FAE9) : const Color(0xFFFFE4E6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: good ? const Color(0xFF16875B) : const Color(0xFFD33A47),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SmallRow extends StatelessWidget {
  const SmallRow(
    this.title,
    this.subtitle,
    this.trailing,
    this.color, {
    super.key,
  });
  final String title, subtitle, trailing;
  final Color color;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(width: 3, height: 38, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F9FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF087D99),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class StudentRow extends StatelessWidget {
  const StudentRow(this.initials, this.name, this.detail, {super.key});
  final String initials, name, detail;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: navy,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(detail, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        const Pill('New', true),
      ],
    ),
  );
}

class EmptyPage extends StatelessWidget {
  const EmptyPage(this.icon, this.title, this.subtitle, {super.key});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      TeacherHeader(title: title),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: cyan),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(c).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

void showAttendance(BuildContext c, String className) async {
  final classId = await StudafyDatabase.instance.classIdForLabel(className);
  if (classId == null || !c.mounted) return;
  final students = await StudafyDatabase.instance.students(classId);
  if (!c.mounted) return;
  final values = {
    for (final s in students)
      s['id'] as int: <String, String?>{'status': 'present', 'reason': null},
  };
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Take attendance', style: Theme.of(c).textTheme.headlineSmall),
            Text(className, style: const TextStyle(color: muted)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...students.map(
                    (student) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canvas,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${student['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<String>(
                            initialValue: values[student['id']]!['status'],
                            items: const [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text('Present'),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text('Absent'),
                              ),
                              DropdownMenuItem(
                                value: 'tardy',
                                child: Text('Tardy'),
                              ),
                              DropdownMenuItem(
                                value: 'excused',
                                child: Text('Excused absence'),
                              ),
                            ],
                            onChanged: (v) => setSheet(
                              () => values[student['id'] as int]!['status'] = v,
                            ),
                          ),
                          if (values[student['id']]!['status'] ==
                              'excused') ...[
                            const SizedBox(height: 7),
                            TextFormField(
                              onChanged: (v) =>
                                  values[student['id'] as int]!['reason'] = v,
                              decoration: const InputDecoration(
                                labelText: 'Reason for excused absence',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () async {
                await StudafyDatabase.instance.saveAttendanceDetails(
                  classId,
                  DateTime.now(),
                  values,
                );
                if (!c.mounted) return;
                Navigator.pop(c);
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance saved successfully.'),
                  ),
                );
              },
              child: const Text('Save attendance'),
            ),
          ],
        ),
      ),
    ),
  );
}

void showNotebook(BuildContext c, String className) async {
  final classId = await StudafyDatabase.instance.classIdForLabel(className);
  if (classId == null || !c.mounted) return;
  final lesson = TextEditingController(), homework = TextEditingController();
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lesson notebook', style: Theme.of(c).textTheme.headlineSmall),
          Text(className, style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          TextField(
            controller: lesson,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Lesson covered',
              hintText: 'What did you teach today?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: homework,
            decoration: const InputDecoration(labelText: 'Homework (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (lesson.text.trim().isEmpty) return;
              await StudafyDatabase.instance.saveNotebook(
                classId,
                lesson.text.trim(),
                homework.text.trim(),
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save notebook'),
          ),
        ],
      ),
    ),
  );
}
