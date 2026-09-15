import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../core/studafy_localizations.dart';
import '../features/classes/domain/classroom.dart';
import '../features/classes/presentation/classes_page.dart';
import '../features/academic/presentation/academic_overview_page.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/teacher_dashboard/presentation/teacher_dashboard.dart';
import '../teacher_features.dart';
import 'app_dependencies.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int index = 0;

  // API-041 classes open only the typed authoritative/preview academic port.
  Future<void> _openClassroom(ClassroomSummary classroom) async {
    final academic = widget.dependencies.academic;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AcademicOverviewPage(
          repository: academic,
          classroomId: classroom.id.value,
          teacherTools: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    void open(Widget page) {
      Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    final dashboardActions = TeacherDashboardActions(
      openChats: () => open(const ChatsPage()),
      openNotifications: () => open(const NotificationsPage()),
      openProfile: () => open(const MyStudafyPage()),
    );
    final pages = [
      TeacherHome(actions: dashboardActions),
      ClassesPage(
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        header: const FeatureHeader('Classes'),
      ),
      AcademicOverviewPage(
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.content,
      ),
      AcademicOverviewPage(
        repository: widget.dependencies.academic,
        teacherTools: true,
        initialFeed: AcademicFeed.grades,
      ),
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
        accent: studafyNavy,
      ),
    );
  }
}
