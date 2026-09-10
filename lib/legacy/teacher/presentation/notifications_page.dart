part of '../../../teacher_features.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _canvasColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: () async {
            await StudafyDatabase.instance.markNotificationsRead();
            setState(() {});
          },
          child: const Text('Mark all read'),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: StudafyDatabase.instance.notifications(),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final row in snapshot.data ?? <Map<String, Object?>>[])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FeatureCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _notificationIcon('${row['kind']}'),
                        color: _navy,
                      ),
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
                                  '${row['title']}',
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (row['is_read'] == 0)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF20C6E8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${row['body']}',
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
  IconData _notificationIcon(String kind) => switch (kind) {
    'submission' => Icons.upload_rounded,
    'gradebook' => Icons.check_rounded,
    'attendance' => Icons.priority_high_rounded,
    'incident' => Icons.flag_rounded,
    _ => Icons.calendar_month_outlined,
  };
}
