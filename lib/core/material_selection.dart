import 'package:flutter/widgets.dart';

import '../l10n/generated/app_l10n.dart';
import 'failures.dart';

/// Exactly the class material an AI feature uses (2026-10-07, ADR-0039).
///
/// Chosen in one picker for summaries, quizzes, flashcards, notebooks and
/// the study helper: lessons, and within each lesson its own text and the
/// files and links to use. Only ids leave the device; the server checks
/// each one and reads nothing else.

/// What the material is chosen for: it names the picker's action.
enum MaterialAction { summary, quiz, flashcards, notebook, helper }

/// A file or link on a lesson, and whether it can be read.
@immutable
class MaterialSource {
  const MaterialSource({
    required this.id,
    required this.isLink,
    required this.name,
    required this.state,
    this.reason,
  });

  final String id;
  final bool isLink;
  final String name;

  /// 'ready', 'processing', 'unsupported' or 'failed'.
  final String state;
  final String? reason;

  bool get ready => state == 'ready';
  bool get processing => state == 'processing';

  /// Can never be read as it is: a teacher has to change it.
  bool get unusable => !ready && !processing;
}

/// One lesson in a selection, and what of it is used.
@immutable
class LessonSelection {
  const LessonSelection({
    required this.lessonId,
    required this.title,
    required this.classroomId,
    required this.classLabel,
    required this.includeText,
    required this.sourceIds,
    this.sourceNames = const {},
    this.wholeLesson = false,
    this.totalSources = 0,
  });

  final String lessonId;
  final String title;
  final String classroomId;

  /// "Biology · 8A": the class, as the student knows it.
  final String classLabel;

  /// The lesson's own text is used.
  final bool includeText;

  /// The files and links used.
  final Set<String> sourceIds;
  final Map<String, String> sourceNames;

  /// All of it: its text and every file and link. Sent as the lesson
  /// itself, so the server reads exactly what it has.
  final bool wholeLesson;

  /// How many files and links the lesson has, when known.
  final int totalSources;

  bool get isEmpty => !includeText && sourceIds.isEmpty && !wholeLesson;

  LessonSelection copyWith({
    bool? includeText,
    Set<String>? sourceIds,
    bool? wholeLesson,
  }) => LessonSelection(
    lessonId: lessonId,
    title: title,
    classroomId: classroomId,
    classLabel: classLabel,
    includeText: includeText ?? this.includeText,
    sourceIds: sourceIds ?? this.sourceIds,
    sourceNames: sourceNames,
    wholeLesson: wholeLesson ?? this.wholeLesson,
    totalSources: totalSources,
  );
}

/// One of the student's own notebook notes, for the helper.
@immutable
class NoteSelection {
  const NoteSelection({
    required this.id,
    required this.title,
    required this.classLabel,
  });

  final String id;
  final String title;
  final String classLabel;
}

/// A reference as sent to the server.
@immutable
class MaterialRefData {
  const MaterialRefData(this.kind, this.id, {this.lessonId, this.title = ''});

  /// 'lesson', 'text', 'file', 'link' or 'note'.
  final String kind;
  final String id;
  final String? lessonId;
  final String title;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'lessonId': ?lessonId,
  };
}

@immutable
class MaterialSelection {
  const MaterialSelection({this.lessons = const [], this.notes = const []});

  static const empty = MaterialSelection();

  final List<LessonSelection> lessons;
  final List<NoteSelection> notes;

  bool get isEmpty =>
      lessons.every((lesson) => lesson.isEmpty) && notes.isEmpty;

  int get attachmentCount =>
      lessons.fold(0, (n, lesson) => n + lesson.sourceIds.length);

  LessonSelection? lesson(String id) {
    for (final lesson in lessons) {
      if (lesson.lessonId == id) return lesson;
    }
    return null;
  }

  /// Exactly what is chosen, as references for the server.
  List<MaterialRefData> toRefs() => [
    for (final lesson in lessons)
      if (lesson.wholeLesson)
        MaterialRefData('lesson', lesson.lessonId, title: lesson.title)
      else ...[
        if (lesson.includeText)
          MaterialRefData('text', lesson.lessonId, title: lesson.title),
        for (final id in lesson.sourceIds)
          MaterialRefData(
            'file',
            id,
            lessonId: lesson.lessonId,
            title: lesson.sourceNames[id] ?? '',
          ),
      ],
    for (final note in notes)
      MaterialRefData('note', note.id, title: note.title),
  ];

  List<Map<String, Object?>> toJson() => [
    for (final ref in toRefs()) ref.toJson(),
  ];

  /// The name of a chosen file or link, by id.
  String? sourceName(String id) {
    for (final lesson in lessons) {
      if (lesson.sourceNames[id] case final name?) return name;
    }
    return null;
  }
}

/// The selection in one line: "Biology · 8A · Lesson: Cells · 2
/// attachments", or "Biology · 8A · 3 lessons · 5 attachments".
String materialSummary(AppL10n l10n, MaterialSelection selection) {
  final lessons = [
    for (final lesson in selection.lessons)
      if (!lesson.isEmpty) lesson,
  ];
  if (lessons.isEmpty && selection.notes.isEmpty) return l10n.pickNothing;
  final classes = {
    for (final lesson in lessons)
      if (lesson.classLabel.isNotEmpty) lesson.classLabel,
    for (final note in selection.notes)
      if (note.classLabel.isNotEmpty) note.classLabel,
  };
  final parts = <String>[
    if (classes.length == 1)
      classes.first
    else if (classes.length > 1)
      l10n.pickClasses(classes.length),
    if (lessons.length == 1)
      l10n.pickLessonNamed(lessons.single.title)
    else if (lessons.length > 1)
      l10n.pickLessons(lessons.length),
    if (lessons.any((l) => l.wholeLesson))
      lessons.every((l) => l.wholeLesson)
          ? l10n.pickAllAttachments
          : l10n.pickAttachments(selection.attachmentCount)
    else if (selection.attachmentCount > 0)
      l10n.pickAttachments(selection.attachmentCount)
    else if (lessons.isNotEmpty)
      l10n.pickTextOnly,
    if (selection.notes.isNotEmpty) l10n.pickNotes(selection.notes.length),
  ];
  return parts.join(' · ');
}

/// What a picker is asked for.
@immutable
class MaterialPickRequest {
  const MaterialPickRequest({
    required this.action,
    this.initial = MaterialSelection.empty,
    this.preselectLessonId,
    this.onlyClassroomId,
    this.singleLesson = false,
    this.allowNotes = false,
  });

  final MaterialAction action;

  /// What is chosen already.
  final MaterialSelection initial;

  /// Opened from a lesson: it starts chosen, whole, and open to show what
  /// that includes.
  final String? preselectLessonId;

  /// Only this class's lessons: notes are filed in its notebook.
  final String? onlyClassroomId;

  /// One lesson at most: a notebook is made from one lesson.
  final bool singleLesson;

  /// The student's own notes may be chosen too: the helper.
  final bool allowNotes;
}

/// Opens the material picker; null when the student backs out.
typedef MaterialPicker = Future<MaterialSelection?> Function(
  BuildContext context,
  MaterialPickRequest request,
);

/// Chosen files and links that cannot be used now, by id, from a refusal.
class MaterialUnavailableException extends Failure implements Exception {
  const MaterialUnavailableException(this.sources)
    : super(failureCode, 'Some chosen files cannot be used right now.');

  static const failureCode = 'MATERIAL_UNAVAILABLE';

  /// Source id -> why ('processing', or a reading reason code).
  final Map<String, String> sources;

  @override
  String toString() => 'MaterialUnavailableException($sources)';
}

/// What a result was actually made from, as the server reports it.
@immutable
class MaterialScopeInfo {
  const MaterialScopeInfo({this.lessons = const [], this.skipped = const []});

  factory MaterialScopeInfo.fromJson(Map<String, dynamic> json) =>
      MaterialScopeInfo(
        lessons: [
          for (final lesson in (json['lessons'] as List<dynamic>? ?? const []))
            (
              title: (lesson as Map<String, dynamic>)['title'] as String,
              includeText: lesson['includeText'] as bool? ?? false,
              wholeLesson: lesson['wholeLesson'] as bool? ?? false,
              sources: [
                for (final source
                    in (lesson['sources'] as List<dynamic>? ?? const []))
                  (source as Map<String, dynamic>)['name'] as String,
              ],
            ),
        ],
        skipped: [
          for (final item in (json['skipped'] as List<dynamic>? ?? const []))
            (item as Map<String, dynamic>)['name'] as String,
        ],
      );

  final List<
    ({String title, bool includeText, bool wholeLesson, List<String> sources})
  >
  lessons;
  final List<String> skipped;
}

/// "Cells (lesson text, Leaf.pdf) · Respiration (whole lesson)".
String scopeLine(AppL10n l10n, MaterialScopeInfo scope) => scope.lessons
    .map((lesson) {
      final parts = lesson.wholeLesson
          ? [l10n.pickWholeLesson]
          : [if (lesson.includeText) l10n.pickLessonText, ...lesson.sources];
      return '${lesson.title} (${parts.join(', ')})';
    })
    .join(' · ');
