import '../domain/parent_repository.dart';

/// Fail-closed adapter used until the authenticated parent API slice exists.
final class UnavailableParentRepository implements ParentRepository {
  const UnavailableParentRepository();

  Never get _unavailable => throw const ParentFeatureUnavailable();

  @override
  Future<List<Map<String, Object?>>> linkedChildren() async => _unavailable;

  @override
  Future<Map<String, Object?>?> studentByStudafyId(String studafyId) async =>
      _unavailable;

  @override
  Future<void> linkChild(int studentId) async => _unavailable;

  @override
  Future<int> createAndLinkChild({
    required String name,
    required String email,
  }) async => _unavailable;

  @override
  Future<int> unreadNotificationCount() async => _unavailable;

  @override
  Future<List<Map<String, Object?>>> classesForStudent(int studentId) async =>
      _unavailable;

  @override
  Future<List<Map<String, Object?>>> workForStudent(int studentId) async =>
      _unavailable;

  @override
  Future<Map<String, num>> insightMetricsForStudent(
    int studentId, {
    DateTime? since,
  }) async => _unavailable;

  @override
  Future<List<Map<String, Object?>>> behavioursForStudent(
    int studentId,
  ) async => _unavailable;

  @override
  Future<List<Map<String, Object?>>> chats([String query = '']) async =>
      _unavailable;

  @override
  Future<List<Map<String, Object?>>> parentNotices() async => _unavailable;

  @override
  Future<int> sendMessage(int chatId, String body) async => _unavailable;

  @override
  Future<List<Map<String, Object?>>> messages(int chatId) async => _unavailable;
}
