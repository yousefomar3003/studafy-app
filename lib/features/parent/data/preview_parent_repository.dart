import '../../../studafy_database.dart';
import '../domain/parent_repository.dart';

/// Synthetic-preview adapter. SQLite stays behind this data-layer boundary.
final class PreviewParentRepository implements ParentRepository {
  const PreviewParentRepository();

  @override
  Future<List<Map<String, Object?>>> linkedChildren() =>
      StudafyDatabase.instance.linkedChildren();

  @override
  Future<Map<String, Object?>?> studentByStudafyId(String studafyId) =>
      StudafyDatabase.instance.studentByStudafyId(studafyId);

  @override
  Future<void> linkChild(int studentId) =>
      StudafyDatabase.instance.linkChild(studentId);

  @override
  Future<int> createAndLinkChild({
    required String name,
    required String email,
  }) => StudafyDatabase.instance.createAndLinkChild(name: name, email: email);

  @override
  Future<int> unreadNotificationCount() =>
      StudafyDatabase.instance.unreadNotificationCount();

  @override
  Future<List<Map<String, Object?>>> classesForStudent(int studentId) =>
      StudafyDatabase.instance.classesForStudent(studentId);

  @override
  Future<List<Map<String, Object?>>> workForStudent(int studentId) =>
      StudafyDatabase.instance.workForStudent(studentId);

  @override
  Future<Map<String, num>> insightMetricsForStudent(
    int studentId, {
    DateTime? since,
  }) => StudafyDatabase.instance.insightMetricsForStudent(
    studentId,
    since: since,
  );

  @override
  Future<List<Map<String, Object?>>> behavioursForStudent(int studentId) =>
      StudafyDatabase.instance.behavioursForStudent(studentId);

  @override
  Future<List<Map<String, Object?>>> chats([String query = '']) =>
      StudafyDatabase.instance.chats(query);

  @override
  Future<List<Map<String, Object?>>> parentNotices() =>
      StudafyDatabase.instance.parentNotices();

  @override
  Future<int> sendMessage(int chatId, String body) =>
      StudafyDatabase.instance.sendMessage(chatId, body);

  @override
  Future<List<Map<String, Object?>>> messages(int chatId) =>
      StudafyDatabase.instance.messages(chatId);
}
