import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/studafy_design.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'studafy_database.dart';
import 'data/session_service.dart';
import 'student_linking.dart';
import 'features/account/presentation/delete_account_page.dart';
import 'features/study_coach/domain/study_coach_repository.dart';
import 'features/study_coach/presentation/study_coach_scope.dart';

const _navy = Color(0xFF241D73);
const _cyan = Color(0xFF20C6E8);
const _ink = Color(0xFF171441);
const _muted = Color(0xFF9299B4);
const _canvas = Color(0xFFF7F6FE);

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;
  final pages = const [
    StudentHomePage(),
    StudentNotebookPage(),
    StudentClassworkPage(),
    StudentProgressPage(),
    StudentAiPage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: StudafyNavigationBar(
      selectedIndex: index,
      onSelected: (value) => setState(() => index = value),
      items: [
        StudafyNavItem(
          StudafyLocalizations.of(context).text('today'),
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('notebook'),
          Icons.library_books_outlined,
          Icons.library_books_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('work'),
          Icons.assignment_outlined,
          Icons.assignment_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('grades'),
          Icons.bar_chart_outlined,
          Icons.bar_chart_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(context).text('coach'),
          Icons.auto_awesome_outlined,
          Icons.auto_awesome_rounded,
        ),
      ],
      accent: _navy,
    ),
  );
}

class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({super.key});

  @override
  State<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage> {
  static const studentId = 1;
  int tab = 0;
  late Future<List<Object>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Object>> _load() => Future.wait<Object>([
    StudafyDatabase.instance.todaySessionsForStudent(studentId),
    StudafyDatabase.instance.gradesForStudent(studentId),
    StudafyDatabase.instance.workForStudent(studentId),
    StudafyDatabase.instance.attendanceForStudent(studentId),
  ]);

  Future<void> _refresh() async {
    setState(() {
      data = _load();
    });
    await data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _StudentHeader(title: 'Grades'),
        _GradesAttendanceTabs(
          selected: tab,
          onSelected: (value) => setState(() => tab = value),
        ),
        Expanded(
          child: FutureBuilder<List<Object>>(
            future: data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = snapshot.data![0] as List<Map<String, Object?>>;
              final assessments =
                  snapshot.data![1] as List<Map<String, Object?>>;
              final assignments =
                  snapshot.data![2] as List<Map<String, Object?>>;
              final attendance =
                  snapshot.data![3] as List<Map<String, Object?>>;
              if (tab == 1) {
                return _StudentClassAttendance(
                  classes: classes,
                  attendance: attendance,
                  onRefresh: _refresh,
                );
              }
              final groups = classes.map((classroom) {
                final name = '${classroom['name']}';
                final results = <_ProgressResult>[
                  ...assessments
                      .where((e) => e['class_name'] == name)
                      .map(
                        (e) => _ProgressResult(
                          title: '${e['title']}',
                          category: _progressCategory('${e['type']}'),
                          score: (e['score'] as num).toDouble(),
                          maximum: (e['max_score'] as num).toDouble(),
                        ),
                      ),
                  ...assignments
                      .where(
                        (e) => e['class_name'] == name && e['score'] != null,
                      )
                      .map(
                        (e) => _ProgressResult(
                          title: '${e['title']}',
                          category: _progressCategory('${e['kind']}'),
                          score: (e['score'] as num).toDouble(),
                          maximum: 100,
                        ),
                      ),
                ];
                return _ClassProgress(classroom: classroom, results: results);
              }).toList();
              final all = groups.expand((e) => e.results).toList();
              final overall = _average(all);
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _OverallProgress(score: overall, resultCount: all.length),
                    const SizedBox(height: 18),
                    const Text(
                      'Your classes',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Open a class to see every result recorded by its teacher.',
                      style: TextStyle(color: _muted, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    if (groups.isEmpty)
                      const _ClassworkEmpty(
                        icon: Icons.bar_chart_rounded,
                        title: 'No classes yet',
                        message: 'Your class grades will appear here once you enrol.',
                      )
                    else
                      for (final group in groups) ...[
                        _ClassProgressCard(group: group),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _GradesAttendanceTabs extends StatelessWidget {
  const _GradesAttendanceTabs({
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  i == 0 ? 'Grades' : 'Attendance',
                  style: TextStyle(
                    color: selected == i ? _navy : _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _StudentClassAttendance extends StatelessWidget {
  const _StudentClassAttendance({
    required this.classes,
    required this.attendance,
    required this.onRefresh,
  });
  final List<Map<String, Object?>> classes;
  final List<Map<String, Object?>> attendance;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const Text(
          'Attendance by class',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'See your presence, absences, late arrivals and excused days for every enrolled class.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        for (final classroom in classes) ...[
          Builder(
            builder: (context) {
              final rows = attendance
                  .where((row) => row['class_id'] == classroom['id'])
                  .toList();
              final present = rows
                  .where(
                    (r) =>
                        r['status'] == 'present' ||
                        (r['status'] == null && r['present'] == 1),
                  )
                  .length;
              final late = rows.where((r) => r['status'] == 'tardy').length;
              final excused = rows
                  .where((r) => r['status'] == 'excused')
                  .length;
              final absent = rows.length - present - late - excused;
              final rate = rows.isEmpty
                  ? null
                  : ((present + late) / rows.length * 100);
              final color = Color(
                (classroom['color'] as num?)?.toInt() ?? _navy.toARGB32(),
              );
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    child: Icon(Icons.how_to_reg_rounded, color: color),
                  ),
                  title: Text(
                    '${classroom['name']}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    rows.isEmpty
                        ? 'No attendance recorded yet'
                        : '${rate!.round()}% attendance · ${rows.length} sessions',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Row(
                      children: [
                        _AttendanceMetric(
                          'Present',
                          present,
                          const Color(0xFF15966A),
                        ),
                        _AttendanceMetric(
                          'Absent',
                          absent,
                          const Color(0xFFFF5D5D),
                        ),
                        _AttendanceMetric(
                          'Late',
                          late,
                          const Color(0xFFE39A12),
                        ),
                        _AttendanceMetric('Excused', excused, _cyan),
                      ],
                    ),
                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final row in rows.take(5))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['day']}'),
                          subtitle: row['reason'] == null
                              ? null
                              : Text('${row['reason']}'),
                          trailing: Text(
                            '${row['status'] ?? (row['present'] == 1 ? 'present' : 'absent')}',
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );
}

class _ProgressResult {
  const _ProgressResult({
    required this.title,
    required this.category,
    required this.score,
    required this.maximum,
  });
  final String title;
  final String category;
  final double score;
  final double maximum;
  double get percent =>
      maximum <= 0 ? 0 : (score / maximum * 100).clamp(0, 100);
}

class _ClassProgress {
  const _ClassProgress({required this.classroom, required this.results});
  final Map<String, Object?> classroom;
  final List<_ProgressResult> results;
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({required this.score, required this.resultCount});
  final double? score;
  final int resultCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _navy,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: (score ?? 0) / 100,
                strokeWidth: 7,
                backgroundColor: Colors.white24,
                color: _cyan,
              ),
              Text(
                score == null ? '—' : '${score!.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall grade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                resultCount == 0
                    ? 'Waiting for your first graded work'
                    : 'Based on $resultCount graded ${resultCount == 1 ? 'item' : 'items'} across your classes',
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClassProgressCard extends StatelessWidget {
  const _ClassProgressCard({required this.group});
  final _ClassProgress group;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      (group.classroom['color'] as num?)?.toInt() ?? _navy.toARGB32(),
    );
    final average = _average(group.results);
    final categories = <String, List<_ProgressResult>>{};
    for (final result in group.results) {
      categories.putIfAbsent(result.category, () => []).add(result);
    }
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE9EAF4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 5,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(
          '${group.classroom['name']}',
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'Grade ${group.classroom['grade']} · Section ${group.classroom['section']} · ${group.results.length} results',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        trailing: Text(
          average == null ? '—' : '${average.round()}%',
          style: const TextStyle(
            color: _navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          if (group.results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No grades have been published for this class yet.',
                style: TextStyle(color: _muted),
              ),
            )
          else
            for (final entry in categories.entries) ...[
              _ProgressCategory(
                title: entry.key,
                results: entry.value,
                color: color,
              ),
              if (entry.key != categories.keys.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ProgressCategory extends StatelessWidget {
  const _ProgressCategory({
    required this.title,
    required this.results,
    required this.color,
  });
  final String title;
  final List<_ProgressResult> results;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _canvas,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_average(results)!.round()}% average',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        for (var i = 0; i < results.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  results[i].title,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_score(results[i].score)} / ${_score(results[i].maximum)}',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: results[i].percent / 100,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E6F1),
              color: color,
            ),
          ),
          if (i != results.length - 1) const SizedBox(height: 13),
        ],
      ],
    ),
  );
}

double? _average(Iterable<_ProgressResult> results) {
  if (results.isEmpty) return null;
  return results.map((e) => e.percent).reduce((a, b) => a + b) / results.length;
}

String _progressCategory(String raw) {
  final value = raw.toLowerCase();
  if (value.contains('homework')) return 'Homework';
  if (value.contains('quiz')) return 'Quizzes';
  if (value.contains('exam') ||
      value.contains('midterm') ||
      value.contains('final')) {
    return 'Exams';
  }
  return 'Assignments';
}

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});
  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  static const studentId = 1;
  late Future<List<Object>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Object>> _load() => Future.wait<Object>([
    StudafyDatabase.instance.students(),
    StudafyDatabase.instance.todaySessionsForStudent(studentId),
    StudafyDatabase.instance.workForStudent(studentId),
    StudafyDatabase.instance.gradesForStudent(studentId),
    StudafyDatabase.instance.noticesForStudent(studentId),
  ]);

  Future<void> _refresh() async {
    setState(() {
      data = _load();
    });
    await data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _StudentHeader(),
        Expanded(
          child: FutureBuilder<List<Object>>(
            future: data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final students = snapshot.data![0] as List<Map<String, Object?>>;
              final student = students.firstWhere(
                (row) => row['id'] == studentId,
                orElse: () => {'name': 'Layla Hassan'},
              );
              final classes = snapshot.data![1] as List<Map<String, Object?>>;
              final work = snapshot.data![2] as List<Map<String, Object?>>;
              final grades = snapshot.data![3] as List<Map<String, Object?>>;
              final notices = snapshot.data![4] as List<Map<String, Object?>>;
              final firstName = '${student['name']}'.split(' ').first;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Text(
                      'Good morning, $firstName',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: _navy, fontSize: 26),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat(
                        'EEEE, d MMMM',
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(DateTime.now()),
                      style: const TextStyle(color: _muted),
                    ),
                    if (notices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AnnouncementSpotlight(notices: notices),
                    ],
                    const SizedBox(height: 14),
                    _TodayClasses(classes: classes),
                    const SizedBox(height: 14),
                    _DueSoon(work: work),
                    const SizedBox(height: 14),
                    _NewGrades(grades: grades),
                    const SizedBox(height: 14),
                    const _DayPlan(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({this.title});
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⁺studafy',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'Al-Noor International',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  )
                : Text(
                    title!,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          FutureBuilder<int>(
            future: StudafyDatabase.instance.unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              label: Text('${snapshot.data ?? 0}'),
              backgroundColor: const Color(0xFFFF5D5D),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const StudentNotificationsPage(),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const StudentProfilePage(),
              ),
            ),
            icon: const CircleAvatar(
              backgroundColor: _navy,
              child: Text(
                'LH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});
  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Profile')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: _navy,
              child: Text(
                'LH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Layla Hassan',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'layla.hassan@alnoor.edu',
                    style: TextStyle(color: _muted),
                  ),
                  SizedBox(height: 5),
                  Chip(
                    label: Text('Student'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const StudentIdentityCard(
          name: 'Layla Hassan',
          email: 'layla.hassan@alnoor.edu',
          studafyId: 'STU-0001',
        ),
        const SizedBox(height: 24),
        const _StudentSectionLabel('SCHOOL'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _row('School', 'Al-Noor International'),
              const Divider(height: 1),
              _row('Grade', 'Grade 10'),
              const Divider(height: 1),
              _row('Section', 'Section B'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _StudentSectionLabel('PERSONAL'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _row('Full name', 'Layla Hassan'),
              const Divider(height: 1),
              _row('Date of birth', '04 May 2010'),
              const Divider(height: 1),
              _row('Guardian', 'Nadia Hassan'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const StudentSettingsPage(),
            ),
          ),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Account and settings'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class StudentSettingsPage extends StatefulWidget {
  const StudentSettingsPage({super.key});
  @override
  State<StudentSettingsPage> createState() => _StudentSettingsPageState();
}

class _StudentSettingsPageState extends State<StudentSettingsPage> {
  bool push = true, grades = true, quiet = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Account and settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Push notifications'),
                value: push,
                onChanged: (v) => setState(() => push = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Grade alerts'),
                value: grades,
                onChanged: (v) => setState(() => grades = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Quiet hours (21:00–07:00)'),
                value: quiet,
                onChanged: (v) => setState(() => quiet = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                onTap: () => showStudafyLanguagePicker(context),
                title: const Text('Language'),
                trailing: Text(
                  StudafyLocaleController.instance.locale.languageCode == 'ar'
                      ? 'العربية'
                      : 'English',
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              const ListTile(
                title: Text('Privacy, data and policies'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () async {
            await SessionService.signOut();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/roles',
                (_) => false,
              );
            }
          },
          child: const Text(
            'Sign out',
            style: TextStyle(color: Color(0xFFFF5D5D)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  const DeleteAccountPage(email: 'layla.hassan@alnoor.edu'),
            ),
          ),
          child: const Text(
            'Delete account',
            style: TextStyle(
              color: Color(0xFFA5A3B5),
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StudentSectionLabel extends StatelessWidget {
  const _StudentSectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .7,
      ),
    ),
  );
}

class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});
  @override
  State<StudentNotificationsPage> createState() =>
      _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> {
  late Future<List<Object>> data;
  final read = <String>{};
  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Object>> _load() => Future.wait<Object>([
    StudafyDatabase.instance.gradesForStudent(1),
    StudafyDatabase.instance.noticesForStudent(1),
    StudafyDatabase.instance.workForStudent(1),
    StudafyDatabase.instance.assessmentsForStudent(1),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: () async {
            await StudafyDatabase.instance.markNotificationsRead();
            if (mounted) {
              setState(() => read.addAll(['grade', 'notice', 'due', 'exam']));
            }
          },
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: FutureBuilder<List<Object>>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final gradeRows = snapshot.data![0] as List<Map<String, Object?>>;
        final notices = snapshot.data![1] as List<Map<String, Object?>>;
        final work = snapshot.data![2] as List<Map<String, Object?>>;
        final exams = snapshot.data![3] as List<Map<String, Object?>>;
        final cards =
            <
              ({
                String id,
                IconData icon,
                Color color,
                String title,
                String detail,
              })
            >[];
        if (gradeRows.isNotEmpty) {
          final g = gradeRows.first;
          cards.add((
            id: 'grade',
            icon: Icons.star_rounded,
            color: const Color(0xFF16A36D),
            title: 'New grade: ${g['class_name']}',
            detail:
                '${g['title']} — ${_score(g['score'])}/${_score(g['max_score'])} was published.',
          ));
        }
        if (notices.isNotEmpty) {
          final n = notices.first;
          cards.add((
            id: 'notice',
            icon: Icons.priority_high_rounded,
            color: const Color(0xFFFF5D5D),
            title: '${n['class_name']} announcement',
            detail: '${n['message']}',
          ));
        }
        final due = work.where((e) => e['submitted_at'] == null).toList();
        if (due.isNotEmpty) {
          cards.add((
            id: 'due',
            icon: Icons.timer_outlined,
            color: const Color(0xFFE0A01B),
            title: 'Assignment due',
            detail:
                '${due.first['title']} is due ${_shortDate('${due.first['due_at']}')}.',
          ));
        }
        if (exams.isNotEmpty) {
          cards.add((
            id: 'exam',
            icon: Icons.event_note_rounded,
            color: _navy,
            title: 'Exam scheduled',
            detail: '${exams.first['title']} · ${exams.first['class_name']}',
          ));
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              data = _load();
            });
            await data;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (cards.isEmpty)
                const _ClassworkEmpty(
                  icon: Icons.notifications_none_rounded,
                  title: 'You’re all caught up',
                  message: 'Grades, announcements, deadlines, and exam updates will appear here.',
                ),
              for (final card in cards)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(card.icon, color: card.color, size: 21),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    card.title,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!read.contains(card.id))
                                  const CircleAvatar(
                                    radius: 4,
                                    backgroundColor: _cyan,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              card.detail,
                              style: const TextStyle(
                                color: _muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 7),
                            const Text(
                              'Recently',
                              style: TextStyle(
                                color: Color(0xFFB7BCD0),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _TodayClasses extends StatelessWidget {
  const _TodayClasses({required this.classes});
  final List<Map<String, Object?>> classes;

  int _minutes(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _state(Map<String, Object?> item, int index) {
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final start = _minutes('${item['session_start_time']}');
    final end = _minutes('${item['session_end_time']}');
    if (current >= start && current < end) return 'NOW';
    if (current < start) {
      final firstFuture = classes.indexWhere(
        (row) => _minutes('${row['session_start_time']}') > current,
      );
      return firstFuture == index ? 'NEXT' : 'LATER';
    }
    return 'COMPLETED';
  }

  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Today's Classes",
                style: TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${classes.length} classes',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
          ],
        ),
        const SizedBox(height: 12),
        if (classes.isEmpty)
          const Text(
            'No teacher-created classes are scheduled.',
            style: TextStyle(color: _muted),
          )
        else
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = classes[index],
                    color = Color(item['color'] as int);
                return Container(
                  width: 178,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: .22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _state(item, index),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${item['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item['session_start_time']}–${item['session_end_time']} · ${item['room']}',
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _DueSoon extends StatelessWidget {
  const _DueSoon({required this.work});
  final List<Map<String, Object?>> work;
  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Due Soon',
          style: TextStyle(
            color: _navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        if (work.isEmpty)
          const Text('You are all caught up.', style: TextStyle(color: _muted))
        else
          for (final item in work.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 39,
                    decoration: BoxDecoration(
                      color: Color(
                        (item['class_name'].hashCode & 0x00FFFFFF) | 0xFF000000,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item['class_name']} · Due ${_shortDate('${item['due_at']}')}',
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: item['submitted_at'] == null
                        ? 'Not started'
                        : 'Submitted',
                    positive: item['submitted_at'] != null,
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _NewGrades extends StatelessWidget {
  const _NewGrades({required this.grades});
  final List<Map<String, Object?>> grades;
  @override
  Widget build(BuildContext context) => _StudentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'New Grades',
                style: TextStyle(
                  color: _navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const StudentProgressPage(),
                ),
              ),
              child: const Text('View grades'),
            ),
          ],
        ),
        if (grades.isEmpty)
          const Text(
            'No newly published grades.',
            style: TextStyle(color: _muted),
          )
        else
          for (final item in grades.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['class_name']}',
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const _StatusPill(label: 'New', positive: true),
                  const SizedBox(width: 9),
                  Text(
                    '${_score(item['score'])}/${item['max_score']}',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _AnnouncementSpotlight extends StatelessWidget {
  const _AnnouncementSpotlight({required this.notices});
  final List<Map<String, Object?>> notices;

  void _open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .65,
      maxChildSize: .9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'School announcements',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 11),
              itemBuilder: (context, index) {
                final item = notices[index];
                final important = item['mandatory'] == 1;
                return Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: important ? const Color(0xFFFFF6F2) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: important
                          ? const Color(0xFFFFCBBE)
                          : const Color(0xFFE8EAF3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['class_name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (important)
                            const _StatusPill(
                              label: 'Important',
                              warning: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item['message']}',
                        style: const TextStyle(color: _ink, height: 1.4),
                      ),
                      if (item['meeting_url'] != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Google Meet · ${item['meeting_at']}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed: () {
                            final uri = Uri.tryParse('${item['meeting_url']}');
                            if (uri != null) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.video_call_rounded),
                          label: const Text('Open in Google Meet'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        _shortDate('${item['created_at']}'),
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final highlighted = notices.firstWhere(
      (item) => item['mandatory'] == 1,
      orElse: () => notices.first,
    );
    final important = highlighted['mandatory'] == 1;
    return Material(
      color: important ? const Color(0xFFFFF3EE) : const Color(0xFFEAFBFD),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Badge(
                label: Text('${notices.length}'),
                backgroundColor: important ? const Color(0xFFFF5D5D) : _cyan,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    important
                        ? Icons.campaign_rounded
                        : Icons.notifications_active_rounded,
                    color: important ? const Color(0xFFE04B3F) : _navy,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'School announcements',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (important)
                          const _StatusPill(label: 'Important', warning: true),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${highlighted['message']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to view all ${notices.length}',
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right_rounded, color: _navy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPlan extends StatelessWidget {
  const _DayPlan();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBFD), Color(0xFFF0EDFF)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_rounded, color: Color(0xFF7737EE)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plan your study time',
                style: TextStyle(color: _navy, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'You have 2 unfinished tasks. A focused 35-minute session can clear the nearest deadline.',
                style: TextStyle(
                  color: Color(0xFF646B84),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: _muted),
      ],
    ),
  );
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B241D73),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.positive = false,
    this.warning = false,
  });
  final String label;
  final bool positive, warning;
  @override
  Widget build(BuildContext context) {
    final background = warning
        ? const Color(0xFFFFE1E1)
        : positive
        ? const Color(0xFFD6F8E8)
        : const Color(0xFFF0F1F7);
    final foreground = warning
        ? const Color(0xFFC62828)
        : positive
        ? const Color(0xFF15885D)
        : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StudentNotebookPage extends StatefulWidget {
  const StudentNotebookPage({super.key});
  @override
  State<StudentNotebookPage> createState() => _StudentNotebookPageState();
}

class _StudentNotebookPageState extends State<StudentNotebookPage> {
  static const studentId = 1;
  int period = 1;
  String query = '';
  final search = TextEditingController();
  final Set<String> expanded = {};
  late Future<List<Map<String, Object?>>> notes;

  @override
  void initState() {
    super.initState();
    notes = StudafyDatabase.instance.studentNotebooks(studentId);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _StudentSectionHeader(title: 'My Notebook'),
        _NotebookPeriods(
          selected: period,
          onSelected: (value) => setState(() => period = value),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: notes,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final filtered = _filterNotes(snapshot.data!);
              final grouped = <String, List<Map<String, Object?>>>{};
              for (final note in filtered) {
                grouped
                    .putIfAbsent('${note['class_name']}', () => [])
                    .add(note);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  final next = StudafyDatabase.instance.studentNotebooks(
                    studentId,
                  );
                  setState(() => notes = next);
                  await next;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    TextField(
                      controller: search,
                      onChanged: (value) =>
                          setState(() => query = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search lessons, subjects, or homework',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} lesson${filtered.length == 1 ? '' : 's'} captured ${const ['today', 'this week', 'this month'][period]}',
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                        if (grouped.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              if (expanded.length == grouped.length) {
                                expanded.clear();
                              } else {
                                expanded.addAll(grouped.keys);
                              }
                            }),
                            child: Text(
                              expanded.length == grouped.length
                                  ? 'Minimise all'
                                  : 'Expand all',
                            ),
                          ),
                      ],
                    ),
                    if (filtered.isEmpty) const _NotebookEmpty(),
                    for (final entry in grouped.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NotebookSubject(
                          subject: entry.key,
                          notes: entry.value,
                          expanded: expanded.contains(entry.key),
                          onToggle: () => setState(() {
                            expanded.contains(entry.key)
                                ? expanded.remove(entry.key)
                                : expanded.add(entry.key);
                          }),
                          onAttachment: _openAttachment,
                          onStudyAction: _studyAction,
                        ),
                      ),
                    if (filtered.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          'Notebook entries are filed by your teachers after lessons. Attachments may include photos, PDFs, documents, slides, spreadsheets, files, and links.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  List<Map<String, Object?>> _filterNotes(List<Map<String, Object?>> source) {
    final now = DateTime.now();
    return source.where((note) {
      final date = DateTime.tryParse('${note['day']}');
      final inPeriod =
          date == null ||
          switch (period) {
            0 =>
              date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day,
            1 => !date.isBefore(
              DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(days: 6)),
            ),
            _ => date.year == now.year && date.month == now.month,
          };
      if (!inPeriod) return false;
      if (query.isEmpty) return true;
      return '${note['class_name']} ${note['lesson']} ${note['homework']}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  Future<void> _openAttachment(Map<String, Object?> attachment) async {
    final uri = '${attachment['uri']}',
        kind = '${attachment['kind']}',
        name = '${attachment['name']}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_attachmentIcon(kind, name), color: _navy),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (kind == 'image' && File(uri).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(uri),
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(_attachmentIcon(kind, name), size: 48, color: _navy),
                      const SizedBox(height: 12),
                      Text(
                        kind == 'link'
                            ? uri
                            : 'This ${_fileType(name)} is attached to the lesson.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save copy'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(kind == 'link' ? 'Open link' : 'Open file'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _studyAction(String action, Map<String, Object?> note) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFF0EFFF),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF7737EE),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${note['class_name']} · ${note['lesson']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(switch (action) {
                'Summarise' => 'Create a concise explanation using the teacher’s lesson notes and attachments.',
                'Quiz me' => 'Generate practice questions grounded only in today’s lesson material.',
                'Flashcards' => 'Turn key facts and definitions from this lesson into review cards.',
                _ => 'Ask a question and get an answer grounded in the filed lesson content.',
              }, style: const TextStyle(color: Color(0xFF5F6680), height: 1.4)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$action is ready for the AI study screen.',
                      ),
                    ),
                  );
                },
                child: Text('Continue to $action'),
              ),
              const SizedBox(height: 7),
              const Text(
                'AI output should be checked against the teacher’s original material.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSectionHeader extends StatelessWidget {
  const _StudentSectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: _navy,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          FutureBuilder<int>(
            future: StudafyDatabase.instance.unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              label: Text('${snapshot.data ?? 0}'),
              backgroundColor: const Color(0xFFFF5D5D),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const StudentNotificationsPage(),
                  ),
                ),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const StudentProfilePage(),
              ),
            ),
            icon: const CircleAvatar(
              radius: 19,
              backgroundColor: _navy,
              child: Text(
                'LH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotebookPeriods extends StatelessWidget {
  const _NotebookPeriods({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x10241D73), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Text(
                  const ['Day', 'Week', 'Month'][i],
                  style: TextStyle(
                    color: selected == i ? _navy : _muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _NotebookSubject extends StatelessWidget {
  const _NotebookSubject({
    required this.subject,
    required this.notes,
    required this.expanded,
    required this.onToggle,
    required this.onAttachment,
    required this.onStudyAction,
  });
  final String subject;
  final List<Map<String, Object?>> notes;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Map<String, Object?>> onAttachment;
  final void Function(String, Map<String, Object?>) onStudyAction;
  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(subject);
    final attachmentTotal = notes.fold<int>(
      0,
      (sum, note) => sum + ((note['attachment_count'] as int?) ?? 0),
    );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x13241D73),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 82,
                  color: color,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 4, backgroundColor: Colors.white),
                      SizedBox(height: 18),
                      CircleAvatar(radius: 4, backgroundColor: Colors.white),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${notes.length} lesson${notes.length == 1 ? '' : 's'} · $attachmentTotal attachment${attachmentTotal == 1 ? '' : 's'} · last ${_relativeDay('${notes.first['day']}')}',
                          style: const TextStyle(
                            color: Color(0xFFA89B78),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFFA89B78),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          if (expanded)
            for (final note in notes)
              _NotebookLesson(
                note: note,
                color: color,
                onAttachment: onAttachment,
                onStudyAction: onStudyAction,
              ),
        ],
      ),
    );
  }
}

class _NotebookLesson extends StatelessWidget {
  const _NotebookLesson({
    required this.note,
    required this.color,
    required this.onAttachment,
    required this.onStudyAction,
  });
  final Map<String, Object?> note;
  final Color color;
  final ValueChanged<Map<String, Object?>> onAttachment;
  final void Function(String, Map<String, Object?>) onStudyAction;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: StudafyDatabase.instance.attachments('notebook', note['id'] as int),
    builder: (context, snapshot) {
      final attachments = snapshot.data ?? [];
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFFFBF1),
          border: Border(top: BorderSide(color: Color(0xFFEDE4CB))),
        ),
        padding: const EdgeInsets.fromLTRB(46, 16, 16, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${note['day']} · PERIOD ${note['session_number']}',
                    style: const TextStyle(
                      color: Color(0xFFA89B78),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${attachments.length} files',
                  style: const TextStyle(
                    color: Color(0xFFA89B78),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${note['lesson']}',
              style: const TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ('${note['homework'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                'Homework: ${note['homework']}',
                style: const TextStyle(color: Color(0xFF625D50), height: 1.4),
              ),
            ],
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 13),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _AttachmentTile(
                    item: attachments[index],
                    onTap: () => onAttachment(attachments[index]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final action in [
                  'Summarise',
                  'Quiz me',
                  'Flashcards',
                  'Ask',
                ])
                  ActionChip(
                    avatar: Icon(
                      action == 'Ask'
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.auto_awesome_rounded,
                      size: 14,
                      color: _navy,
                    ),
                    label: Text(action, style: const TextStyle(fontSize: 10)),
                    onPressed: () => onStudyAction(action, note),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Filed by your teacher · ${_relativeDay('${note['day']}')}',
              style: const TextStyle(color: Color(0xFFA89B78), fontSize: 10),
            ),
          ],
        ),
      );
    },
  );
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.item, required this.onTap});
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final kind = '${item['kind']}',
        name = '${item['name']}',
        uri = '${item['uri']}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE4DDCB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (kind == 'image' && File(uri).existsSync())
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(uri),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Icon(_attachmentIcon(kind, name), color: _navy, size: 27),
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF81775E), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookEmpty extends StatelessWidget {
  const _NotebookEmpty();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 25),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 34,
          backgroundColor: Color(0xFFF0EFFF),
          child: Icon(Icons.library_books_outlined, color: _navy, size: 31),
        ),
        const SizedBox(height: 15),
        const Text(
          'No filed lessons here yet',
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Teacher lesson notes and their photos, documents, PDFs, links, and other files will appear automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You will be notified when a teacher publishes new lesson material.',
              ),
            ),
          ),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Notify me when filed'),
        ),
      ],
    ),
  );
}

IconData _attachmentIcon(String kind, String name) {
  final extension = name.toLowerCase().split('.').last;
  if (kind == 'link') return Icons.link_rounded;
  if (kind == 'image') return Icons.image_outlined;
  if (extension == 'pdf') return Icons.picture_as_pdf_outlined;
  if (['doc', 'docx'].contains(extension)) return Icons.description_outlined;
  if (['ppt', 'pptx'].contains(extension)) return Icons.slideshow_outlined;
  if (['xls', 'xlsx', 'csv'].contains(extension)) {
    return Icons.table_chart_outlined;
  }
  if (['mp3', 'm4a', 'wav'].contains(extension)) {
    return Icons.audio_file_outlined;
  }
  if (['mp4', 'mov'].contains(extension)) return Icons.video_file_outlined;
  return Icons.insert_drive_file_outlined;
}

String _fileType(String name) {
  final parts = name.split('.');
  return parts.length > 1 ? '${parts.last.toUpperCase()} document' : 'file';
}

Color _subjectColor(String subject) {
  const colors = [
    Color(0xFF241D73),
    Color(0xFF20C6E8),
    Color(0xFFE47B00),
    Color(0xFF7737EE),
    Color(0xFFFF315F),
  ];
  return colors[subject.hashCode.abs() % colors.length];
}

String _relativeDay(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final now = DateTime.now();
  final difference = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (difference == 0) return 'today';
  if (difference == 1) return 'yesterday';
  return '${date.day}/${date.month}/${date.year}';
}

class StudentClassworkPage extends StatefulWidget {
  const StudentClassworkPage({super.key});
  @override
  State<StudentClassworkPage> createState() => _StudentClassworkPageState();
}

class _StudentClassworkPageState extends State<StudentClassworkPage> {
  static const studentId = 1;
  int tab = 0;
  String filter = 'All';
  late Future<List<Map<String, Object?>>> assignments;
  late Future<List<Map<String, Object?>>> exams;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    assignments = StudafyDatabase.instance.workForStudent(studentId);
    exams = StudafyDatabase.instance.assessmentsForStudent(studentId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _StudentSectionHeader(title: 'Work'),
        _ClassworkTabs(
          selected: tab,
          onSelected: (value) => setState(() => tab = value),
        ),
        Expanded(child: tab == 0 ? _assignments() : _exams()),
      ],
    ),
  );

  Widget _assignments() => FutureBuilder<List<Map<String, Object?>>>(
    future: assignments,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final all = snapshot.data!;
      final visible = all
          .where((item) => filter == 'All' || _assignmentStatus(item) == filter)
          .toList();
      return RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await assignments;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final value = const [
                        'All',
                        'Due',
                        'Submitted',
                        'Graded',
                        'Late',
                      ][index],
                      selected = filter == value;
                  final count = value == 'All'
                      ? all.length
                      : all
                            .where((item) => _assignmentStatus(item) == value)
                            .length;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => filter = value),
                    label: Text('$value $count'),
                    selectedColor: _navy,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? _navy : const Color(0xFFE0E2ED),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const _ClassworkEmpty(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Nothing in this filter',
                message: 'New teacher assignments will appear automatically.',
              )
            else
              for (final item in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _AssignmentCard(
                    item: item,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AssignmentDetail(
                            item: item,
                            studentId: studentId,
                          ),
                        ),
                      );
                      setState(_reload);
                    },
                  ),
                ),
          ],
        ),
      );
    },
  );

  Widget _exams() => FutureBuilder<List<Map<String, Object?>>>(
    future: exams,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data!
          .where((item) => '${item['delivery']}' != 'online')
          .toList();
      return RefreshIndicator(
        onRefresh: () async {
          setState(_reload);
          await exams;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFBFD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF1687A0),
                    size: 20,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Official exams are completed on paper. This page shows dates and status; reviewed marks appear in Grades only after your teacher publishes them.',
                      style: TextStyle(color: Color(0xFF436A72), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const _ClassworkEmpty(
                icon: Icons.quiz_outlined,
                title: 'No exams assigned',
                message: 'Published quizzes and exams from your classes will appear here.',
              )
            else
              for (final exam in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExamCard(
                    exam: exam,
                    onOpen: () async {
                      // Paper examinations are never launched in-app.
                    },
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _ClassworkTabs extends StatelessWidget {
  const _ClassworkTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEEF7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x10241D73), blurRadius: 6),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      i == 0 ? Icons.assignment_outlined : Icons.quiz_outlined,
                      size: 17,
                      color: selected == i ? _navy : _muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      i == 0 ? 'Assignments' : 'Exam dates',
                      style: TextStyle(
                        color: selected == i ? _navy : _muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item, required this.onTap});
  final Map<String, Object?> item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = _assignmentStatus(item), color = _statusColor(status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(
                        ('${item['class_name']}'.hashCode & 0x00FFFFFF) |
                            0xFF000000,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${item['class_name']}',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _WorkStatus(label: status, color: color),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '${item['title']}',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: status == 'Late' ? color : _muted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      status == 'Late'
                          ? 'Overdue · ${_shortDate('${item['due_at']}')}'
                          : 'Due ${_shortDate('${item['due_at']}')}',
                      style: TextStyle(
                        color: status == 'Late' ? color : _muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (item['score'] != null)
                    Text(
                      'Score ${_score(item['score'])}',
                      style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentDetail extends StatefulWidget {
  const _AssignmentDetail({required this.item, required this.studentId});
  final Map<String, Object?> item;
  final int studentId;
  @override
  State<_AssignmentDetail> createState() => _AssignmentDetailState();
}

class _AssignmentDetailState extends State<_AssignmentDetail> {
  final files = <Map<String, String>>[];
  bool submitting = false;

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles();
    for (final file in result) {
      if (file.path == null) continue;
      final stored = await StudafyDatabase.instance.persistAttachmentFile(
        file.path!,
        file.name,
      );
      files.add({
        'kind': _kindForFile(file.name),
        'name': file.name,
        'uri': stored,
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (files.isEmpty) return;
    setState(() => submitting = true);
    final submissionId = await StudafyDatabase.instance.submitAssignment(
      widget.item['id'] as int,
      widget.studentId,
    );
    await StudafyDatabase.instance.addAttachments(
      'submission',
      submissionId,
      files,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF15885D),
          size: 42,
        ),
        title: const Text('Assignment submitted'),
        content: const Text(
          'Your files were uploaded successfully. You can return before the deadline to add a revised submission.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Assignment'),
      actions: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: _navy,
          child: Text(
            'LH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
      ],
    ),
    body: FutureBuilder<List<List<Map<String, Object?>>>>(
      future: Future.wait([
        StudafyDatabase.instance.attachments(
          'assignment',
          widget.item['id'] as int,
        ),
        if (widget.item['submission_id'] != null)
          StudafyDatabase.instance.attachments(
            'submission',
            widget.item['submission_id'] as int,
          )
        else
          Future.value(<Map<String, Object?>>[]),
      ]),
      builder: (context, snapshot) {
        final teacherFiles = snapshot.data?[0] ?? [],
            submittedFiles = snapshot.data?[1] ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${widget.item['class_name']}',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${widget.item['title']}',
              style: const TextStyle(
                color: _navy,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Due ${widget.item['due_at']}',
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            const Text(
              'Instructions',
              style: TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Complete the work using the lesson material in your Notebook. Include clear working or sources where appropriate, then review every attached file before submitting.',
              style: TextStyle(color: Color(0xFF626981), height: 1.45),
            ),
            if (teacherFiles.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Teacher attachments',
                style: TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final file in teacherFiles) _ClassworkFile(item: file),
            ],
            const SizedBox(height: 20),
            const Text(
              'Your submission',
              style: TextStyle(
                color: _navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (submittedFiles.isNotEmpty) ...[
              for (final file in submittedFiles) _ClassworkFile(item: file),
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < files.length; i++)
              _ClassworkFile(
                item: files[i],
                onRemove: () => setState(() => files.removeAt(i)),
              ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                files.isEmpty ? 'Add submission files' : 'Add more files',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAED),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Accepted: images, PDF, Word, slides, spreadsheets, audio, video, and other teacher-approved files.',
                style: TextStyle(color: Color(0xFF8A7650), fontSize: 10),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: files.isEmpty || submitting ? null : _submit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                widget.item['submitted_at'] == null
                    ? 'Submit assignment'
                    : 'Submit revision',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onOpen});
  final Map<String, Object?> exam;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final paper = '${exam['delivery']}' != 'online',
        submitted = exam['submitted_at'] != null,
        scheduled = DateTime.tryParse('${exam['scheduled_at']}'),
        open =
            !paper &&
            !submitted &&
            (scheduled == null || !scheduled.isAfter(DateTime.now()));
    final status = paper
        ? (exam['score'] == null ? 'Awaiting result' : 'Result published')
        : submitted
        ? (exam['score'] == null ? 'Submitted' : 'Marked')
        : open
        ? 'Open now'
        : 'Scheduled';
    final color = submitted
        ? _muted
        : open
        ? const Color(0xFF15885D)
        : const Color(0xFFB87500);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${exam['class_name']}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _WorkStatus(label: status, color: color),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${exam['title']}',
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${exam['type']} · ${exam['max_score']} marks${scheduled == null ? '' : ' · ${_shortDate('${exam['scheduled_at']}')}'}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: open ? onOpen : null,
              child: Text(
                paper
                    ? (exam['score'] == null
                          ? 'Paper exam · result pending'
                          : 'Grade ${_score(exam['score'])}/${exam['max_score']}')
                    : submitted
                    ? (exam['score'] == null
                          ? 'Awaiting marking'
                          : 'Marked ${_score(exam['score'])}/${exam['max_score']}')
                    : open
                    ? 'Start ${'${exam['type']}'.toLowerCase()}'
                    : 'Not open yet',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamRunner extends StatefulWidget {
  const _ExamRunner({required this.exam, required this.studentId});
  final Map<String, Object?> exam;
  final int studentId;
  @override
  State<_ExamRunner> createState() => _ExamRunnerState();
}

class _ExamRunnerState extends State<_ExamRunner> {
  int current = 0;
  List<Map<String, Object?>> questions = [];
  final answers = <int, String>{};

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text('${widget.exam['type']}'),
      actions: [TextButton(onPressed: _review, child: const Text('Review'))],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.assessmentQuestions(
        widget.exam['id'] as int,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        questions = snapshot.data!;
        if (questions.isEmpty) {
          return const _ClassworkEmpty(
            icon: Icons.quiz_outlined,
            title: 'Questions unavailable',
            message: 'Ask your teacher to publish the exam questions.',
          );
        }
        final question = questions[current],
            options = _options('${question['options'] ?? ''}');
        return Column(
          children: [
            Container(
              color: _navy,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Question ${current + 1} of ${questions.length} · ${widget.exam['title']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${question['points']} marks',
                        style: const TextStyle(
                          color: _cyan,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  LinearProgressIndicator(
                    value: (current + 1) / questions.length,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    color: _cyan,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${question['prompt']}',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (options.isNotEmpty)
                    RadioGroup<String>(
                      groupValue: answers[question['id']],
                      onChanged: (value) => setState(
                        () => answers[question['id'] as int] = value ?? '',
                      ),
                      child: Column(
                        children: [
                          for (final option in options)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                child: RadioListTile<String>(
                                  value: option,
                                  title: Text(option),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    TextFormField(
                      key: ValueKey(question['id']),
                      initialValue: answers[question['id']] ?? '',
                      minLines: 5,
                      maxLines: 10,
                      onChanged: (value) =>
                          answers[question['id'] as int] = value,
                      decoration: const InputDecoration(
                        hintText: 'Write your answer here…',
                        alignLabelWithHint: true,
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    if (current > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => current--),
                        child: const Text('Previous'),
                      ),
                    if (current > 0) const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton(
                        onPressed: current == questions.length - 1
                            ? _review
                            : () => setState(() => current++),
                        child: Text(
                          current == questions.length - 1
                              ? 'Review answers'
                              : 'Next question',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _review() async {
    if (questions.isEmpty) return;
    final unanswered = questions
        .where((q) => (answers[q['id']] ?? '').trim().isEmpty)
        .length;
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          unanswered == 0
              ? Icons.fact_check_outlined
              : Icons.warning_amber_rounded,
          color: unanswered == 0 ? _navy : const Color(0xFFB87500),
          size: 38,
        ),
        title: const Text('Review and submit'),
        content: Text(
          unanswered == 0
              ? 'All ${questions.length} questions have answers. Once submitted, you cannot change them.'
              : '$unanswered of ${questions.length} questions are unanswered. You can return to complete them or submit now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reviewing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit exam'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    final encoded = questions
        .map((q) => 'Q${q['id']}: ${answers[q['id']] ?? '[unanswered]'}')
        .join('\n');
    await StudafyDatabase.instance.submitAssessment(
      widget.exam['id'] as int,
      widget.studentId,
      encoded,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF15885D),
          size: 42,
        ),
        title: const Text('Exam submitted'),
        content: const Text(
          'Your answers were submitted successfully. Your result will appear after your teacher marks and publishes it.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

class _ClassworkFile extends StatelessWidget {
  const _ClassworkFile({required this.item, this.onRemove});
  final Map<String, Object?> item;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0E2ED)),
    ),
    child: Row(
      children: [
        Icon(
          _attachmentIcon('${item['kind']}', '${item['name']}'),
          color: _navy,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${item['name']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
          )
        else
          const Icon(Icons.download_outlined, color: _muted),
      ],
    ),
  );
}

class _WorkStatus extends StatelessWidget {
  const _WorkStatus({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class _ClassworkEmpty extends StatelessWidget {
  const _ClassworkEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 28),
      child: Column(
        children: [
          Icon(icon, color: _navy, size: 45),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}

String _assignmentStatus(Map<String, Object?> item) {
  if (item['score'] != null) return 'Graded';
  if (item['submitted_at'] != null) return 'Submitted';
  final due = DateTime.tryParse('${item['due_at']}');
  if (due != null && due.isBefore(DateTime.now())) return 'Late';
  return 'Due';
}

Color _statusColor(String status) => switch (status) {
  'Graded' || 'Submitted' => const Color(0xFF15885D),
  'Late' => const Color(0xFFFF4757),
  _ => const Color(0xFFB87500),
};

List<String> _options(String raw) => raw.trim().isEmpty
    ? []
    : raw
          .split(RegExp(r'\n|\|'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

String _kindForFile(String name) {
  final ext = name.toLowerCase().split('.').last;
  return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)
      ? 'image'
      : 'file';
}

class StudentAiPage extends StatefulWidget {
  const StudentAiPage({super.key});
  @override
  State<StudentAiPage> createState() => _StudentAiPageState();
}

class _StudentAiPageState extends State<StudentAiPage> {
  static const studentId = 1;
  late Future<List<Object>> data;

  @override
  void initState() {
    super.initState();
    data = Future.wait<Object>([
      StudafyDatabase.instance.classesForStudent(studentId),
      StudafyDatabase.instance.studentNotebooks(studentId),
      StudafyDatabase.instance.gradesForStudent(studentId),
      StudafyDatabase.instance.workForStudent(studentId),
    ]);
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    body: Column(
      children: [
        const _StudentHeader(title: 'Study Coach'),
        Expanded(
          child: FutureBuilder<List<Object>>(
            future: data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = snapshot.data![0] as List<Map<String, Object?>>;
              final notes = snapshot.data![1] as List<Map<String, Object?>>;
              final grades = snapshot.data![2] as List<Map<String, Object?>>;
              final work = snapshot.data![3] as List<Map<String, Object?>>;
              final weak = _weakestClass(classes, grades, work);
              final weakTopic = _topicFor(weak, notes);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_navy, Color(0xFF4B3FC2)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: _cyan,
                          size: 30,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Learn from your classes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your teacher’s notebook content is already connected. Choose a tool and start studying.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  if (weak != null) ...[
                    const SizedBox(height: 16),
                    _AiRecommendation(
                      subject: weak,
                      topic: weakTopic,
                      onStudy: () => _open(
                        _AiStudyPage(
                          subject: weak,
                          topic: weakTopic,
                          notes: notes,
                        ),
                      ),
                      onQuiz: () => _open(
                        _AiPracticePage(
                          classes: classes,
                          notes: notes,
                          initialClass: weak,
                          flashcards: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Study tools',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AiToolTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Ask Me',
                    subtitle:
                        'Ask about your notebook, or attach something new',
                    onTap: () => _open(const AskAiPage()),
                  ),
                  _AiToolTile(
                    icon: Icons.quiz_outlined,
                    title: 'Create a quiz',
                    subtitle: 'Choose a class and lesson topic',
                    onTap: () => _open(
                      _AiPracticePage(
                        classes: classes,
                        notes: notes,
                        flashcards: false,
                      ),
                    ),
                  ),
                  _AiToolTile(
                    icon: Icons.style_outlined,
                    title: 'Make flashcards',
                    subtitle: 'Review key facts from teacher materials',
                    onTap: () => _open(
                      _AiPracticePage(
                        classes: classes,
                        notes: notes,
                        flashcards: true,
                      ),
                    ),
                  ),
                  _AiToolTile(
                    icon: Icons.insights_rounded,
                    title: 'Learning evaluator',
                    subtitle: 'Find weak subjects and get a focused next step',
                    onTap: () => _open(
                      _AiEvaluatorPage(
                        classes: classes,
                        notes: notes,
                        grades: grades,
                        work: work,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _AiRecommendation extends StatelessWidget {
  const _AiRecommendation({
    required this.subject,
    required this.topic,
    required this.onStudy,
    required this.onQuiz,
  });
  final String subject, topic;
  final VoidCallback onStudy, onQuiz;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E8),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0D89A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended for you',
          style: TextStyle(
            color: Color(0xFFB87500),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '$subject · $topic',
          style: const TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Recent results suggest this is the best place to focus next.',
          style: TextStyle(color: _muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onStudy,
                child: const Text('Study material'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton(
                onPressed: onQuiz,
                style: FilledButton.styleFrom(backgroundColor: _navy),
                child: const Text('Practice quiz'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AiToolTile extends StatelessWidget {
  const _AiToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9EAF4)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFEDFF),
          foregroundColor: _navy,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
        trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
      ),
    ),
  );
}

class AskAiPage extends StatefulWidget {
  const AskAiPage({super.key});
  @override
  State<AskAiPage> createState() => _AskAiPageState();
}

class _AskAiPageState extends State<AskAiPage> {
  final controller = TextEditingController();
  final messages = <({bool user, String body})>[];
  String? attachment, attachmentLocalPath;
  bool sending = false;

  Future<void> _attach() async {
    if (!StudafyRuntime.policy.allowsRemoteFileUploads) return;
    final files = await FilePicker.pickFiles();
    if (files.isNotEmpty && files.first.path != null) {
      setState(() {
        attachment = files.first.name;
        attachmentLocalPath = files.first.path;
      });
    }
  }

  Future<void> _send() async {
    final value = controller.text.trim();
    if (value.isEmpty || sending) return;
    setState(() {
      sending = true;
      messages.add((user: true, body: value));
      messages.add((user: false, body: 'Reading your authorized materials…'));
      controller.clear();
    });
    try {
      final answer = await StudyCoachScope.read(context).ask(question: value);
      if (mounted) {
        setState(
          () => messages[messages.length - 1] = (user: false, body: answer),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => messages[messages.length - 1] = (
            user: false,
            body: '$error'.replaceFirst('Bad state: ', ''),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
          attachment = null;
          attachmentLocalPath = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Ask Me')),
    body: Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 45,
                          color: _navy,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Ask about your class materials',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Your notebooks and teacher attachments are already available here. New file attachments are temporarily unavailable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final message = messages[i];
                    final user = message.user;
                    return Align(
                      alignment: user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          color: user ? _navy : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.body,
                          style: TextStyle(
                            color: user ? Colors.white : _ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (attachment != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(Icons.attach_file_rounded, size: 18, color: _navy),
                Expanded(
                  child: Text(attachment!, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    attachment = null;
                    attachmentLocalPath = null;
                  }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ask about your materials',
                prefixIcon: IconButton(
                  key: const Key('study-coach-attachment-control'),
                  tooltip: 'File attachments are temporarily unavailable',
                  onPressed: StudafyRuntime.policy.allowsRemoteFileUploads
                      ? _attach
                      : null,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.arrow_upward_rounded, color: _navy),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AiPracticePage extends StatefulWidget {
  const _AiPracticePage({
    required this.classes,
    required this.notes,
    required this.flashcards,
    this.initialClass,
  });
  final List<Map<String, Object?>> classes, notes;
  final bool flashcards;
  final String? initialClass;
  @override
  State<_AiPracticePage> createState() => _AiPracticePageState();
}

class _AiPracticePageState extends State<_AiPracticePage> {
  String? selectedClass;
  String? selectedTopic;
  bool generating = false;
  String? error;

  List<String> get classNames => widget.classes
      .map((entry) => '${entry['name']}')
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    selectedClass =
        widget.initialClass ?? (classNames.isEmpty ? null : classNames.first);
  }

  List<String> get topics {
    final found = widget.notes
        .where((e) => e['class_name'] == selectedClass)
        .map((e) => '${e['lesson']}')
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    return found.isEmpty
        ? ['Current lesson', 'Recent homework', 'Key concepts']
        : found;
  }

  Future<void> _generate() async {
    final topic = selectedTopic ?? topics.first;
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final row = widget.classes.firstWhere(
        (item) => '${item['name']}' == selectedClass,
      );
      final classroomId = row['remote_id'] as String?;
      if (classroomId == null) {
        throw StateError(
          'This class is still syncing. Practice can be generated when sync completes.',
        );
      }
      final studyCoach = StudyCoachScope.read(context);
      final page = widget.flashcards
          ? _FlashcardSession(
              subject: selectedClass ?? 'Class',
              topic: topic,
              cards: await studyCoach.flashcards(
                classroomId: classroomId,
                topic: topic,
              ),
            )
          : _AiQuizSession(
              subject: selectedClass ?? 'Class',
              topic: topic,
              questions: await studyCoach.quiz(
                classroomId: classroomId,
                topic: topic,
              ),
            );
      if (mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
      }
    } catch (caught) {
      if (mounted) {
        setState(() => error = '$caught'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(
      title: Text(widget.flashcards ? 'Create flashcards' : 'Create a quiz'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Choose your material',
          style: TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The AI uses the selected teacher notebook and its attachments automatically.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        DropdownButtonFormField<String>(
          initialValue: selectedClass,
          decoration: const InputDecoration(labelText: 'Class'),
          items: classNames
              .map((name) => DropdownMenuItem(value: name, child: Text(name)))
              .toList(),
          onChanged: (v) => setState(() {
            selectedClass = v;
            selectedTopic = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedTopic,
          decoration: const InputDecoration(labelText: 'Topic'),
          items: topics
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => selectedTopic = v),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: selectedClass == null || generating ? null : _generate,
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            minimumSize: const Size.fromHeight(54),
          ),
          icon: Icon(
            widget.flashcards ? Icons.style_outlined : Icons.quiz_outlined,
          ),
          label: Text(
            generating
                ? 'Generating from class material…'
                : widget.flashcards
                ? 'Generate flashcards'
                : 'Generate quiz',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(color: Color(0xFFE74747))),
        ],
      ],
    ),
  );
}

class _AiQuizSession extends StatefulWidget {
  const _AiQuizSession({
    required this.subject,
    required this.topic,
    required this.questions,
  });
  final String subject, topic;
  final List<StudyQuizQuestion> questions;
  @override
  State<_AiQuizSession> createState() => _AiQuizSessionState();
}

class _AiQuizSessionState extends State<_AiQuizSession> {
  int index = 0;
  int? selected;
  int correct = 0;
  List<StudyQuizQuestion> get questions => widget.questions;

  void _next() {
    if (selected == null) return;
    if (selected == questions[index].correctIndex) correct++;
    if (index == questions.length - 1) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quiz complete'),
          content: Text(
            'You scored $correct out of ${questions.length}. Your result can now inform future study recommendations.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        index++;
        selected = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[index];
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(title: Text(widget.subject)),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (index + 1) / questions.length,
              color: _cyan,
              backgroundColor: const Color(0xFFE5E6F1),
            ),
            const SizedBox(height: 28),
            Text(
              'Question ${index + 1} of ${questions.length}',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              q.prompt,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) => setState(() => selected = value),
              child: Column(
                children: [
                  for (var i = 0; i < q.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RadioListTile<int>(
                        value: i,
                        title: Text(q.options[i]),
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Color(0xFFE2E4F0)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: selected == null ? null : _next,
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(
                index == questions.length - 1 ? 'Finish quiz' : 'Next question',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlashcardSession extends StatefulWidget {
  const _FlashcardSession({
    required this.subject,
    required this.topic,
    required this.cards,
  });
  final String subject, topic;
  final List<StudyFlashcard> cards;
  @override
  State<_FlashcardSession> createState() => _FlashcardSessionState();
}

class _FlashcardSessionState extends State<_FlashcardSession> {
  int index = 0;
  bool answer = false;
  List<StudyFlashcard> get cards => widget.cards;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Flashcards')),
    body: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            '${widget.subject} · ${index + 1} of ${cards.length}',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => answer = !answer),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      answer ? 'ANSWER' : 'QUESTION',
                      style: const TextStyle(
                        color: _cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      answer ? cards[index].back : cards[index].front,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Tap card to flip',
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: index == 0
                      ? null
                      : () => setState(() {
                          index--;
                          answer = false;
                        }),
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (index == cards.length - 1) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        index++;
                        answer = false;
                      });
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: _navy),
                  child: Text(index == cards.length - 1 ? 'Finish' : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AiStudyPage extends StatelessWidget {
  const _AiStudyPage({
    required this.subject,
    required this.topic,
    required this.notes,
  });
  final String subject, topic;
  final List<Map<String, Object?>> notes;
  @override
  Widget build(BuildContext context) {
    final material = notes.where((e) => e['class_name'] == subject).toList();
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(title: Text(subject)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            topic,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recommended teacher material',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 18),
          for (final note in material)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${note['lesson']}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if ('${note['homework'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${note['homework']}',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Text(
                    '${note['attachment_count'] ?? 0} teacher attachments',
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (material.isEmpty)
            const _ClassworkEmpty(
              icon: Icons.menu_book_outlined,
              title: 'No material yet',
              message: 'This recommendation will fill in when the teacher publishes the lesson notebook.',
            ),
        ],
      ),
    );
  }
}

class _AiEvaluatorPage extends StatelessWidget {
  const _AiEvaluatorPage({
    required this.classes,
    required this.notes,
    required this.grades,
    required this.work,
  });
  final List<Map<String, Object?>> classes, notes, grades, work;
  @override
  Widget build(BuildContext context) {
    final rows = classes.map((c) {
      final name = '${c['name']}';
      final values = <double>[
        ...grades
            .where((e) => e['class_name'] == name)
            .map((e) => (e['score'] as num) * 100 / (e['max_score'] as num)),
        ...work
            .where((e) => e['class_name'] == name && e['score'] != null)
            .map((e) => (e['score'] as num).toDouble()),
      ];
      final average = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
      final overdue = work
          .where(
            (e) =>
                e['class_name'] == name &&
                e['submitted_at'] == null &&
                (DateTime.tryParse('${e['due_at']}')
                        ?.isBefore(DateTime.now()) ??
                    false),
          )
          .length;
      return (
        name: name,
        average: average,
        sample: values.length,
        overdue: overdue,
        topic: _topicFor(name, notes),
      );
    }).toList()..sort((a, b) => (a.average ?? 101).compareTo(b.average ?? 101));
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(title: const Text('Learning evaluator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your learning signals',
            style: TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Recommendations use published quizzes, exams, homework scores, submissions, and notebook topics. They are study guidance—not a final grade.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (final row in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: row.average != null && row.average! < 70
                      ? const Color(0xFFFFD0D0)
                      : const Color(0xFFE9EAF4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.name,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        row.average == null || row.sample < 3
                            ? 'Insufficient data'
                            : '${row.average!.round()}%',
                        style: TextStyle(
                          color: row.average != null && row.average! < 70
                              ? const Color(0xFFE74747)
                              : const Color(0xFF15885D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    row.average == null || row.sample < 3
                        ? '${row.sample} published result(s). At least 3 are required before Study Coach identifies a learning pattern.'
                        : row.average! < 70
                        ? 'Focus next: ${row.topic}. ${row.overdue > 0 ? '${row.overdue} overdue item also needs attention.' : 'Practice recall before your next assessment.'}'
                        : 'On track. Keep reviewing ${row.topic} to maintain momentum.',
                    style: const TextStyle(color: _muted, height: 1.4),
                  ),
                  if (row.average != null &&
                      row.sample >= 3 &&
                      row.average! < 70) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Study material'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _AiStudyPage(
                                subject: row.name,
                                topic: row.topic,
                                notes: notes,
                              ),
                            ),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Make quiz'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _AiPracticePage(
                                classes: classes,
                                notes: notes,
                                initialClass: row.name,
                                flashcards: false,
                              ),
                            ),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Flashcards'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _AiPracticePage(
                                classes: classes,
                                notes: notes,
                                initialClass: row.name,
                                flashcards: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String? _weakestClass(
  List<Map<String, Object?>> classes,
  List<Map<String, Object?>> grades,
  List<Map<String, Object?>> work,
) {
  String? result;
  double lowest = double.infinity;
  for (final c in classes) {
    final name = '${c['name']}';
    final values = <double>[
      ...grades
          .where((e) => e['class_name'] == name)
          .map((e) => (e['score'] as num) * 100 / (e['max_score'] as num)),
      ...work
          .where((e) => e['class_name'] == name && e['score'] != null)
          .map((e) => (e['score'] as num).toDouble()),
    ];
    final overdue = work
        .where(
          (e) =>
              e['class_name'] == name &&
              e['submitted_at'] == null &&
              (DateTime.tryParse('${e['due_at']}')?.isBefore(DateTime.now()) ??
                  false),
        )
        .length;
    if (values.length < 3 && overdue < 2) continue;
    final average = values.isEmpty
        ? 59.0
        : values.reduce((a, b) => a + b) / values.length;
    if (average < lowest) {
      lowest = average;
      result = name;
    }
  }
  return result;
}

String _topicFor(String? subject, List<Map<String, Object?>> notes) {
  final found = notes.where((e) => e['class_name'] == subject).toList();
  return found.isEmpty ? 'recent class topics' : '${found.first['lesson']}';
}

String _shortDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  return '${date.day}/${date.month}';
}

String _score(Object? value) {
  if (value is num) {
    return value == value.roundToDouble()
        ? '${value.toInt()}'
        : value.toStringAsFixed(1);
  }
  return '—';
}
