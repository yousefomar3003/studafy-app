import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_localizations.dart';
import 'student_ai_page.dart';
import 'student_classwork_page.dart';
import 'student_home_page.dart';
import 'student_notebook_page.dart';
import 'student_progress_page.dart';
import 'student_shared.dart';

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
      accent: studentNavy,
    ),
  );
}
