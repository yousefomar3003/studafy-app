part of '../../../teacher_features.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});
  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final id = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Family connections'),
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.connectionRequests(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Connect to a child',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter the child’s unique Studafy ID. They must accept your request before access is granted.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: id,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Child Studafy ID',
                hintText: 'STU-0001',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _send,
              child: const Text('Send connection request'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final scanned = await scanStudentQr(context);
                if (scanned != null) setState(() => id.text = scanned);
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan student QR'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Requests',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: FeatureCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: _navy,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['student_name']}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${row['studafy_id']}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge('${row['status']}'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> _send() async {
    try {
      await StudafyDatabase.instance.requestConnection(
        'ST-2H9X-46B',
        id.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connection request sent. Waiting for the child to accept.',
            ),
          ),
        );
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found with that Studafy ID.'),
          ),
        );
      }
    }
  }
}
