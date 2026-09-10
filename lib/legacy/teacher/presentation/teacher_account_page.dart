part of '../../../teacher_features.dart';

class MyStudafyPage extends StatefulWidget {
  const MyStudafyPage({super.key});
  @override
  State<MyStudafyPage> createState() => _MyStudafyPageState();
}

class _MyStudafyPageState extends State<MyStudafyPage> {
  late Future<List<Object>> data;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => data = Future.wait<Object>([
    StudafyDatabase.instance.profile(),
    StudafyDatabase.instance.linkedChildren(),
  ]);
  Future<void> _photo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (file != null) {
      await StudafyDatabase.instance.updateProfile({'photo_path': file.path});
      setState(() {
        _reload();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('My Studafy'),
      actions: [
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Object>>(
      future: data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = snapshot.data![0] as Map<String, Object?>,
            children = snapshot.data![1] as List<Map<String, Object?>>;
        final path = p['photo_path'] as String?;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241D73), Color(0xFF4037A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44241D73),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _photo,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white24,
                              backgroundImage: path != null
                                  ? FileImage(File(path))
                                  : null,
                              child: path == null
                                  ? const Text(
                                      'RH',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: _cyanAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: _navy,
                                ),
                              ),
                            ),
                          ],
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
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${p['email']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'STUDAFY ID',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ST-2H9X-46B',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SWITCH WORKSPACE',
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 9),
            _workspace(
              Icons.school_rounded,
              'Teacher · Al-Noor International',
              'Classes, gradebook and communications',
              true,
              () {},
            ),
            const SizedBox(height: 10),
            _workspace(
              Icons.family_restroom_rounded,
              'Parent · My Family',
              'View linked children without another login',
              false,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentWorkspacePage(children: children),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MY CHILDREN',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConnectionsPage(),
                        ),
                      ).then((_) {
                        setState(() {
                          _reload();
                        });
                      }),
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Connect'),
                ),
              ],
            ),
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FeatureCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentNotebookPage(student: child),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _navy,
                        child: Text(
                          _initials('${child['student_name']}'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${child['student_name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${child['studafy_id']}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge('Linked'),
                      const Icon(Icons.chevron_right, color: _muted),
                    ],
                  ),
                ),
              ),
            if (children.isEmpty)
              const Text(
                'No linked children yet. Use Connect to send a request.',
                style: TextStyle(color: _muted),
              ),
          ],
        );
      },
    ),
  );
  Widget _workspace(
    IconData icon,
    String title,
    String subtitle,
    bool active,
    VoidCallback tap,
  ) => FeatureCard(
    onTap: tap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? const [_navy, Color(0xFF4A41AD)]
                  : const [Color(0xFF20C6E8), Color(0xFF0FA1C0)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (active)
          const StatusBadge('Active')
        else
          const Icon(Icons.arrow_forward_rounded, color: _navy),
      ],
    ),
  );
  String _initials(String value) =>
      value.split(' ').take(2).map((e) => e[0]).join();
}

const _cyanAccent = Color(0xFF20C6E8);
