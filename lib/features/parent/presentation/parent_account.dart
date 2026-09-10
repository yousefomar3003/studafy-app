part of '../../../parent_features.dart';

class ParentAccountPage extends StatefulWidget {
  const ParentAccountPage({super.key});
  @override
  State<ParentAccountPage> createState() => _ParentAccountPageState();
}

class _ParentAccountPageState extends State<ParentAccountPage> {
  bool schoolUpdates = true, childAlerts = true, quietHours = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvas,
    appBar: AppBar(title: const Text('Account and settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: _navy,
              child: Text(
                'NH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nadia Hassan',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'nadia.hassan@example.com',
                  style: TextStyle(color: _muted),
                ),
                Chip(
                  label: Text('Parent'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const StudentLinkPage(asParent: true),
            ),
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEAFBFD),
            child: Icon(Icons.add_link_rounded, color: _navy),
          ),
          title: const Text(
            'Link a student',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Enter their ID or scan their QR code'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('School updates'),
                value: schoolUpdates,
                onChanged: (v) => setState(() => schoolUpdates = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Child alerts'),
                subtitle: const Text('Attendance, grades and deadlines'),
                value: childAlerts,
                onChanged: (v) => setState(() => childAlerts = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                title: const Text('Quiet hours'),
                value: quietHours,
                onChanged: (v) => setState(() => quietHours = v),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                onTap: () => showStudafyLanguagePicker(context),
                title: const Text('Language'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      StudafyLocaleController.instance.locale.languageCode ==
                              'ar'
                          ? 'العربية'
                          : 'English',
                      style: const TextStyle(color: _muted),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              const ListTile(
                title: Text('Privacy & data'),
                trailing: Icon(Icons.chevron_right_rounded, color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          onTap: () {
            ActiveContextController.instance.switchRole(StudafyRole.teacher);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/teacher',
              (_) => false,
            );
          },
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEFEDFF),
            child: Icon(Icons.swap_horiz_rounded, color: _navy),
          ),
          title: const Text(
            'Switch to Teacher',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Available when this account has both roles'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () async {
            await ParentRepositoryScope.of(context).signOut();
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
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA5A3B5),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    const DeleteAccountPage(email: 'nadia.hassan@example.com'),
              ),
            ),
            child: const Text(
              'Delete account',
              style: TextStyle(
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
