import 'package:flutter/material.dart';

import '../../../app/account_hub_page.dart';
import '../../../app/student_today_page.dart';
import '../../../features/classes/application/class_list_interactor.dart';
import '../../../features/classes/presentation/join_class_page.dart';
import '../../../features/academic/presentation/submit_work_page.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_localizations.dart';
import '../../../core/studafy_domain.dart';
import '../../../features/academic/domain/academic_repository.dart';
import '../../../features/academic/presentation/academic_overview_page.dart';
import '../../../features/messaging/presentation/conversations_page.dart';
import '../../../features/messaging/presentation/messaging_scope.dart';
import 'student_shared.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.academic, this.classes});
  final AcademicRepository academic;

  /// Lets a student join a class from a link they were sent. Optional so the
  /// preview shell, which has no school service behind it, still builds.
  final ClassListInteractor? classes;
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
      StudentTodayPage(
        academic: repository,
        onWork: () => setState(() => index = 2),
        onNotebook: () => setState(() => index = 1),
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
        // Only published work can be handed in; a draft is not the
        // student's to see as open.
        onOpenRecord: (record) async {
          final messenger = ScaffoldMessenger.of(context);
          final done = await Navigator.of(context).push<String>(
            MaterialPageRoute<String>(
              builder: (_) => SubmitWorkPage(
                repository: repository,
                assignmentId: record.id,
                assignmentTitle: record.title,
                canSubmit: record.state == 'published',
              ),
            ),
          );
          if (done != null) {
            messenger.showSnackBar(SnackBar(content: Text(done)));
          }
        },
      ),
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        initialFeed: AcademicFeed.grades,
        actions: const [AccountButton()],
      ),
      if (messaging) const ConversationsPage(),
    ];
    final classes = widget.classes;
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      // Always reachable, not only from an empty state: a student joins a
      // second class on the same day they join their first, and the link
      // often arrives in a chat app rather than as something tappable.
      floatingActionButton: classes == null || index != 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JoinClassPage(classes: classes),
                ),
              ),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'انضم إلى فصل'
                    : 'Join a class',
              ),
            ),
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
