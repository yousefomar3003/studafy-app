import 'package:flutter/foundation.dart';

/// A student's AI allowance, in tokens (ADR-0037): one allowance for the
/// helper and every other AI study tool. Free resets weekly, the paid plans
/// monthly.
@immutable
class HelperAllowance {
  const HelperAllowance({
    required this.weekly,
    required this.total,
    required this.used,
    required this.remaining,
    required this.resetsAt,
  });

  final bool weekly;
  final int total;
  final int used;
  final int remaining;
  final DateTime resetsAt;

  double get usedFraction =>
      total <= 0 ? 1 : (used / total).clamp(0, 1).toDouble();

  /// Under a fifth left: the student is told before it runs out.
  bool get low => remaining > 0 && remaining < total * 0.2;

  /// Nothing left to ask with.
  bool get exhausted => remaining <= 0;

  static HelperAllowance? fromJson(Object? json) {
    if (json is! Map) return null;
    final total = json['total'];
    final used = json['used'];
    final remaining = json['remaining'];
    final resets = DateTime.tryParse('${json['resetsAt']}');
    if (total is! int || used is! int || remaining is! int || resets == null) {
      return null;
    }
    return HelperAllowance(
      weekly: json['period'] == 'week',
      total: total,
      used: used,
      remaining: remaining,
      resetsAt: resets.toLocal(),
    );
  }
}

/// Where a fact in an answer came from: [n] in the answer.
@immutable
class AnswerCitation {
  const AnswerCitation({
    required this.n,
    required this.kind,
    required this.name,
    this.lessonTitle,
    this.page,
    this.slide,
  });

  final int n;

  /// 'lesson', 'file', 'link' or 'note'.
  final String kind;
  final String name;
  final String? lessonTitle;
  final int? page;
  final int? slide;

  Map<String, Object?> toJson() => {
    'n': n,
    'sourceKind': kind,
    'name': name,
    'lessonTitle': ?lessonTitle,
    'page': ?page,
    'slide': ?slide,
  };

  static AnswerCitation? fromJson(Object? json) {
    if (json is! Map) return null;
    final n = json['n'];
    final name = json['name'];
    if (n is! int || name is! String) return null;
    return AnswerCitation(
      n: n,
      kind: '${json['sourceKind'] ?? 'file'}',
      name: name,
      lessonTitle: json['lessonTitle'] as String?,
      page: json['page'] as int?,
      slide: json['slide'] as int?,
    );
  }
}

/// A source the student chose that could not be read, and the code for why.
@immutable
class UnreadableSource {
  const UnreadableSource({required this.name, required this.reason});

  final String name;
  final String reason;

  Map<String, Object?> toJson() => {'name': name, 'reason': reason};

  static UnreadableSource? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final reason = json['reason'];
    if (name is! String || reason is! String) return null;
    return UnreadableSource(name: name, reason: reason);
  }
}

/// One exchange with the study assistant.
class StudyAnswer {
  const StudyAnswer({
    required this.answer,
    this.citations = const [],
    this.unreadable = const [],
    this.allowance,
  });

  final String answer;
  final List<AnswerCitation> citations;
  final List<UnreadableSource> unreadable;

  /// What is left after this answer. Null when it came from the device.
  final HelperAllowance? allowance;
}

/// Failure codes the helper's screen explains in the reader's own language,
/// instead of the generic "record no longer exists" or "check your
/// connection" that a 404 or 429 would otherwise become.
abstract final class StudyAssistantFailure {
  /// Not enough tokens left in the allowance for this question.
  static const allowanceUsed = 'AI_ALLOWANCE_USED';

  /// The same question is still being answered.
  static const inProgress = 'AI_REQUEST_IN_PROGRESS';

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

enum ChatReferenceKind { lesson, file, link, note }

/// A lesson, one file or link on a lesson, or one of the student's notes the
/// helper answers from. Only which one travels; the server reads the
/// material itself, and only what this student may read.
@immutable
class ChatReference {
  const ChatReference({
    required this.kind,
    required this.id,
    required this.title,
    this.lessonId,
  });

  final ChatReferenceKind kind;
  final String id;
  final String title;

  /// The lesson a file or link belongs to.
  final String? lessonId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'lessonId': ?lessonId,
  };

  static ChatReference? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = ChatReferenceKind.values
        .where((value) => value.name == json['kind'])
        .firstOrNull;
    final id = json['id'];
    final title = json['title'];
    if (kind == null || id is! String || title is! String) return null;
    final lesson = json['lessonId'];
    return ChatReference(
      kind: kind,
      id: id,
      title: title,
      lessonId: lesson is String ? lesson : null,
    );
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
    this.citations = const [],
    this.unreadable = const [],
  });

  final ChatRole role;
  final String text;
  final DateTime at;

  /// A photo sent with this question - its name only; the photo itself stays
  /// in the upload pipeline.
  final String? photoName;

  /// An answer's sources, and what it could not read.
  final List<AnswerCitation> citations;
  final List<UnreadableSource> unreadable;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    'at': at.toUtc().toIso8601String(),
    'photoName': ?photoName,
    if (citations.isNotEmpty)
      'citations': [for (final c in citations) c.toJson()],
    if (unreadable.isNotEmpty)
      'unreadable': [for (final u in unreadable) u.toJson()],
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
      citations: [
        for (final item in json['citations'] as List<dynamic>? ?? const [])
          ?AnswerCitation.fromJson(item),
      ],
      unreadable: [
        for (final item in json['unreadable'] as List<dynamic>? ?? const [])
          ?UnreadableSource.fromJson(item),
      ],
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
  /// [references] are lessons, files, links and notes to answer from;
  /// [photoFileIds] the student's own scanned uploads of purpose
  /// `assistant_attachment`. [requestId] is the same for a retry of the same
  /// question, so it is never charged twice; [language] is the app's.
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
    String? requestId,
    String? language,
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
