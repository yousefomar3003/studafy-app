import 'dart:convert';

import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/study.dart';
import '../domain/study_notebook.dart';

class ApiStudyRepository implements StudyRepository {
  const ApiStudyRepository(this._client);

  final V1ApiClient _client;

  /// A per-call key: each of these is a new act, and a retry after a lost
  /// response is the user pressing again.
  static String _key(String what) => newIdempotencyKey('study-$what');

  static StudyRefusal _refusal(Object error) {
    if (error is! V1ApiException) return StudyRefusal.failed;
    return switch (error.code) {
      'PLAN_REQUIRED' => StudyRefusal.planRequired,
      'AI_ALLOWANCE_USED' => StudyRefusal.allowanceUsed,
      'MATERIAL_PROCESSING' => StudyRefusal.materialProcessing,
      'PHOTO_NOT_READY' => StudyRefusal.photoNotReady,
      'PHOTO_UNREADABLE' => StudyRefusal.photoUnreadable,
      'LESSON_HAS_NO_TEXT' => StudyRefusal.lessonHasNoText,
      'AI_FEATURE_DISABLED' => StudyRefusal.unavailable,
      _ => StudyRefusal.failed,
    };
  }

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on StudyException {
      rethrow;
    } on Object catch (error) {
      throw StudyException(_refusal(error));
    }
  }

  static NotebookEntry _entry(V1NotebookEntryDto dto) => NotebookEntry(
    id: dto.id,
    classroomId: dto.classroomId,
    title: dto.title,
    body: dto.body,
    fromWhiteboard: dto.source == 'whiteboard',
    fromLesson: dto.source == 'lesson',
    createdAt: DateTime.parse(dto.createdAt).toLocal(),
    photo: dto.photo == null
        ? null
        : StoredAttachment(
            id: dto.photo!.id,
            displayName: dto.photo!.displayName,
            sizeBytes: dto.photo!.sizeBytes,
            scanState: dto.photo!.scanState,
            mediaType: dto.photo!.mediaType,
          ),
  );

  @override
  Future<StudyPlan> plan() => _guard(() async {
    final dto = await _client.getStudyPlan();
    return StudyPlan(
      tier: StudyPlanTier.parse(dto.plan),
      allowance: AiAllowance(
        weekly: dto.allowance.period == 'week',
        total: dto.allowance.total,
        used: dto.allowance.used,
        remaining: dto.allowance.remaining,
        resetsAt: DateTime.parse(dto.allowance.resetsAt).toLocal(),
      ),
      available: dto.available?.toSet(),
    );
  });

  @override
  Future<List<NotebookGroup>> myNotebooks() => _guard(() async {
    final page = await _client.listMyNotebooks();
    return [
      for (final group in page.classes)
        NotebookGroup(
          classroomId: group['classroomId'] as String,
          className: group['name'] as String,
          classGone: group['archived'] as bool,
          entries: [
            for (final item in group['entries'] as List<dynamic>)
              _entry(V1NotebookEntryDto.fromJson(item as Map<String, dynamic>)),
          ],
        ),
    ];
  });

  @override
  Future<NotebookEntry> lessonNotes(String resourceId) => _guard(() async {
    return _entry(
      await _client.createLessonNotes(
        const V1CreateLessonNotesRequestDto(),
        resourceId: resourceId,
        idempotencyKey: newIdempotencyKey('lesson-notes'),
      ),
    );
  });

  @override
  Future<List<NotebookEntry>> notebook(String classroomId) => _guard(() async {
    final page = await _client.listNotebookEntries(classroomId: classroomId);
    return [for (final item in page.items) _entry(item)];
  });

  @override
  Future<NotebookEntry> addNote(
    String classroomId, {
    required String title,
    required String body,
  }) => _guard(() async {
    return _entry(
      await _client.createNotebookEntry(
        V1CreateNotebookEntryRequestDto(title: title, body: body),
        classroomId: classroomId,
        idempotencyKey: _key('note'),
      ),
    );
  });

  @override
  Future<NotebookEntry> whiteboardNote(
    String classroomId,
    String photoFileId,
  ) => _guard(() async {
    return _entry(
      await _client.createWhiteboardNote(
        V1WhiteboardNoteRequestDto(photoFileId: photoFileId),
        classroomId: classroomId,
        // Keyed on the photo: a retry after a lost response replays the
        // stored notes instead of paying for the same photo twice.
        idempotencyKey: 'study-whiteboard-$photoFileId',
      ),
    );
  });

  @override
  Future<void> deleteNote(String entryId) => _guard(() async {
    await _client.deleteNotebookEntry(
      const V1DeleteNotebookEntryRequestDto(),
      entryId: entryId,
      idempotencyKey: _key('delete'),
    );
  });

  @override
  Future<StudySet> studySet(String resourceId, StudySetKind kind) =>
      _guard(() async {
        final dto = await _client.generateStudySet(
          V1GenerateStudySetRequestDto(kind: kind.name),
          resourceId: resourceId,
          idempotencyKey: _key('set-${kind.name}'),
        );
        return _set(kind, dto.questions, dto.cards);
      });

  static StudySet _set(
    StudySetKind kind,
    List<V1QuizQuestionDto>? questions,
    List<V1FlashcardDto>? cards,
  ) => StudySet(
    kind: kind,
    questions: [
      for (final q in questions ?? const <V1QuizQuestionDto>[])
        QuizQuestion(
          question: q.question,
          options: q.options,
          answerIndex: q.answerIndex,
          explanation: q.explanation,
        ),
    ],
    cards: [
      for (final c in cards ?? const <V1FlashcardDto>[])
        Flashcard(front: c.front, back: c.back),
    ],
  );

  @override
  Future<List<StudyNotebookSummary>> notebooks(String classroomId) =>
      _guard(() async {
        final list = await _client.listStudyNotebooks(classroomId: classroomId);
        return [
          for (final item in list.items)
            StudyNotebookSummary.fromJson(item.toJson().cast()),
        ];
      });

  @override
  Future<StudyNotebookSummary> createNotebook(
    String classroomId, {
    required String resourceId,
    required List<String> sourceIds,
    String? title,
  }) => _guard(() async {
    final dto = await _client.createStudyNotebook(
      V1CreateStudyNotebookRequestDto.fromJson({
        'resourceId': resourceId,
        'sourceIds': sourceIds,
        'title': ?title,
      }),
      classroomId: classroomId,
      idempotencyKey: _key('notebook'),
    );
    return StudyNotebookSummary.fromJson(dto.toJson().cast());
  });

  @override
  Future<StudyNotebook> openNotebook(String notebookId) => _guard(() async {
    final dto = await _client.getStudyNotebook(notebookId: notebookId);
    return StudyNotebook.fromJson(_json(dto.toJson()));
  });

  @override
  Future<StudyNotebookSummary> updateNotebook(
    String notebookId, {
    List<String>? sourceIds,
  }) => _guard(() async {
    final dto = await _client.regenerateStudyNotebook(
      V1RegenerateStudyNotebookRequestDto.fromJson({'sourceIds': ?sourceIds}),
      notebookId: notebookId,
      idempotencyKey: _key('notebook-update'),
    );
    return StudyNotebookSummary.fromJson(dto.toJson().cast());
  });

  @override
  Future<StudyNotebookSummary> saveNotebookSettings(
    String notebookId,
    NotebookSettings settings,
  ) => _guard(() async {
    final dto = await _client.updateStudyNotebookSettings(
      V1StudyNotebookSettingsRequestDto.fromJson(_json(settings.toJson())),
      notebookId: notebookId,
      idempotencyKey: _key('notebook-settings'),
    );
    return StudyNotebookSummary.fromJson(dto.toJson().cast());
  });

  @override
  Future<StudyNotebook> saveNotebookPersonal(
    String notebookId, {
    required int expectedVersion,
    required NotebookPersonal personal,
  }) async {
    try {
      final dto = await _client.saveStudyNotebookPersonal(
        V1StudyNotebookPersonalRequestDto.fromJson(
          _json({
            'expectedVersion': expectedVersion,
            'personal': personal.toJson(),
          }),
        ),
        notebookId: notebookId,
        idempotencyKey: _key('notebook-personal'),
      );
      return StudyNotebook.fromJson(_json(dto.toJson()));
    } on V1ApiException catch (error) {
      if (error.code == 'VERSION_CONFLICT') throw const NotebookConflict(null);
      throw StudyException(_refusal(error));
    } on Object catch (error) {
      throw StudyException(_refusal(error));
    }
  }

  @override
  Future<void> deleteNotebook(String notebookId) => _guard(() async {
    await _client.deleteStudyNotebook(
      const V1DeleteStudyNotebookRequestDto(),
      notebookId: notebookId,
      idempotencyKey: _key('notebook-delete'),
    );
  });

  @override
  Future<StudySet> notebookStudySet(
    String notebookId,
    StudySetKind kind,
    List<String> sectionKeys,
  ) => _guard(() async {
    final dto = await _client.makeNotebookStudySet(
      V1NotebookStudySetRequestDto(kind: kind.name, sectionKeys: sectionKeys),
      notebookId: notebookId,
      idempotencyKey: _key('notebook-set-${kind.name}'),
    );
    return _set(kind, dto.questions, dto.cards);
  });

  /// A DTO's map, as plain JSON all the way down, the shape the domain
  /// models and request DTOs read.
  static Map<String, dynamic> _json(Map<String, Object?> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}
