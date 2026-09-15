import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import '../../../features/academic/data/preview_student_identity.dart';
import 'student_account_pages.dart';
import 'student_shared.dart';

class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({super.key});

  @override
  State<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage> {
  static const studentId = PreviewStudentIdentity.localId;
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
    backgroundColor: studentCanvas,
    body: Column(
      children: [
        const StudentHeader(title: 'Grades'),
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
                        color: studentInk,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Open a class to see every result recorded by its teacher.',
                      style: TextStyle(color: studentMuted, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    if (groups.isEmpty)
                      const StudentEmptyState(
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
                    color: selected == i ? studentNavy : studentMuted,
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
            color: studentInk,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'See your presence, absences, late arrivals and excused days for every enrolled class.',
          style: TextStyle(color: studentMuted, height: 1.4),
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
                (classroom['color'] as num?)?.toInt() ?? studentNavy.toARGB32(),
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
                      color: studentInk,
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
                        _AttendanceMetric('Excused', excused, studentCyan),
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
        Text(label, style: const TextStyle(color: studentMuted, fontSize: 10)),
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
      color: studentNavy,
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
                color: studentCyan,
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
      (group.classroom['color'] as num?)?.toInt() ?? studentNavy.toARGB32(),
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
          style: const TextStyle(
            color: studentInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          'Grade ${group.classroom['grade']} · Section ${group.classroom['section']} · ${group.results.length} results',
          style: const TextStyle(color: studentMuted, fontSize: 12),
        ),
        trailing: Text(
          average == null ? '—' : '${average.round()}%',
          style: const TextStyle(
            color: studentNavy,
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
                style: TextStyle(color: studentMuted),
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
      color: studentCanvas,
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
                  color: studentInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${_average(results)!.round()}% average',
              style: const TextStyle(
                color: studentMuted,
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
                    color: studentInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${studentScore(results[i].score)} / ${studentScore(results[i].maximum)}',
                style: const TextStyle(
                  color: studentNavy,
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
