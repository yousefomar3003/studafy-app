import 'package:flutter/foundation.dart';

enum DataExportState { pending, ready, failed, expired }

DataExportState dataExportStateFromWire(String value) => switch (value) {
  'ready' => DataExportState.ready,
  'failed' => DataExportState.failed,
  'expired' => DataExportState.expired,
  _ => DataExportState.pending,
};

/// The person's most recent request for a copy of their data (DL-051).
@immutable
class DataExportStatus {
  const DataExportStatus({
    required this.id,
    required this.state,
    required this.requestedAt,
    this.readyAt,
    this.expiresAt,
  });

  final String id;
  final DataExportState state;
  final DateTime requestedAt;
  final DateTime? readyAt;
  final DateTime? expiresAt;
}

/// Right-of-access port: request a copy, check on it, download it.
abstract interface class DataExportRepository {
  /// Null when the person has never asked for an export.
  Future<DataExportStatus?> status();

  /// Asks for an export after a fresh recent-auth challenge. Returns the
  /// pending request if one already exists.
  Future<DataExportStatus> request();

  /// The finished export as a JSON document.
  Future<String> download();
}
