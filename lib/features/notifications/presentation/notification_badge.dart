import 'package:flutter/material.dart';

import 'notifications_page.dart';
import 'notifications_scope.dart';

/// Unread-count badge over a bell icon, backed by the typed notifications
/// interactor (MOB-070) instead of a direct SQLite call. Replaces the fake
/// per-screen count the legacy header used to read straight from the local
/// preview database.
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final interactor = NotificationsScope.of(context);
    return FutureBuilder(
      future: interactor.unreadCount(),
      builder: (context, snapshot) {
        final count =
            snapshot.data?.fold(
              onSuccess: (value) => value,
              onFailure: (_) => 0,
            ) ??
            0;
        return Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          backgroundColor: const Color(0xFFFF5D5D),
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }
}
