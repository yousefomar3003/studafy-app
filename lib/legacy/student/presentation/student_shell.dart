import 'package:flutter/material.dart';

import '../../../app/account_hub_page.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_localizations.dart';
import '../../../core/studafy_domain.dart';
import '../../../features/academic/domain/academic_repository.dart';
import '../../../features/academic/presentation/academic_overview_page.dart';
import '../../../features/messaging/presentation/conversations_page.dart';
import '../../../features/messaging/presentation/messaging_scope.dart';
import 'student_shared.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.academic});
  final AcademicRepository academic;
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final repository = widget.academic;
    final studentId = ActiveContextController.instance.selectedStudent?.id;
    final messaging = MessagingScope.isAvailable(context);
    final pages = <Widget>[
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        actions: const [AccountButton()],
      ),
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        initialFeed: AcademicFeed.content,
        actions: const [AccountButton()],
      ),
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        initialFeed: AcademicFeed.assignments,
        actions: const [AccountButton()],
      ),
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        initialFeed: AcademicFeed.grades,
        actions: const [AccountButton()],
      ),
      if (messaging) const ConversationsPage(),
    ];
    return Scaffold(
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
          if (messaging)
            StudafyNavItem(
              StudafyLocalizations.of(context).text('messages'),
              Icons.forum_outlined,
              Icons.forum_rounded,
            ),
        ],
        accent: studentNavy,
      ),
    );
  }
}
