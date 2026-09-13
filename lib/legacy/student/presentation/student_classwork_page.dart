import 'package:flutter/material.dart';

import '../../../studafy_database.dart';
import 'student_account_pages.dart';
import 'student_classwork_assignment.dart';
import 'student_classwork_exam.dart';
import 'student_shared.dart';

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
    backgroundColor: studentCanvas,
    body: Column(
      children: [
        const StudentSectionHeader(title: 'Work'),
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
          .where(
            (item) =>
                filter == 'All' || studentAssignmentStatus(item) == filter,
          )
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
                            .where(
                              (item) => studentAssignmentStatus(item) == value,
                            )
                            .length;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => filter = value),
                    label: Text('$value $count'),
                    selectedColor: studentNavy,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : studentMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? studentNavy : const Color(0xFFE0E2ED),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const StudentEmptyState(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Nothing in this filter',
                message: 'New teacher assignments will appear automatically.',
              )
            else
              for (final item in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: StudentAssignmentCard(
                    item: item,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentAssignmentDetail(
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
              const StudentEmptyState(
                icon: Icons.quiz_outlined,
                title: 'No exams assigned',
                message: 'Published quizzes and exams from your classes will appear here.',
              )
            else
              for (final exam in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StudentExamCard(
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
                      color: selected == i ? studentNavy : studentMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      i == 0 ? 'Assignments' : 'Exam dates',
                      style: TextStyle(
                        color: selected == i ? studentNavy : studentMuted,
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
