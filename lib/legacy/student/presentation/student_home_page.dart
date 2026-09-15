import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../studafy_database.dart';
import '../../../features/academic/data/preview_student_identity.dart';
import 'student_account_pages.dart';
import 'student_home_components.dart';
import 'student_shared.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});
  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  static const studentId = PreviewStudentIdentity.localId;
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
    backgroundColor: studentCanvas,
    body: Column(
      children: [
        const StudentHeader(),
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
                          ?.copyWith(color: studentNavy, fontSize: 26),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat(
                        'EEEE, d MMMM',
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(DateTime.now()),
                      style: const TextStyle(color: studentMuted),
                    ),
                    if (notices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      StudentAnnouncementSpotlight(notices: notices),
                    ],
                    const SizedBox(height: 14),
                    StudentTodayClasses(classes: classes),
                    const SizedBox(height: 14),
                    StudentDueSoon(work: work),
                    const SizedBox(height: 14),
                    StudentNewGrades(grades: grades),
                    const SizedBox(height: 14),
                    const StudentDayPlan(),
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
