import '../../../core/failures.dart';
import '../domain/messaging.dart';

/// In-memory messaging for synthetic builds only. It follows the same
/// contact rule the server enforces so the demo never shows a path the real
/// product refuses.
class PreviewMessagingRepository
    implements MessagingRepository, SafetyRepository {
  PreviewMessagingRepository({this.myUserId = 'demo-user'});

  final String myUserId;
  static const _school = 'demo-school';

  final List<MessagingContact> _people = const [
    MessagingContact(
      userId: 'demo-teacher',
      displayName: 'Rana Haddad',
      role: MessagingRole.staff,
    ),
    MessagingContact(
      userId: 'demo-office',
      displayName: 'School office',
      role: MessagingRole.staff,
    ),
  ];
  final List<Conversation> _conversations = [];
  final Map<String, List<ChatMessage>> _messages = {};
  final List<BlockedPerson> _blocks = [];
  int _sequence = 0;

  String _id(String prefix) => '$prefix-${++_sequence}';

  bool _blockedWith(String userId) =>
      _blocks.any((block) => block.involves(userId));

  @override
  Future<bool> messagingEnabled(String schoolId) async => true;

  @override
  Future<List<Conversation>> conversations() async =>
      List.of(_conversations)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) async {
    final items = List.of(_messages[conversationId] ?? const <ChatMessage>[])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return MessagePage(items: items);
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
    List<String> attachmentFileIds = const [],
  }) async {
    final existing = _messages[conversationId]?.where(
      (message) => message.id == clientMessageId,
    );
    if (existing != null && existing.isNotEmpty) return existing.first;
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0) throw Failure.notFound;
    final conversation = _conversations[index];
    if (conversation.others(myUserId).any((p) => _blockedWith(p.userId))) {
      throw const Failure('FORBIDDEN', 'FORBIDDEN');
    }
    final message = ChatMessage(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: myUserId,
      body: body,
      createdAt: DateTime.now(),
    );
    (_messages[conversationId] ??= []).add(message);
    _conversations[index] = Conversation(
      id: conversation.id,
      schoolId: conversation.schoolId,
      subject: conversation.subject,
      participants: conversation.participants,
      updatedAt: message.createdAt,
      lastReadAt: message.createdAt,
    );
    return message;
  }

  @override
  Future<List<MessagingContact>> contacts(String schoolId) async => _people;

  @override
  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) async {
    final chosen = _people.where((p) => participantIds.contains(p.userId));
    if (chosen.length != participantIds.length) {
      throw const Failure('CONTACT_NOT_ALLOWED', 'CONTACT_NOT_ALLOWED');
    }
    final now = DateTime.now();
    final conversation = Conversation(
      id: _id('conversation'),
      schoolId: _school,
      subject: subject,
      updatedAt: now,
      lastReadAt: now,
      participants: [
        ConversationParticipant(
          userId: myUserId,
          displayName: 'You',
          role: MessagingRole.guardian,
        ),
        for (final person in chosen)
          ConversationParticipant(
            userId: person.userId,
            displayName: person.displayName,
            role: person.role,
          ),
      ],
    );
    _conversations.add(conversation);
    return conversation;
  }

  @override
  Future<void> report({
    required String schoolId,
    required ReportTarget target,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  }) async {}

  @override
  Future<BlockedPerson> block({
    required String schoolId,
    required String userId,
  }) async {
    final block = BlockedPerson(
      blockId: _id('block'),
      schoolId: schoolId,
      blockerId: myUserId,
      blockedId: userId,
      createdAt: DateTime.now(),
    );
    _blocks.add(block);
    return block;
  }

  @override
  Future<void> unblock(String blockId) async =>
      _blocks.removeWhere((block) => block.blockId == blockId);

  @override
  Future<List<BlockedPerson>> blocks(String schoolId) async => List.of(_blocks);

  @override
  Future<void> createAnnouncement(AnnouncementDraft draft) async =>
      throw StateError('Announcements need the school service.');

  @override
  Future<List<Announcement>> announcements({String? classroomId}) async =>
      const [];
}
