import '../../../core/inline_photo.dart';
import '../../../core/material_selection.dart';
import '../domain/study.dart';
import '../domain/study_notebook.dart';

/// Synthetic builds: a free plan and an empty notebook; nothing is paid.
class PreviewStudyRepository implements StudyRepository {
  PreviewStudyRepository();

  final Map<String, List<NotebookEntry>> _notes = {};

  @override
  Future<StudyPlan> plan() async => StudyPlan.free;

  @override
  Future<List<NotebookEntry>> notebook(String classroomId) async =>
      List.of(_notes[classroomId] ?? const []);

  @override
  Future<NotebookEntry> addNote(
    String classroomId, {
    required String title,
    required String body,
  }) async {
    final entry = NotebookEntry(
      id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
      classroomId: classroomId,
      title: title,
      body: body,
      fromWhiteboard: false,
      createdAt: DateTime.now(),
    );
    (_notes[classroomId] ??= []).insert(0, entry);
    return entry;
  }

  @override
  Future<NotebookEntry> whiteboardNote(
    String classroomId,
    String photoFileId,
  ) => throw const StudyException(StudyRefusal.unavailable);

  @override
  Future<void> deleteNote(String entryId) async {
    for (final list in _notes.values) {
      list.removeWhere((e) => e.id == entryId);
    }
    _personal.removeWhere((e) => e.id == entryId);
  }

  /// The personal notebook (ADR-0045), on this device only.
  final List<NotebookEntry> _personal = [];

  @override
  Future<List<NotebookEntry>> personalNotebook() async => List.of(_personal);

  @override
  Future<NotebookEntry> addPersonalNote({
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final entry = NotebookEntry(
      id: 'preview-${now.microsecondsSinceEpoch}',
      classroomId: null,
      title: title,
      body: body,
      fromWhiteboard: false,
      createdAt: now,
      updatedAt: now,
    );
    _personal.insert(0, entry);
    return entry;
  }

  // Notes from a photo are Studafy Plus; a synthetic build is on free.
  @override
  Future<NotebookEntry> photoNote(InlinePhoto photo, {String? title}) =>
      throw const StudyException(StudyRefusal.planRequired);

  @override
  Future<NotebookEntry> editNote(
    String entryId, {
    String? title,
    String? body,
  }) async {
    final lists = [_personal, ..._notes.values];
    for (final list in lists) {
      final at = list.indexWhere((e) => e.id == entryId);
      if (at < 0) continue;
      final edited = list[at].copyWith(
        title: title,
        body: body,
        updatedAt: DateTime.now(),
      );
      list[at] = edited;
      return edited;
    }
    throw const StudyException(StudyRefusal.failed);
  }

  @override
  Future<StudySet> practiseNotes(StudySetKind kind, List<String> entryIds) =>
      throw const StudyException(StudyRefusal.planRequired);

  @override
  Future<StudySet> studySet(String resourceId, StudySetKind kind) =>
      throw const StudyException(StudyRefusal.unavailable);

  @override
  Future<List<NotebookGroup>> myNotebooks() async => [
    for (final entry in _notes.entries)
      if (entry.value.isNotEmpty)
        NotebookGroup(
          classroomId: entry.key,
          className: entry.key,
          classGone: false,
          entries: List.of(entry.value),
        ),
  ];

  @override
  Future<NotebookEntry> lessonNotes(String resourceId) =>
      throw const StudyException(StudyRefusal.planRequired);

  // Study notebooks are written by the AI on Studafy Plus: a synthetic
  // build has none and cannot make one.
  @override
  Future<List<StudyNotebookSummary>> notebooks(String classroomId) async =>
      const [];

  @override
  Future<StudyNotebookSummary> createNotebook(
    String classroomId, {
    required String resourceId,
    required List<String> sourceIds,
    String? title,
    MaterialSelection? selection,
    bool skipUnavailable = false,
  }) => throw const StudyException(StudyRefusal.planRequired);

  @override
  Future<StudyNotebook> openNotebook(String notebookId) =>
      throw const StudyException(StudyRefusal.failed);

  @override
  Future<StudyNotebookSummary> updateNotebook(
    String notebookId, {
    List<String>? sourceIds,
    bool skipUnavailable = false,
  }) => throw const StudyException(StudyRefusal.planRequired);

  @override
  Future<StudyNotebookSummary> saveNotebookSettings(
    String notebookId,
    NotebookSettings settings,
  ) => throw const StudyException(StudyRefusal.failed);

  @override
  Future<StudyNotebook> saveNotebookPersonal(
    String notebookId, {
    required int expectedVersion,
    required NotebookPersonal personal,
  }) => throw const StudyException(StudyRefusal.failed);

  @override
  Future<void> deleteNotebook(String notebookId) async {}

  @override
  Future<StudySet> notebookStudySet(
    String notebookId,
    StudySetKind kind,
    List<String> sectionKeys,
  ) => throw const StudyException(StudyRefusal.unavailable);

  @override
  Future<StudySet> selectionStudySet(
    StudySetKind kind,
    MaterialSelection selection, {
    bool skipUnavailable = false,
  }) => throw const StudyException(StudyRefusal.unavailable);

  @override
  Future<NotebookEntry> summarise(
    String classroomId,
    MaterialSelection selection, {
    bool skipUnavailable = false,
    String? language,
  }) => throw const StudyException(StudyRefusal.planRequired);
}
