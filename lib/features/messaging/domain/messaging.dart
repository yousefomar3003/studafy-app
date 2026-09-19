import 'package:flutter/foundation.dart';

/// Coarse role of a person in a school conversation. Display-only: the
/// server decides who may contact whom (DL-049 contact policy).
enum MessagingRole { staff, student, guardian }

MessagingRole messagingRoleFromWire(String value) => switch (value) {
  'staff' => MessagingRole.staff,
  'student' => MessagingRole.student,
  _ => MessagingRole.guardian,
};

@immutable
class ConversationParticipant {
  const ConversationParticipant({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final MessagingRole role;
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.schoolId,
    required this.participants,
    required this.updatedAt,
    this.subject,
    this.lastReadAt,
  });

  final String id;
  final String schoolId;
  final String? subject;
  final List<ConversationParticipant> participants;
  final DateTime updatedAt;
  final DateTime? lastReadAt;

  /// Everyone in the conversation except [myUserId].
  List<ConversationParticipant> others(String myUserId) => [
    for (final participant in participants)
      if (participant.userId != myUserId) participant,
  ];

  bool get hasUnread => lastReadAt == null || updatedAt.isAfter(lastReadAt!);

  String? participantName(String userId) {
    for (final participant in participants) {
      if (participant.userId == userId) return participant.displayName;
    }
    return null;
  }
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

/// One page of messages, newest first; [nextCursor] loads older ones.
@immutable
class MessagePage {
  const MessagePage({required this.items, this.nextCursor});

  final List<ChatMessage> items;
  final String? nextCursor;
}

@immutable
class MessagingContact {
  const MessagingContact({
    required this.userId,
    required this.displayName,
    required this.role,
    this.relatedStudentNames = const [],
  });

  final String userId;
  final String displayName;
  final MessagingRole role;

  /// Filled only for a staff viewer looking at a guardian.
  final List<String> relatedStudentNames;
}

/// What a report is about. Maps onto the SAFE-043 report kinds.
enum ReportTarget { message, conversation, user }

/// Reasons offered in the report sheet. The chosen reason leads the report
/// text a moderator reads.
enum ReportReason { harassment, inappropriate, safety, spam, other }

/// A block between two people in a school. The server lists blocks in both
/// directions, because either one stops the pair messaging.
@immutable
class BlockedPerson {
  const BlockedPerson({
    required this.blockId,
    required this.schoolId,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
  });

  final String blockId;
  final String schoolId;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;

  /// Only the person who made a block can see it as theirs and undo it.
  bool madeBy(String userId) => blockerId == userId;

  bool involves(String userId) => blockerId == userId || blockedId == userId;
}

/// The `/v1` conversations and contacts port.
abstract interface class MessagingRepository {
  Future<bool> messagingEnabled(String schoolId);

  Future<List<Conversation>> conversations();

  Future<MessagePage> messages(String conversationId, {String? cursor});

  /// [clientMessageId] makes a retried send land exactly once.
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
  });

  Future<List<MessagingContact>> contacts(String schoolId);

  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  });
}

/// The SAFE-043 reporting and blocking port.
abstract interface class SafetyRepository {
  Future<void> report({
    required String schoolId,
    required ReportTarget target,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  });

  Future<BlockedPerson> block({
    required String schoolId,
    required String userId,
  });

  Future<void> unblock(String blockId);

  Future<List<BlockedPerson>> blocks(String schoolId);
}
