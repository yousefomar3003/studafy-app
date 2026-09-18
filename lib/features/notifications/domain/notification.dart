import 'package:flutter/foundation.dart';

/// A single notification, already resolved from the server's templated
/// `{templateKey, payload}` shape into display-ready fields (MOB-070). The
/// raw payload map never crosses into presentation — the data adapter is
/// the only place that reads it.
@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.templateKey,
    required this.title,
    required this.detail,
    required this.createdAt,
    this.route,
    this.readAt,
  });

  final String id;
  final String templateKey;
  final String title;
  final String detail;
  final DateTime createdAt;

  /// Deep-link-style destination the notification should open when tapped,
  /// e.g. `assignment:<id>`. Null when the template has no destination.
  final String? route;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationItem copyWith({DateTime? readAt}) => NotificationItem(
    id: id,
    templateKey: templateKey,
    title: title,
    detail: detail,
    createdAt: createdAt,
    route: route,
    readAt: readAt ?? this.readAt,
  );
}

@immutable
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.nextCursor,
    required this.isFromCache,
  });

  final List<NotificationItem> items;
  final String? nextCursor;

  /// True when this page came from the offline cache because the live
  /// request could not be made (airplane mode, timeout, server error).
  /// Presentation uses this to show an honest "offline" state instead of
  /// silently presenting stale data as fresh.
  final bool isFromCache;
}
