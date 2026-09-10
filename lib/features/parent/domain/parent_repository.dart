/// Transitional parent-feature port.
///
/// The preview adapter still maps the legacy SQLite rows while the individual
/// parent vertical slices move to dedicated typed entities. Presentation code
/// never receives a database/provider object and remote runtimes fail closed.
abstract interface class ParentRepository {
  Future<List<Map<String, Object?>>> linkedChildren();

  Future<Map<String, Object?>?> studentByStudafyId(String studafyId);

  Future<void> linkChild(int studentId);

  Future<int> createAndLinkChild({required String name, required String email});

  Future<int> unreadNotificationCount();

  Future<List<Map<String, Object?>>> classesForStudent(int studentId);

  Future<List<Map<String, Object?>>> workForStudent(int studentId);

  Future<Map<String, num>> insightMetricsForStudent(
    int studentId, {
    DateTime? since,
  });

  Future<List<Map<String, Object?>>> behavioursForStudent(int studentId);

  Future<List<Map<String, Object?>>> chats([String query = '']);

  Future<List<Map<String, Object?>>> parentNotices();

  Future<int> sendMessage(int chatId, String body);

  Future<List<Map<String, Object?>>> messages(int chatId);
}

class ParentFeatureUnavailable implements Exception {
  const ParentFeatureUnavailable();

  @override
  String toString() =>
      'Parent records are unavailable until the server repository is enabled.';
}
