import 'package:flutter/material.dart';

import '../core/studafy_design.dart';
import '../features/classes/domain/classroom.dart';
import '../features/classes/presentation/classes_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/school_operations/presentation/classroom_management_page.dart';
import '../features/school_operations/presentation/guardian_verification_page.dart';
import '../features/school_operations/presentation/terms_page.dart';
import '../features/school_operations/domain/school_operations_repository.dart';
import 'account_hub_page.dart';
import 'app_dependencies.dart';

class SchoolAdminShell extends StatefulWidget {
  const SchoolAdminShell({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<SchoolAdminShell> createState() => _SchoolAdminShellState();
}

class _SchoolAdminShellState extends State<SchoolAdminShell> {
  int _index = 0;
  String _t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<void> _openClassroom(ClassroomSummary classroom) async {
    final repository = widget.dependencies.schoolOperations;
    if (repository == null) return;
    final result = await widget.dependencies.classes.loadClasses();
    if (!mounted) return;
    final classes = result.fold(
      onSuccess: (value) => value,
      onFailure: (_) => <ClassroomSummary>[classroom],
    );
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ClassroomManagementPage(
          repository: repository,
          classroom: ManagedClassroom(
            id: classroom.id.value,
            name: classroom.name,
          ),
          classrooms: [
            for (final item in classes)
              ManagedClassroom(id: item.id.value, name: item.name),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operations = widget.dependencies.schoolOperations;
    if (operations == null) {
      return Scaffold(
        body: Center(
          child: Text(
            _t(
              context,
              'Administration requires the remote backend.',
              'تتطلب الإدارة الاتصال بالخادم.',
            ),
          ),
        ),
      );
    }
    final pages = [
      ClassesPage(
        classes: widget.dependencies.classes,
        onOpenClassroom: _openClassroom,
        header: _AdminHeader(
          title: _t(context, 'School administration', 'إدارة المدرسة'),
        ),
      ),
      TermsPage(repository: operations),
      GuardianVerificationPage(repository: operations),
      // Re-reads when its tab comes into view; an IndexedStack would
      // otherwise hold the feed as it was at launch all session.
      NotificationsPage(visible: _index == 3),
      const AccountHubPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: _t(context, 'Classes', 'الفصول'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.date_range_outlined),
            selectedIcon: const Icon(Icons.date_range),
            label: _t(context, 'Terms', 'الفصول الدراسية'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.verified_user_outlined),
            selectedIcon: const Icon(Icons.verified_user),
            label: _t(context, 'Guardians', 'أولياء الأمور'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: _t(context, 'Updates', 'التحديثات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_circle_outlined),
            selectedIcon: const Icon(Icons.account_circle),
            label: _t(context, 'Account', 'الحساب'),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: studafyInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const AccountButton(),
          ],
        ),
      ),
    ),
  );
}
