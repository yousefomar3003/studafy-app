import 'package:flutter/material.dart';

import '../../../core/studafy_localizations.dart';
import '../../../data/session_service.dart';
import '../../../studafy_database.dart';
import '../../../student_linking.dart';
import '../../../app/account_scope.dart';
import '../../../features/account/presentation/delete_account_page.dart';
import 'student_shared.dart';

class StudentHeader extends StatelessWidget {
  const StudentHeader({super.key, this.title});
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
                          color: studentNavy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        'Al-Noor International',
                        style: TextStyle(color: studentMuted, fontSize: 12),
                      ),
                    ],
                  )
                : Text(
                    title!,
                    style: const TextStyle(
                      color: studentInk,
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
              backgroundColor: studentNavy,
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
          child: Text(label, style: const TextStyle(color: studentMuted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: studentInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: studentCanvas,
    appBar: AppBar(title: const Text('Profile')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: studentNavy,
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
                      color: studentInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'layla.hassan@alnoor.edu',
                    style: TextStyle(color: studentMuted),
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
    backgroundColor: studentCanvas,
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
              builder: (_) => DeleteAccountPage(
                email: accountEmail(context),
                account: AccountScope.of(context),
              ),
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
        color: studentMuted,
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
    backgroundColor: studentCanvas,
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
                '${g['title']} — ${studentScore(g['score'])}/${studentScore(g['max_score'])} was published.',
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
                '${due.first['title']} is due ${studentShortDate('${due.first['due_at']}')}.',
          ));
        }
        if (exams.isNotEmpty) {
          cards.add((
            id: 'exam',
            icon: Icons.event_note_rounded,
            color: studentNavy,
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
                const StudentEmptyState(
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
                                      color: studentInk,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (!read.contains(card.id))
                                  const CircleAvatar(
                                    radius: 4,
                                    backgroundColor: studentCyan,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              card.detail,
                              style: const TextStyle(
                                color: studentMuted,
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

class StudentSectionHeader extends StatelessWidget {
  const StudentSectionHeader({super.key, required this.title});
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
                color: studentNavy,
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
              backgroundColor: studentNavy,
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
