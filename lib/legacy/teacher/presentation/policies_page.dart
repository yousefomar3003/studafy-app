part of '../../../teacher_features.dart';

class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Policies'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'How Studafy handles your account and school data.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 18),
        FeatureCard(
          child: Column(
            children: [
              _policy(
                context,
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                'What we collect and how it is used',
              ),
              const Divider(),
              _policy(
                context,
                Icons.description_outlined,
                'Terms of Use',
                'Rules for using Studafy',
              ),
              const Divider(),
              _policy(
                context,
                Icons.school_outlined,
                'School data policy',
                'Ownership and retention of education records',
              ),
              const Divider(),
              _policy(
                context,
                Icons.cookie_outlined,
                'Cookie & analytics notice',
                'Diagnostics and product analytics',
              ),
              const Divider(),
              _policy(
                context,
                Icons.child_care_outlined,
                'Child safeguarding',
                'Safety and reporting commitments',
              ),
              const Divider(),
              _policy(
                context,
                Icons.update_rounded,
                'Policy updates',
                'Last updated 2 September 2026',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _policy(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _navy),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _PolicyDetail(title: title)),
    ),
  );
}

class _PolicyDetail extends StatelessWidget {
  const _PolicyDetail({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(backgroundColor: Colors.white, title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Effective 2 September 2026',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your information',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Studafy processes profile, class, attendance, assessment, and communication data to provide and secure the school service. Your school controls official education records.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Your choices',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can request a copy, correction, or deletion of eligible personal data. Some information may remain where the school has a legal, safeguarding, or academic-record obligation.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Questions',
          style: TextStyle(
            fontSize: 17,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Contact your school office or privacy@studafy.app for help with a data request.',
        ),
      ],
    ),
  );
}
