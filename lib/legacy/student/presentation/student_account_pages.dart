import 'package:flutter/material.dart';

import '../../../core/language_picker.dart';
import '../../../data/session_service.dart';
import '../../../features/notifications/presentation/notification_badge.dart';
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
          const NotificationBadge(),
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
                  Localizations.localeOf(context).languageCode == 'ar'
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
          const NotificationBadge(),
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
