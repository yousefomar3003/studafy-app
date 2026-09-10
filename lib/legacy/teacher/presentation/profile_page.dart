part of '../../../teacher_features.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool biometricLock = false;
  bool weeklyDigest = true;
  bool lessonReminders = true;
  bool compactMode = false;
  String language = 'English';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Settings'),
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: StudafyDatabase.instance.profile(),
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p == null) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FeatureCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: _navy,
                    child: Text(
                      'RH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${p['email']}',
                          style: const TextStyle(color: _muted),
                        ),
                        Text(
                          '${p['school']}',
                          style: const TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _edit(context, p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FeatureCard(
              onTap: () {
                ActiveContextController.instance.switchRole(StudafyRole.parent);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/parent',
                  (_) => false,
                );
              },
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFEAFBFD),
                    child: Icon(Icons.swap_horiz_rounded, color: _navy),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Switch to Parent',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Use your linked parent role without signing out',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FeatureCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionsPage()),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFE7F9FC),
                    child: Icon(Icons.family_restroom, color: _navy),
                  ),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Family connections',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Connect to a child using their unique Studafy ID',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _muted),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('TEACHING'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.menu_book_outlined,
                    'Subjects',
                    'Biology, Chemistry',
                  ),
                  const Divider(),
                  _linkSetting(Icons.groups_outlined, 'Classes', '4 assigned'),
                  const Divider(),
                  _linkSetting(
                    Icons.school_outlined,
                    'Homeroom',
                    'Grade 10 · Section B',
                  ),
                  const Divider(),
                  _linkSetting(Icons.badge_outlined, 'Staff ID', 'ALN-T-0219'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'NOTIFICATIONS',
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _setting('Do Not Disturb', 'do_not_disturb', p),
                  const Divider(),
                  _setting('New submissions', 'submissions', p),
                  const Divider(),
                  _setting('Gradebook decisions', 'gradebook', p),
                  const Divider(),
                  _setting('Messages', 'messages', p),
                  const Divider(),
                  _setting(
                    'Daily attendance reminder',
                    'attendance_reminder',
                    p,
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Weekly teaching summary'),
                    subtitle: const Text('Delivered every Sunday morning'),
                    value: weeklyDigest,
                    onChanged: (v) => setState(() => weeklyDigest = v),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lesson reminders'),
                    subtitle: const Text('15 minutes before each class'),
                    value: lessonReminders,
                    onChanged: (v) => setState(() => lessonReminders = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('PREFERENCES'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.language_rounded,
                    'Language',
                    language,
                    onTap: _chooseLanguage,
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.schedule_rounded,
                    'School week',
                    'Sunday – Thursday',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.accessibility_new_rounded,
                    'Accessibility',
                    'Text size & contrast',
                    onTap: () => _openInfo(
                      'Accessibility',
                      'Use your device text size, increase contrast, reduce motion, and enable screen-reader labels throughout Studafy.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.view_compact_outlined,
                      color: _navy,
                    ),
                    title: const Text('Compact class lists'),
                    value: compactMode,
                    onChanged: (v) => setState(() => compactMode = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('SECURITY & DATA'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.password_rounded,
                    'Password & sign-in',
                    'Managed by your school',
                    onTap: () => _openInfo(
                      'Password & sign-in',
                      'Your school identity provider manages your password. Contact school IT to change it or recover access.',
                    ),
                  ),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.fingerprint_rounded,
                      color: _navy,
                    ),
                    title: const Text('Require Face ID'),
                    subtitle: const Text('When reopening Studafy'),
                    value: biometricLock,
                    onChanged: (v) => setState(() => biometricLock = v),
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.devices_rounded,
                    'Signed-in devices',
                    '1 active',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.download_rounded,
                    'Download my data',
                    'Request an archive',
                    onTap: () => _openInfo(
                      'Download my data',
                      'We will prepare a secure archive of your profile, classes, content, and activity. A download link will be sent to your verified email.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('SUPPORT & LEGAL'),
            const SizedBox(height: 8),
            FeatureCard(
              child: Column(
                children: [
                  _linkSetting(
                    Icons.help_outline_rounded,
                    'Help centre',
                    'Guides and contact support',
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.policy_outlined,
                    'Policies',
                    'Privacy, terms & school data',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PoliciesPage()),
                    ),
                  ),
                  const Divider(),
                  _linkSetting(
                    Icons.info_outline_rounded,
                    'About Studafy',
                    'Version 1.0.0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SettingsLabel('ACCOUNT'),
            const SizedBox(height: 8),
            FeatureCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: _coral),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: _coral, fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                ),
                onTap: () async {
                  await SessionService.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/roles',
                      (_) => false,
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA5A3B5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeleteAccountPage(email: '${p['email']}'),
                  ),
                ),
                child: const Text(
                  'Delete account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFA5A3B5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    ),
  );
  Widget _setting(String label, String key, Map<String, Object?> p) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: p[key] == 1,
        onChanged: (v) async {
          await StudafyDatabase.instance.updateProfile({key: v ? 1 : 0});
          setState(() {});
        },
      );

  Widget _linkSetting(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navy),
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 165),
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: _muted),
      ],
    ),
    onTap:
        onTap ??
        () => _openInfo(
          label,
          '$value\n\nThis information is managed by your school office.',
        ),
  );

  Future<void> _chooseLanguage() async {
    await showStudafyLanguagePicker(context);
    if (mounted) {
      setState(
        () => language =
            StudafyLocaleController.instance.locale.languageCode == 'ar'
            ? 'العربية'
            : 'English',
      );
    }
  }

  Future<void> _openInfo(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
  Future<void> _edit(BuildContext context, Map<String, Object?> p) async {
    final name = TextEditingController(text: '${p['name']}'),
        email = TextEditingController(text: '${p['email']}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StudafyDatabase.instance.updateProfile({
                'name': name.text.trim(),
                'email': email.text.trim(),
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) setState(() {});
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  );
}
