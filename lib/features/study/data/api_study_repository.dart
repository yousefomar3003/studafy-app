import 'dart:convert';

import '../../../core/ai_consent.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/idempotency.dart';
import '../../../core/inline_photo.dart';
import '../../../core/material_selection.dart';
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
      'PAYLOAD_TOO_LARGE' ||
      'UNSUPPORTED_MEDIA_TYPE' => StudyRefusal.photoRejected,
      'LESSON_HAS_NO_TEXT' => StudyRefusal.lessonHasNoText,
      'AI_FEATURE_DISABLED' => StudyRefusal.unavailable,
      'AI_STUDENTS_ONLY' => StudyRefusal.aiConsent,
      _ => StudyRefusal.failed,
    };
  }

  /// Every call, with the AI notice shown first when the server wants the
  /// student's consent (ADR-0043): once they agree, the call is made again.
  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await AiConsentGate.instance.run(() => _guardOnce(run));
    } on AiConsentRequiredException {
      throw const StudyException(StudyRefusal.aiConsent);
    }
  }

  static Future<T> _guardOnce<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on StudyException {
      rethrow;
    } on V1ApiException catch (error) {
      if (error.code == 'AI_CONSENT_REQUIRED' ||
          error.code == 'AI_GUARDIAN_CONSENT_REQUIRED') {
        throw AiConsentRequiredException(
          guardian: error.code == 'AI_GUARDIAN_CONSENT_REQUIRED',
        );
      }
      // Chosen files that cannot be read now, named so the student can try
      // again or go on without them.
      if (error.code == 'MATERIAL_UNAVAILABLE') {
        throw MaterialUnavailableException({
          for (final entry in error.fieldErrors.entries)
            if (entry.key.startsWith('sources/'))
              entry.key.substring('sources/'.length): entry.value,
        });
      }
      throw StudyException(_refusal(error));
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
    updatedAt: switch (dto.updatedAt) {
      final at? => DateTime.parse(at).toLocal(),
      null => null,
    },
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
      aiEnabled: dto.aiEnabled,
      aiAccess: dto.aiAccess,
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
    // Any of the student's own notes, in a class or personal (ADR-0045).
    await _client.deleteMyNotebookEntry(
      const V1DeleteNotebookEntryRequestDto(),
      entryId: entryId,
      idempotencyKey: _key('delete'),
    );
  });

  @override
  Future<List<NotebookEntry>> personalNotebook() => _guard(() async {
    final page = await _client.listMyNotebookEntries();
    return [for (final item in page.items) _entry(item)];
  });

  @override
  Future<NotebookEntry> addPersonalNote({
    required String title,
    required String body,
  }) => _guard(() async {
    return _entry(
      await _client.createMyNotebookEntry(
        V1CreateNotebookEntryRequestDto(title: title, body: body),
        idempotencyKey: _key('personal-note'),
      ),
    );
  });

  @override
  Future<NotebookEntry> photoNote(InlinePhoto photo, {String? title}) =>
      _guard(() async {
        return _entry(
          await _client.createMyPhotoNote(
            V1PhotoNoteRequestDto.fromJson({
              'image': photo.toJson(),
              'title': ?title,
            }),
            idempotencyKey: _key('photo-note'),
          ),
        );
      });

  @override
  Future<NotebookEntry> editNote(
    String entryId, {
    String? title,
    String? body,
  }) => _guard(() async {
    return _entry(
      await _client.updateMyNotebookEntry(
        V1UpdateNotebookEntryRequestDto.fromJson({
          'title': ?title,
          'body': ?body,
        }),
        entryId: entryId,
        idempotencyKey: _key('edit'),
      ),
    );
  });

  @override
  Future<StudySet> practiseNotes(StudySetKind kind, List<String> entryIds) =>
      _guard(() async {
        final dto = await _client.practiseMyNotes(
          V1NotesPracticeRequestDto(kind: kind.name, entryIds: entryIds),
          idempotencyKey: _key('practice-${kind.name}'),
        );
        return _set(kind, dto.questions, dto.cards);
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
    List<V1FlashcardDto>? cards, {
    MaterialScopeInfo? scope,
  }) => StudySet(
    kind: kind,
    scope: scope,
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
  Future<StudySet> selectionStudySet(
    StudySetKind kind,
    MaterialSelection selection, {
    bool skipUnavailable = false,
  }) => _guard(() async {
    final dto = await _client.generateSelectionStudySet(
      V1SelectionStudySetRequestDto.fromJson(
        _json({
          'kind': kind.name,
          'references': selection.toJson(),
          if (skipUnavailable) 'skipUnavailable': true,
        }),
      ),
      idempotencyKey: _key('selection-${kind.name}'),
    );
    return _set(
      kind,
      dto.questions,
      dto.cards,
      scope: MaterialScopeInfo.fromJson(_json(dto.scope.toJson())),
    );
  });

  @override
  Future<NotebookEntry> summarise(
    String classroomId,
    MaterialSelection selection, {
    bool skipUnavailable = false,
    String? language,
  }) => _guard(() async {
    return _entry(
      await _client.summariseMaterial(
        V1SummariseMaterialRequestDto.fromJson(
          _json({
            'references': selection.toJson(),
            if (skipUnavailable) 'skipUnavailable': true,
            if (language == 'ar' || language == 'en') 'language': language,
          }),
        ),
        classroomId: classroomId,
        idempotencyKey: _key('summary'),
      ),
    );
  });

  @override
  Future<StudyNotebookSummary> createNotebook(
    String classroomId, {
    required String resourceId,
    required List<String> sourceIds,
    String? title,
    MaterialSelection? selection,
    bool skipUnavailable = false,
  }) => _guard(() async {
    final dto = await _client.createStudyNotebook(
      V1CreateStudyNotebookRequestDto.fromJson(
        _json({
          'resourceId': resourceId,
          'sourceIds': sourceIds,
          'title': ?title,
          if (selection != null) 'references': selection.toJson(),
          if (skipUnavailable) 'skipUnavailable': true,
        }),
      ),
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
    bool skipUnavailable = false,
  }) => _guard(() async {
    final dto = await _client.regenerateStudyNotebook(
      V1RegenerateStudyNotebookRequestDto.fromJson({
        'sourceIds': ?sourceIds,
        if (skipUnavailable) 'skipUnavailable': true,
      }),
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
