import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/inline_photo.dart';
import '../../../core/material_selection.dart';

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

  /// A quarter or less left - the bar's "Running low": the student is told
  /// before it runs out.
  bool get low => remaining > 0 && used >= total * 0.75;

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

  /// The AI study tools are off for this account: the student declined the
  /// AI notice, a parent has not agreed for a child account, or the account
  /// is not a student in a class (ADR-0043).
  static const consentRequired = 'AI_CONSENT_REQUIRED';
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

/// A whole lesson; its own text alone; one file or link on it; or one of
/// the student's notes (ADR-0039).
enum ChatReferenceKind { lesson, text, file, link, note }

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
    this.lessonTitle,
    this.classLabel,
  });

  final ChatReferenceKind kind;
  final String id;
  final String title;

  /// The lesson a file or link belongs to.
  final String? lessonId;

  /// Its lesson's title and class, to say what the chat answers from.
  final String? lessonTitle;
  final String? classLabel;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'lessonId': ?lessonId,
    'lessonTitle': ?lessonTitle,
    'classLabel': ?classLabel,
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
    final lessonTitle = json['lessonTitle'];
    final classLabel = json['classLabel'];
    return ChatReference(
      kind: kind,
      id: id,
      title: title,
      lessonId: lesson is String ? lesson : null,
      lessonTitle: lessonTitle is String ? lessonTitle : null,
      classLabel: classLabel is String ? classLabel : null,
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
    this.photoThumb,
    this.citations = const [],
    this.unreadable = const [],
  });

  final ChatRole role;
  final String text;
  final DateTime at;

  /// A photo sent with this question - its name only; the photo itself stays
  /// in the upload pipeline.
  final String? photoName;

  /// A small copy of that photo, kept on the device with the chat, so the
  /// chat shows the photo itself.
  final Uint8List? photoThumb;

  ChatTurn withPhotoThumb(Uint8List thumb) => ChatTurn(
    role: role,
    text: text,
    at: at,
    photoName: photoName,
    photoThumb: thumb,
    citations: citations,
    unreadable: unreadable,
  );

  /// An answer's sources, and what it could not read.
  final List<AnswerCitation> citations;
  final List<UnreadableSource> unreadable;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    'at': at.toUtc().toIso8601String(),
    'photoName': ?photoName,
    if (photoThumb case final thumb?) 'photoThumb': base64Encode(thumb),
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
      photoThumb: switch (json['photoThumb']) {
        final String encoded => () {
          try {
            return base64Decode(encoded);
          } on FormatException {
            return null;
          }
        }(),
        _ => null,
      },
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
    this.marks = const [],
  });

  final String id;

  /// The first question, shortened - what the chat is about.
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatTurn> turns;

  /// The lessons and notes this chat answers from.
  final List<ChatReference> references;

  /// Where in the chat the material it answers from changed, so the
  /// student can see which answers used what.
  final List<ChatContextMark> marks;

  StudyChat withTurns(List<ChatTurn> next) => StudyChat(
    id: id,
    title: title,
    createdAt: createdAt,
    updatedAt: next.isEmpty ? updatedAt : next.last.at,
    turns: next,
    references: references,
    marks: marks,
  );

  /// [next] from now on; marked in the chat when it already has turns.
  StudyChat withReferences(List<ChatReference> next, {ChatContextMark? mark}) =>
      StudyChat(
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        turns: turns,
        references: next,
        marks: [...marks, ?mark],
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'turns': [for (final turn in turns) turn.toJson()],
    'references': [for (final reference in references) reference.toJson()],
    'marks': [for (final mark in marks) mark.toJson()],
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
      marks: [
        for (final item in json['marks'] as List<dynamic>? ?? const [])
          ?ChatContextMark.fromJson(item),
      ],
    );
  }
}

/// The material a chat answers from changed here: [label] says to what,
/// empty for none.
@immutable
class ChatContextMark {
  const ChatContextMark({required this.at, required this.label});

  final DateTime at;
  final String label;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'label': label,
  };

  static ChatContextMark? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse('${json['at']}');
    final label = json['label'];
    if (at == null || label is! String) return null;
    return ChatContextMark(at: at.toLocal(), label: label);
  }
}

/// The chat's references as a selection, for the picker and the line that
/// says what the chat answers from.
MaterialSelection selectionOfReferences(List<ChatReference> references) {
  final lessons = <String, LessonSelection>{};
  final notes = <NoteSelection>[];
  for (final r in references) {
    if (r.kind == ChatReferenceKind.note) {
      notes.add(
        NoteSelection(id: r.id, title: r.title, classLabel: r.classLabel ?? ''),
      );
      continue;
    }
    final lessonId =
        r.kind == ChatReferenceKind.lesson || r.kind == ChatReferenceKind.text
        ? r.id
        : r.lessonId;
    if (lessonId == null) continue;
    final current =
        lessons[lessonId] ??
        LessonSelection(
          lessonId: lessonId,
          title:
              r.kind == ChatReferenceKind.lesson ||
                  r.kind == ChatReferenceKind.text
              ? r.title
              : r.lessonTitle ?? '',
          classroomId: '',
          classLabel: r.classLabel ?? '',
          includeText: false,
          sourceIds: const {},
        );
    lessons[lessonId] = switch (r.kind) {
      ChatReferenceKind.lesson => current.copyWith(
        includeText: true,
        wholeLesson: true,
      ),
      ChatReferenceKind.text => current.copyWith(includeText: true),
      _ => LessonSelection(
        lessonId: current.lessonId,
        title: current.title,
        classroomId: current.classroomId,
        classLabel: current.classLabel,
        includeText: current.includeText,
        sourceIds: {...current.sourceIds, r.id},
        sourceNames: {...current.sourceNames, r.id: r.title},
        wholeLesson: current.wholeLesson,
      ),
    };
  }
  return MaterialSelection(lessons: lessons.values.toList(), notes: notes);
}

/// A selection as the chat keeps it.
List<ChatReference> referencesOfSelection(MaterialSelection selection) => [
  for (final lesson in selection.lessons)
    if (lesson.wholeLesson)
      ChatReference(
        kind: ChatReferenceKind.lesson,
        id: lesson.lessonId,
        title: lesson.title,
        classLabel: lesson.classLabel,
      )
    else ...[
      if (lesson.includeText)
        ChatReference(
          kind: ChatReferenceKind.text,
          id: lesson.lessonId,
          title: lesson.title,
          classLabel: lesson.classLabel,
        ),
      for (final id in lesson.sourceIds)
        ChatReference(
          kind: ChatReferenceKind.file,
          id: id,
          title: lesson.sourceNames[id] ?? '',
          lessonId: lesson.lessonId,
          lessonTitle: lesson.title,
          classLabel: lesson.classLabel,
        ),
    ],
  for (final note in selection.notes)
    ChatReference(
      kind: ChatReferenceKind.note,
      id: note.id,
      title: note.title,
      classLabel: note.classLabel,
    ),
];

/// Asks the study assistant a question.
///
/// The question is the request, with at most the last few turns of the same
/// chat for a follow-up. Nothing about the student, their class, their marks
/// or their school is sent, and nothing else is read from the device to build
/// it - the server holds the provider credential and adds the instructions.
abstract class StudyAssistantRepository {
  /// [references] are lessons, files, links and notes to answer from;
  /// [photoFileIds] the student's own scanned uploads of purpose
  /// `assistant_attachment`; [inlinePhotos] are sent with the question by a
  /// student with no school to upload into (ADR-0045). [requestId] is the same for a retry of the same
  /// question, so it is never charged twice; [language] is the app's.
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
    List<InlinePhoto> inlinePhotos = const [],
    String? requestId,
    String? language,
    bool skipUnavailable = false,
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
