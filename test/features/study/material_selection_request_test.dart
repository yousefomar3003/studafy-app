import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/material_selection.dart';
import 'package:studafy/data/contracts/v1_client.generated.dart';
import 'package:studafy/features/study/data/api_study_repository.dart';
import 'package:studafy/features/study/domain/study.dart';

/// The material a student chose reaches the server as the list it is.
///
/// The generated client once read `V1MaterialRefs` (a list) as an empty
/// object, so every request naming material - quizzes, flashcards and
/// study notes from chosen lessons - failed in the app before it was sent
/// (2026-11-03).
void main() {
  const lessonId = '00000000-0000-4000-8000-0000000000a1';
  const fileId = '00000000-0000-4000-8000-0000000000f1';
  const selection = MaterialSelection(
    lessons: [
      LessonSelection(
        lessonId: lessonId,
        title: 'Cells',
        classroomId: classroomId,
        classLabel: 'Biology',
        includeText: true,
        sourceIds: {fileId},
      ),
    ],
  );

  test('flashcards from chosen material send the chosen references', () async {
    final transport = _Transport();
    final set = await ApiStudyRepository(V1ApiClient(transport))
        .selectionStudySet(StudySetKind.flashcards, selection);

    expect(transport.lastPath, '/v1/study-sets');
    final references = transport.lastBody!['references']! as List<Object?>;
    expect(references, isNotEmpty);
    expect(references, [
      for (final ref in selection.toJson())
        {
          'kind': ref['kind'],
          'id': ref['id'],
          if (ref['lessonId'] != null) 'lessonId': ref['lessonId'],
        },
    ]);
    expect(set.cards, hasLength(4));
  });

  test('study notes from chosen material send them too', () async {
    final transport = _Transport();
    await ApiStudyRepository(V1ApiClient(transport))
        .summarise(classroomId, selection);

    final references = transport.lastBody!['references']! as List<Object?>;
    expect(references, hasLength(selection.toJson().length));
  });
}

class _Transport implements V1JsonTransport {
  String? lastPath;
  Map<String, Object?>? lastBody;

  static const _scope = {'lessons': <Object?>[], 'skipped': <Object?>[]};

  @override
  Future<Map<String, dynamic>> get(String path) async =>
      throw UnimplementedError(path);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? idempotencyKey,
    bool requiresIdempotency = false,
  }) async {
    lastPath = path.split('?').first;
    lastBody = body;
    if (lastPath == '/v1/study-sets') {
      return {
        'id': '00000000-0000-4000-8000-0000000000d1',
        'kind': 'flashcards',
        'questions': null,
        'cards': [
          for (var i = 0; i < 4; i++)
            {'front': 'Term $i', 'back': 'Meaning $i'},
        ],
        'scope': _scope,
        'createdAt': '2026-11-03T10:00:00Z',
      };
    }
    return {
      'id': '00000000-0000-4000-8000-0000000000e1',
      'classroomId': classroomId,
      'title': 'Cells',
      'body': '# Cells',
      'source': 'lesson',
      'createdAt': '2026-11-03T10:00:00Z',
      'photo': null,
      'scope': _scope,
    };
  }
}

const classroomId = '00000000-0000-4000-8000-0000000000c1';
