import 'package:flutter/foundation.dart';

/// One exchange with the study assistant.
class StudyAnswer {
  const StudyAnswer({required this.answer, required this.remainingToday});

  final String answer;

  /// Questions left in today's allowance, so the app can warn before the
  /// student hits the limit rather than after.
  final int remainingToday;
}

/// Failure codes the helper's screen explains in the reader's own language,
/// instead of the generic "record no longer exists" or "check your
/// connection" that a 404 or 429 would otherwise become.
abstract final class StudyAssistantFailure {
  /// Today's free questions are used.
  static const dailyLimit = 'AI_DAILY_LIMIT';

  /// No AI provider behind this server, or it did not answer.
  static const unavailable = 'AI_UNAVAILABLE';

  /// A photo is still being checked; asking again shortly will work.
  static const photoNotReady = 'PHOTO_NOT_READY';

  /// Photos are Studafy Plus.
  static const planRequired = 'PLAN_REQUIRED';
}

/// What this student may give the helper, beyond a question.
@immutable
class HelperAbilities {
  const HelperAbilities({
    this.ask = true,
    this.classMaterial = false,
    this.photos = false,
  });

  /// There is an AI provider behind the helper at all.
  final bool ask;

  /// Lessons and notes can be shared with it (the lesson-tools switch).
  final bool classMaterial;

  /// Photos can be sent (the switch, and Studafy Plus).
  final bool photos;
}

enum ChatReferenceKind { lesson, note }

/// A lesson or one of the student's notes the helper answers from. Only
/// which one travels; the server reads the text itself.
@immutable
class ChatReference {
  const ChatReference({
    required this.kind,
    required this.id,
    required this.title,
  });

  final ChatReferenceKind kind;
  final String id;
  final String title;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
  };

  static ChatReference? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = ChatReferenceKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    final id = json['id'];
    final title = json['title'];
    if (kind == null || id is! String || title is! String) return null;
    return ChatReference(kind: kind, id: id, title: title);
  }

  @override
  bool operator ==(Object other) =>
      other is ChatReference && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

enum ChatRole { student, assistant }

/// One message in a chat with the helper.
@immutable
class ChatTurn {
  const ChatTurn({
    required this.role,
    required this.text,
    required this.at,
    this.photoName,
  });

  final ChatRole role;
  final String text;
  final DateTime at;

  /// A photo sent with this question - its name only; the photo itself stays
  /// in the upload pipeline.
  final String? photoName;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    'at': at.toUtc().toIso8601String(),
    'photoName': ?photoName,
  };

  static ChatTurn? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final role = ChatRole.values
        .where((value) => value.name == json['role'])
        .firstOrNull;
    final text = json['text'];
    final at = DateTime.tryParse('${json['at']}');
    if (role == null || text is! String || at == null) return null;
    final photo = json['photoName'];
    return ChatTurn(
      role: role,
      text: text,
      at: at.toLocal(),
      photoName: photo is String ? photo : null,
    );
  }
}

/// A chat with the helper, kept on the student's device only.
@immutable
class StudyChat {
  const StudyChat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.turns = const [],
    this.references = const [],
  });

  final String id;

  /// The first question, shortened - what the chat is about.
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatTurn> turns;

  /// The lessons and notes this chat answers from.
  final List<ChatReference> references;

  StudyChat withTurns(List<ChatTurn> next) => StudyChat(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: next.isEmpty ? updatedAt : next.last.at,
    turns: next,
    references: references,
  );

  StudyChat withReferences(List<ChatReference> next) => StudyChat(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: updatedAt,
    turns: turns,
    references: next,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'turns': [for (final turn in turns) turn.toJson()],
    'references': [for (final reference in references) reference.toJson()],
  };

  static StudyChat? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final title = json['title'];
    final created = DateTime.tryParse('${json['createdAt']}');
    final updated = DateTime.tryParse('${json['updatedAt']}');
    if (id is! String || title is! String || created == null) return null;
    return StudyChat(
      id: id,
      title: title,
      createdAt: created.toLocal(),
      updatedAt: (updated ?? created).toLocal(),
      turns: [
        for (final item in json['turns'] as List<dynamic>? ?? const [])
          ?ChatTurn.fromJson(item),
      ],
      references: [
        for (final item in json['references'] as List<dynamic>? ?? const [])
          ?ChatReference.fromJson(item),
      ],
    );
  }
}

/// Asks the study assistant a question.
///
/// The question is the request, with at most the last few turns of the same
/// chat for a follow-up. Nothing about the student, their class, their marks
/// or their school is sent, and nothing else is read from the device to build
/// it - the server holds the provider credential and adds the instructions.
abstract class StudyAssistantRepository {
  /// [references] are lessons and notes to answer from; [photoFileIds] the
  /// student's own scanned uploads of purpose `assistant_attachment`.
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  });
}

/// The student's chats with the helper, on this device and for the account
/// signed in. They never leave the device except as a follow-up's context.
abstract interface class StudyChatStore {
  /// Newest first.
  Future<List<StudyChat>> chats();

  Future<void> save(StudyChat chat);

  Future<void> delete(String chatId);

  Future<void> deleteAll();
}
