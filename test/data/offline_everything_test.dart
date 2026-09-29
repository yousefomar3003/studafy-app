import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/data/contracts/response_cache.dart';
import 'package:studafy/data/local_cache/offline_file_cache.dart';
import 'package:studafy/data/local_cache/offline_response_cache.dart';
import 'package:studafy/data/local_cache/session_cache_binder.dart';
import 'package:studafy/features/study_assistant/data/cached_study_assistant_repository.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';

class _Files implements FileUploadRepository {
  Object? failure;
  int downloads = 0;
  @override
  Future<DownloadedFile> download(String fileId) async {
    downloads += 1;
    if (failure != null) throw failure!;
    return DownloadedFile(
      displayName: 'worksheet.pdf',
      mediaType: 'application/pdf',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Helper implements StudyAssistantRepository {
  final asked = <String>[];
  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async {
    asked.add(question);
    return StudyAnswer(answer: 'Answer ${asked.length}', remainingToday: 7);
  }
}

class _Memory implements ResponseCache {
  final entries = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Map<String, dynamic> body) async =>
      entries[key] = body;
}

void signIn(String id) => ActiveContextController.instance.hydrate(
  authenticatedProfile: UserProfile(
    id: id,
    displayName: 'Student',
    email: '$id@example.test',
    memberships: const [],
  ),
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  tearDown(ActiveContextController.instance.signOut);

  test('reads are kept for the account and erased at sign-out', () async {
    signIn('offline-reads-user');
    final binder = SessionCacheBinder(
      context: ActiveContextController.instance,
    );
    addTearDown(binder.dispose);
    final cache = OfflineResponseCache(binder);
    await cache.write('GET /v1/resources', {
      'items': ['Cells'],
    });
    expect(await cache.read('GET /v1/resources'), {
      'items': ['Cells'],
    });

    ActiveContextController.instance.signOut();
    await binder.settled;
    signIn('offline-reads-user');
    await binder.settled;
    expect(await cache.read('GET /v1/resources'), isNull);
  });

  test(
    'an attachment opened once opens again offline, not after a refusal',
    () async {
      signIn('offline-files-user');
      final binder = SessionCacheBinder(
        context: ActiveContextController.instance,
      );
      addTearDown(binder.dispose);
      final files = _Files();
      final repository = CachingFileRepository(files, OfflineFileCache(binder));

      expect((await repository.download('file-1')).bytes, [1, 2, 3]);

      files.failure = Failure.network;
      final offline = await repository.download('file-1');
      expect(offline.bytes, [1, 2, 3]);
      expect(offline.displayName, 'worksheet.pdf');

      // No longer allowed: the kept copy is not a way around the server.
      files.failure = Failure.forbidden;
      await expectLater(
        repository.download('file-1'),
        throwsA(Failure.forbidden),
      );

      // Never opened: offline says so.
      files.failure = Failure.network;
      await expectLater(
        repository.download('file-2'),
        throwsA(Failure.network),
      );

      // Sign-out erases the kept files.
      ActiveContextController.instance.signOut();
      await binder.settled;
      signIn('offline-files-user');
      await binder.settled;
      await expectLater(
        repository.download('file-1'),
        throwsA(Failure.network),
      );
    },
  );

  group('the study helper', () {
    test(
      'the same question in the same chat is answered from the device',
      () async {
        final helper = _Helper();
        final repository = CachedStudyAssistantRepository(helper, _Memory());
        final first = await repository.ask('What is  photosynthesis?');
        final again = await repository.ask('what is photosynthesis? ');
        expect(helper.asked, hasLength(1));
        expect(again.answer, first.answer);
        // A kept answer uses none of today's questions.
        expect(again.remainingToday, 7);
      },
    );

    test(
      'another context, a photo, or an old answer goes to the server',
      () async {
        var now = DateTime(2026, 9, 29);
        final helper = _Helper();
        final repository = CachedStudyAssistantRepository(
          helper,
          _Memory(),
          now: () => now,
        );
        await repository.ask('Explain cells');
        await repository.ask(
          'Explain cells',
          references: const [
            ChatReference(
              kind: ChatReferenceKind.lesson,
              id: 'l1',
              title: 'Cells',
            ),
          ],
        );
        await repository.ask('Explain cells', photoFileIds: const ['p1']);
        await repository.ask('Explain cells', photoFileIds: const ['p1']);
        expect(helper.asked, hasLength(4));

        now = now.add(const Duration(days: 8));
        await repository.ask('Explain cells');
        expect(helper.asked, hasLength(5));
      },
    );
  });
}
