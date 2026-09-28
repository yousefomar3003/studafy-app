import '../../../core/file_upload_repository.dart';
import '../../../data/contracts/v1_client.generated.dart';
import '../../../data/contracts/v1_http_transport.dart';
import '../domain/study.dart';
import '../../../core/idempotency.dart';

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
      'AI_DAILY_LIMIT' => StudyRefusal.dailyLimit,
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
      allowanceUsed: dto.allowanceUsed.toDouble(),
      resetsAt: DateTime.parse(dto.resetsAt).toLocal(),
      askToday: dto.askToday,
      askPerDay: dto.askPerDay,
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
        return StudySet(
          kind: kind,
          questions: [
            for (final q in dto.questions ?? const <V1QuizQuestionDto>[])
              QuizQuestion(
                question: q.question,
                options: q.options,
                answerIndex: q.answerIndex,
                explanation: q.explanation,
              ),
          ],
          cards: [
            for (final c in dto.cards ?? const <V1FlashcardDto>[])
              Flashcard(front: c.front, back: c.back),
          ],
        );
      });
}
