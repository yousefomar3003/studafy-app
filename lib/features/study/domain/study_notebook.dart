import 'package:flutter/foundation.dart';

import 'study.dart';

/// A student's study notebook (2026-10-07): made by the AI from one lesson -
/// all of it, or chosen files and links - in a fixed structure, and kept
/// with the student's own notes, highlights, bookmarks and sections, which
/// updating the AI part never touches.

enum NotebookColor { navy, teal, coral, violet, amber, green, rose, slate }

enum NotebookIcon {
  book,
  science,
  math,
  language,
  globe,
  history,
  art,
  music,
  code,
  star,
}

enum NotebookPageStyle { lined, plain, grid }

enum NotebookStatus { creating, ready, failed }

enum HighlightColor { yellow, green, blue, pink }

T _parse<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

List<Map<String, dynamic>> _maps(Object? value) => [
  for (final item in (value as List<dynamic>?) ?? const [])
    item as Map<String, dynamic>,
];

List<String> _strings(Object? value) =>
    ((value as List<dynamic>?) ?? const []).cast<String>();

/// Where a statement came from: a file and page or slide.
@immutable
class NotebookCitation {
  const NotebookCitation({required this.name, this.page, this.slide});

  factory NotebookCitation.fromJson(Map<String, dynamic> json) =>
      NotebookCitation(
        name: json['name'] as String,
        page: json['page'] as int?,
        slide: json['slide'] as int?,
      );

  final String name;
  final int? page;
  final int? slide;
}

@immutable
class NotebookSection {
  const NotebookSection({
    required this.key,
    required this.heading,
    this.paragraphs = const [],
    this.points = const [],
    this.cites = const [],
    this.extra = false,
  });

  factory NotebookSection.fromJson(Map<String, dynamic> json) =>
      NotebookSection(
        key: json['key'] as String,
        heading: json['heading'] as String,
        paragraphs: _strings(json['paragraphs']),
        points: _strings(json['points']),
        cites: [
          for (final c in _maps(json['cites'])) NotebookCitation.fromJson(c),
        ],
        extra: json['extra'] as bool? ?? false,
      );

  final String key;
  final String heading;
  final List<String> paragraphs;
  final List<String> points;
  final List<NotebookCitation> cites;

  /// Explanation beyond what the lesson's material says.
  final bool extra;
}

/// A fact, rule or common mistake.
@immutable
class NotebookItem {
  const NotebookItem({required this.text, this.cite, this.extra = false});

  factory NotebookItem.fromJson(Map<String, dynamic> json) => NotebookItem(
    text: json['text'] as String,
    cite: json['cite'] == null
        ? null
        : NotebookCitation.fromJson(json['cite'] as Map<String, dynamic>),
    extra: json['extra'] as bool? ?? false,
  );

  final String text;
  final NotebookCitation? cite;
  final bool extra;
}

@immutable
class NotebookTerm {
  const NotebookTerm({required this.term, required this.definition, this.cite});

  factory NotebookTerm.fromJson(Map<String, dynamic> json) => NotebookTerm(
    term: json['term'] as String,
    definition: json['definition'] as String,
    cite: json['cite'] == null
        ? null
        : NotebookCitation.fromJson(json['cite'] as Map<String, dynamic>),
  );

  final String term;
  final String definition;
  final NotebookCitation? cite;
}

@immutable
class NotebookExample {
  const NotebookExample({required this.title, required this.steps, this.cite});

  factory NotebookExample.fromJson(Map<String, dynamic> json) =>
      NotebookExample(
        title: json['title'] as String,
        steps: _strings(json['steps']),
        cite: json['cite'] == null
            ? null
            : NotebookCitation.fromJson(json['cite'] as Map<String, dynamic>),
      );

  final String title;
  final List<String> steps;
  final NotebookCitation? cite;
}

/// The keys of the notebook's fixed parts. Sections have their own.
abstract final class NotebookPart {
  static const overview = 'overview';
  static const objectives = 'objectives';
  static const terms = 'terms';
  static const examples = 'examples';
  static const facts = 'facts';
  static const mistakes = 'mistakes';
  static const summary = 'summary';
}

/// What the AI wrote: each part present only when it has content.
@immutable
class NotebookContent {
  const NotebookContent({
    this.overview,
    this.objectives = const [],
    this.keyTerms = const [],
    this.sections = const [],
    this.examples = const [],
    this.facts = const [],
    this.mistakes = const [],
    this.summary = const [],
  });

  factory NotebookContent.fromJson(Map<String, dynamic> json) =>
      NotebookContent(
        overview: json['overview'] as String?,
        objectives: _strings(json['objectives']),
        keyTerms: [
          for (final t in _maps(json['keyTerms'])) NotebookTerm.fromJson(t),
        ],
        sections: [
          for (final s in _maps(json['sections'])) NotebookSection.fromJson(s),
        ],
        examples: [
          for (final e in _maps(json['examples'])) NotebookExample.fromJson(e),
        ],
        facts: [for (final f in _maps(json['facts'])) NotebookItem.fromJson(f)],
        mistakes: [
          for (final m in _maps(json['mistakes'])) NotebookItem.fromJson(m),
        ],
        summary: _strings(json['summary']),
      );

  final String? overview;
  final List<String> objectives;
  final List<NotebookTerm> keyTerms;
  final List<NotebookSection> sections;
  final List<NotebookExample> examples;
  final List<NotebookItem> facts;
  final List<NotebookItem> mistakes;
  final List<String> summary;
}

/// A note the student wrote against a part of the notebook.
@immutable
class NotebookNote {
  const NotebookNote({
    required this.id,
    required this.sectionKey,
    required this.text,
  });

  factory NotebookNote.fromJson(Map<String, dynamic> json) => NotebookNote(
    id: json['id'] as String,
    sectionKey: json['sectionKey'] as String,
    text: json['text'] as String,
  );

  final String id;
  final String sectionKey;
  final String text;

  Map<String, Object?> toJson() => {
    'id': id,
    'sectionKey': sectionKey,
    'text': text,
  };
}

/// A section the student added, in their own order.
@immutable
class NotebookOwnSection {
  const NotebookOwnSection({
    required this.id,
    required this.title,
    required this.body,
  });

  factory NotebookOwnSection.fromJson(Map<String, dynamic> json) =>
      NotebookOwnSection(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
      );

  final String id;
  final String title;
  final String body;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'body': body};
}

/// One paragraph or point of a part, marked in a colour.
@immutable
class NotebookHighlight {
  const NotebookHighlight({
    required this.sectionKey,
    required this.index,
    required this.color,
  });

  factory NotebookHighlight.fromJson(Map<String, dynamic> json) =>
      NotebookHighlight(
        sectionKey: json['sectionKey'] as String,
        index: json['index'] as int,
        color: _parse(
          HighlightColor.values,
          json['color'],
          HighlightColor.yellow,
        ),
      );

  final String sectionKey;
  final int index;
  final HighlightColor color;

  Map<String, Object?> toJson() => {
    'sectionKey': sectionKey,
    'index': index,
    'color': color.name,
  };
}

/// Everything the student made in a notebook.
@immutable
class NotebookPersonal {
  const NotebookPersonal({
    this.notes = const [],
    this.sections = const [],
    this.bookmarks = const [],
    this.highlights = const [],
  });

  factory NotebookPersonal.fromJson(
    Map<String, dynamic> json,
  ) => NotebookPersonal(
    notes: [for (final n in _maps(json['notes'])) NotebookNote.fromJson(n)],
    sections: [
      for (final s in _maps(json['sections'])) NotebookOwnSection.fromJson(s),
    ],
    bookmarks: _strings(json['bookmarks']),
    highlights: [
      for (final h in _maps(json['highlights'])) NotebookHighlight.fromJson(h),
    ],
  );

  final List<NotebookNote> notes;
  final List<NotebookOwnSection> sections;

  /// Keys of the bookmarked parts and sections.
  final List<String> bookmarks;
  final List<NotebookHighlight> highlights;

  NotebookPersonal copyWith({
    List<NotebookNote>? notes,
    List<NotebookOwnSection>? sections,
    List<String>? bookmarks,
    List<NotebookHighlight>? highlights,
  }) => NotebookPersonal(
    notes: notes ?? this.notes,
    sections: sections ?? this.sections,
    bookmarks: bookmarks ?? this.bookmarks,
    highlights: highlights ?? this.highlights,
  );

  List<NotebookNote> notesFor(String key) => [
    for (final note in notes)
      if (note.sectionKey == key) note,
  ];

  HighlightColor? highlightOf(String key, int index) {
    for (final h in highlights) {
      if (h.sectionKey == key && h.index == index) return h.color;
    }
    return null;
  }

  /// [key]'s line [index] in [color], or unmarked when [color] is null.
  NotebookPersonal withHighlight(
    String key,
    int index,
    HighlightColor? color,
  ) => copyWith(
    highlights: [
      for (final h in highlights)
        if (!(h.sectionKey == key && h.index == index)) h,
      if (color != null)
        NotebookHighlight(sectionKey: key, index: index, color: color),
    ],
  );

  NotebookPersonal toggleBookmark(String key) => copyWith(
    bookmarks: bookmarks.contains(key)
        ? [
            for (final b in bookmarks)
              if (b != key) b,
          ]
        : [...bookmarks, key],
  );

  /// This copy laid over [other] - a newer one saved elsewhere - so neither
  /// loses what it added: notes and sections by id, bookmarks together, and
  /// this copy's highlights where both marked the same line.
  NotebookPersonal mergedOver(NotebookPersonal other) {
    final notes = {for (final n in other.notes) n.id: n};
    for (final n in this.notes) {
      notes[n.id] = n;
    }
    final sections = {for (final s in other.sections) s.id: s};
    for (final s in this.sections) {
      sections[s.id] = s;
    }
    // This copy's order first, then sections only the other has.
    final order = [
      for (final s in this.sections) s.id,
      for (final s in other.sections)
        if (!this.sections.any((t) => t.id == s.id)) s.id,
    ];
    var merged = copyWith(
      notes: notes.values.toList(),
      sections: [for (final id in order) sections[id]!],
      bookmarks: {...other.bookmarks, ...bookmarks}.toList(),
      highlights: const [],
    );
    for (final h in [...other.highlights, ...highlights]) {
      merged = merged.withHighlight(h.sectionKey, h.index, h.color);
    }
    return merged;
  }

  Map<String, Object?> toJson() => {
    'notes': [for (final n in notes) n.toJson()],
    'sections': [for (final s in sections) s.toJson()],
    'bookmarks': bookmarks,
    'highlights': [for (final h in highlights) h.toJson()],
  };
}

/// A file or link of the lesson, as a notebook reads it or could.
@immutable
class NotebookSource {
  const NotebookSource({
    required this.id,
    required this.isLink,
    required this.name,
    required this.state,
    this.reason,
    this.chosen = true,
  });

  factory NotebookSource.fromJson(Map<String, dynamic> json) => NotebookSource(
    id: json['id'] as String,
    isLink: json['kind'] == 'link',
    name: json['name'] as String,
    state: json['state'] as String,
    reason: json['reason'] as String?,
    chosen: json['chosen'] as bool? ?? true,
  );

  final String id;
  final bool isLink;
  final String name;

  /// 'processing', 'ready', 'unsupported' or 'failed'.
  final String state;
  final String? reason;

  /// Part of this notebook.
  final bool chosen;

  bool get ready => state == 'ready';
  bool get processing => state == 'processing';
}

/// A file the AI could not read when it wrote the notebook.
@immutable
class NotebookUnreadable {
  const NotebookUnreadable({required this.name, required this.reason});

  factory NotebookUnreadable.fromJson(Map<String, dynamic> json) =>
      NotebookUnreadable(
        name: json['name'] as String,
        reason: json['reason'] as String,
      );

  final String name;
  final String reason;
}

/// A quiz or flashcards made from the notebook.
@immutable
class NotebookSetSummary {
  const NotebookSetSummary({
    required this.id,
    required this.kind,
    required this.sectionKeys,
    required this.count,
    required this.outdated,
  });

  factory NotebookSetSummary.fromJson(Map<String, dynamic> json) =>
      NotebookSetSummary(
        id: json['id'] as String,
        kind: json['kind'] == 'quiz'
            ? StudySetKind.quiz
            : StudySetKind.flashcards,
        sectionKeys: _strings(json['sectionKeys']),
        count: json['count'] as int,
        outdated: json['outdated'] as bool? ?? false,
      );

  final String id;
  final StudySetKind kind;

  /// Empty: made from the whole notebook.
  final List<String> sectionKeys;
  final int count;

  /// The notebook has been updated since.
  final bool outdated;
}

@immutable
class StudyNotebookSummary {
  const StudyNotebookSummary({
    required this.id,
    required this.classroomId,
    required this.resourceId,
    required this.lessonTitle,
    required this.title,
    this.subtitle,
    this.color = NotebookColor.navy,
    this.icon,
    this.pageStyle = NotebookPageStyle.lined,
    this.status = NotebookStatus.ready,
    this.failure,
    this.updateAvailable = false,
    this.contentVersion = 0,
    this.sourceCount = 0,
    required this.updatedAt,
  });

  factory StudyNotebookSummary.fromJson(Map<String, dynamic> json) =>
      StudyNotebookSummary(
        id: json['id'] as String,
        classroomId: json['classroomId'] as String,
        resourceId: json['resourceId'] as String,
        lessonTitle: json['lessonTitle'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        color: _parse(NotebookColor.values, json['color'], NotebookColor.navy),
        icon: json['icon'] == null
            ? null
            : _parse(NotebookIcon.values, json['icon'], NotebookIcon.book),
        pageStyle: _parse(
          NotebookPageStyle.values,
          json['pageStyle'],
          NotebookPageStyle.lined,
        ),
        status: _parse(
          NotebookStatus.values,
          json['status'],
          NotebookStatus.failed,
        ),
        failure: json['failure'] as String?,
        updateAvailable: json['updateAvailable'] as bool? ?? false,
        contentVersion: json['contentVersion'] as int? ?? 0,
        sourceCount: json['sourceCount'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );

  final String id;
  final String classroomId;
  final String resourceId;
  final String lessonTitle;
  final String title;
  final String? subtitle;
  final NotebookColor color;
  final NotebookIcon? icon;
  final NotebookPageStyle pageStyle;
  final NotebookStatus status;

  /// Why the last writing failed: a code the app words.
  final String? failure;

  /// The lesson or its files changed since the AI part was written.
  final bool updateAvailable;

  /// 0 until the AI part has been written once.
  final int contentVersion;

  /// How many of the lesson's files and links it reads; 0 for all.
  final int sourceCount;
  final DateTime updatedAt;

  bool get hasContent => contentVersion > 0;
}

@immutable
class StudyNotebook {
  const StudyNotebook({
    required this.summary,
    required this.className,
    this.content,
    this.unreadable = const [],
    this.headings = const {},
    this.personal = const NotebookPersonal(),
    this.personalVersion = 1,
    this.sources = const [],
    this.sets = const [],
    this.generatedAt,
  });

  factory StudyNotebook.fromJson(Map<String, dynamic> json) => StudyNotebook(
    summary: StudyNotebookSummary.fromJson(
      json['summary'] as Map<String, dynamic>,
    ),
    className: json['className'] as String,
    content: json['content'] == null
        ? null
        : NotebookContent.fromJson(json['content'] as Map<String, dynamic>),
    unreadable: [
      for (final u in _maps(json['unreadable'])) NotebookUnreadable.fromJson(u),
    ],
    headings: {
      for (final h in _maps(json['headings']))
        h['key'] as String: h['title'] as String,
    },
    personal: NotebookPersonal.fromJson(
      json['personal'] as Map<String, dynamic>,
    ),
    personalVersion: json['personalVersion'] as int,
    sources: [
      for (final s in _maps(json['sources'])) NotebookSource.fromJson(s),
    ],
    sets: [for (final s in _maps(json['sets'])) NotebookSetSummary.fromJson(s)],
    generatedAt: json['generatedAt'] == null
        ? null
        : DateTime.parse(json['generatedAt'] as String).toLocal(),
  );

  final StudyNotebookSummary summary;
  final String className;
  final NotebookContent? content;
  final List<NotebookUnreadable> unreadable;

  /// The student's own names for parts and sections, by key.
  final Map<String, String> headings;
  final NotebookPersonal personal;

  /// The version [personal] was read at; a save names it.
  final int personalVersion;
  final List<NotebookSource> sources;
  final List<NotebookSetSummary> sets;
  final DateTime? generatedAt;

  StudyNotebook copyWith({
    StudyNotebookSummary? summary,
    Map<String, String>? headings,
    NotebookPersonal? personal,
    int? personalVersion,
  }) => StudyNotebook(
    summary: summary ?? this.summary,
    className: className,
    content: content,
    unreadable: unreadable,
    headings: headings ?? this.headings,
    personal: personal ?? this.personal,
    personalVersion: personalVersion ?? this.personalVersion,
    sources: sources,
    sets: sets,
    generatedAt: generatedAt,
  );
}

/// How a notebook looks: its cover and pages.
@immutable
class NotebookSettings {
  const NotebookSettings({
    required this.title,
    this.subtitle,
    required this.color,
    this.icon,
    required this.pageStyle,
    this.headings = const {},
  });

  factory NotebookSettings.of(StudyNotebook notebook) => NotebookSettings(
    title: notebook.summary.title,
    subtitle: notebook.summary.subtitle,
    color: notebook.summary.color,
    icon: notebook.summary.icon,
    pageStyle: notebook.summary.pageStyle,
    headings: notebook.headings,
  );

  final String title;
  final String? subtitle;
  final NotebookColor color;
  final NotebookIcon? icon;
  final NotebookPageStyle pageStyle;
  final Map<String, String> headings;

  NotebookSettings copyWith({
    String? title,
    String? subtitle,
    bool clearSubtitle = false,
    NotebookColor? color,
    NotebookIcon? icon,
    NotebookPageStyle? pageStyle,
    Map<String, String>? headings,
  }) => NotebookSettings(
    title: title ?? this.title,
    subtitle: clearSubtitle ? null : subtitle ?? this.subtitle,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    pageStyle: pageStyle ?? this.pageStyle,
    headings: headings ?? this.headings,
  );

  Map<String, Object?> toJson() => {
    'title': title,
    'subtitle': (subtitle?.trim().isEmpty ?? true) ? null : subtitle!.trim(),
    'color': color.name,
    'icon': icon?.name,
    'pageStyle': pageStyle.name,
    'headings': [
      for (final entry in headings.entries)
        if (entry.value.trim().isNotEmpty)
          {'key': entry.key, 'title': entry.value.trim()},
    ],
  };
}

/// A save of the student's own part met a newer copy - made on another
/// device or in another tab. [latest] is that copy.
class NotebookConflict implements Exception {
  const NotebookConflict(this.latest);
  final StudyNotebook? latest;
}

/// A file or link a student can choose to make a notebook from.
@immutable
class NotebookSourceChoice {
  const NotebookSourceChoice({
    required this.id,
    required this.isLink,
    required this.name,
    required this.state,
    this.reason,
  });

  final String id;
  final bool isLink;
  final String name;

  /// 'processing', 'ready', 'unsupported' or 'failed'.
  final String state;
  final String? reason;

  bool get ready => state == 'ready';
  bool get processing => state == 'processing';
}

/// A student's study notebooks.
abstract interface class StudyNotebookRepository {
  Future<List<StudyNotebookSummary>> notebooks(String classroomId);

  /// Starts writing a notebook from [resourceId]'s [sourceIds] - all of the
  /// lesson when empty. Answers at once, with the notebook "creating".
  Future<StudyNotebookSummary> createNotebook(
    String classroomId, {
    required String resourceId,
    required List<String> sourceIds,
    String? title,
  });

  Future<StudyNotebook> openNotebook(String notebookId);

  /// Writes the AI part again from the lesson as it is now; the student's
  /// own part is kept.
  Future<StudyNotebookSummary> updateNotebook(
    String notebookId, {
    List<String>? sourceIds,
  });

  Future<StudyNotebookSummary> saveNotebookSettings(
    String notebookId,
    NotebookSettings settings,
  );

  /// Throws [NotebookConflict] when [expectedVersion] is not the latest.
  Future<StudyNotebook> saveNotebookPersonal(
    String notebookId, {
    required int expectedVersion,
    required NotebookPersonal personal,
  });

  Future<void> deleteNotebook(String notebookId);

  /// A quiz or flashcards from the notebook, or chosen parts of it: made
  /// once for each version of the notebook, then reopened for free.
  Future<StudySet> notebookStudySet(
    String notebookId,
    StudySetKind kind,
    List<String> sectionKeys,
  );
}
