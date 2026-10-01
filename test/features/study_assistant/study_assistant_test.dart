import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/attachment_field.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/study_assistant/application/study_assistant_interactor.dart';
import 'package:studafy/features/study_assistant/data/file_study_chat_store.dart';
import 'package:studafy/features/study_assistant/domain/study_assistant_repository.dart';
import 'package:studafy/features/study_assistant/presentation/study_assistant_page.dart';

import '../../support/localized_app.dart';

/// The study helper, as a chat. It sends a child's words to a third party,
/// so what it keeps and what it sends matter more than how it looks.
void main() {
  Widget page(
    StudyAssistantRepository repository, {
    Locale? locale,
    Future<bool> Function()? switchedOn,
    StudyChatStore? chats,
    HelperAbilities? abilities,
    List<ChatReference>? pick,
    _Uploads? uploads,
    Future<void> Function(BuildContext, String)? onPlanLimit,
    HelperPlan? plan,
    Future<void> Function()? onUpgrade,
  }) => localizedApp(
    locale: locale,
    home: StudyAssistantPage(
      assistant: StudyAssistantInteractor(
        repository: repository,
        telemetry: const NoopTelemetry(),
      ),
      switchedOn: switchedOn,
      chats: chats,
      abilities: abilities == null ? null : () async => abilities,
      pickReferences: pick == null ? null : (_, _) async => pick,
      uploads: uploads,
      onPlanLimit: onPlanLimit,
      plan: plan == null ? null : () async => plan,
      onUpgrade: onUpgrade,
      schoolId: uploads == null ? null : 'school-1',
      attachmentSource: (_, _) async => PickedAttachment(
        displayName: 'homework.jpg',
        mediaType: 'image/jpeg',
        bytes: Uint8List(2048),
      ),
      photoReadyPoll: const Duration(milliseconds: 10),
    ),
  );

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byType(TextField), question);
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  const cells = ChatReference(
    kind: ChatReferenceKind.lesson,
    id: 'lesson-1',
    title: 'Cells',
  );

  testWidgets('class material chosen for a chat goes with every question', (
    tester,
  ) async {
    final repository = _Recording();
    await tester.pumpWidget(
      page(
        repository,
        abilities: const HelperAbilities(classMaterial: true),
        pick: const [cells],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add material or a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class material'));
    await tester.pumpAndSettle();
    expect(find.text('Cells'), findsOne);

    await ask(tester, 'What is a nucleus?');
    await ask(tester, 'And a membrane?');

    expect(repository.referencesSent, [
      [cells],
      [cells],
    ]);
  });

  testWidgets('photos are locked without Studafy Plus', (tester) async {
    await tester.pumpWidget(
      page(
        _Recording(),
        abilities: const HelperAbilities(classMaterial: true),
        pick: const [],
        uploads: _Uploads(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add material or a photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photos come with Studafy Plus.'), findsOne);
  });

  testWidgets('a photo is uploaded, waited for, and sent with the question', (
    tester,
  ) async {
    final repository = _Recording(notReadyTimes: 2);
    final uploads = _Uploads();
    await tester.pumpWidget(
      page(
        repository,
        abilities: const HelperAbilities(photos: true),
        uploads: uploads,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add material or a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo from library'));
    await tester.pumpAndSettle();
    expect(find.text('homework.jpg'), findsOne);

    await ask(tester, 'Explain this question');

    expect(uploads.purposes, [FilePurpose.assistantAttachment]);
    expect(repository.photosSent, [
      ['photo-1'],
    ]);
    expect(find.text('Answer 1'), findsOne);
  });

  testWidgets('says questions leave the app before any are typed', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Recording()));
    await tester.pumpAndSettle();
    expect(find.textContaining('sent to an AI service'), findsOneWidget);
  });

  testWidgets('a follow-up keeps the chat on screen and sends it along', (
    tester,
  ) async {
    // The reported problem: every new question wiped the previous one, and
    // "what is this?" had nothing to refer to.
    final repository = _Recording();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await ask(tester, 'What is photosynthesis?');
    await ask(tester, 'Why do leaves need it?');

    expect(find.text('What is photosynthesis?'), findsOne);
    expect(find.text('Answer 1'), findsOne);
    expect(find.text('Why do leaves need it?'), findsOne);
    expect(find.text('Answer 2'), findsOne);
    expect(repository.histories.first, isEmpty);
    expect(
      [for (final turn in repository.histories.last) turn.text],
      ['What is photosynthesis?', 'Answer 1'],
    );
    expect(find.textContaining('can be wrong'), findsOneWidget);
  });

  testWidgets('will not ask twice while an answer is still coming', (
    tester,
  ) async {
    // The provider takes seconds, the student taps again, and without the
    // guard both taps spend one of the day's questions.
    final repository = _Held();
    await tester.pumpWidget(page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Explain photosynthesis');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.text('Thinking…'), findsOne);
    await tester.tap(find.byTooltip('Send'), warnIfMissed: false);
    await tester.pump();
    expect(repository.questions, hasLength(1));

    repository.release();
    await tester.pumpAndSettle();
    expect(repository.questions, ['Explain photosynthesis']);
  });

  testWidgets('a refused question goes back in the box, explained', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Refusing(StudyAssistantFailure.dailyLimit)));
    await tester.pumpAndSettle();
    await ask(tester, 'Anything at all');

    expect(find.textContaining("used all of today's questions"), findsOne);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Anything at all',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a plan limit is handed to the host to offer the upgrade', (
    tester,
  ) async {
    final limits = <String>[];
    await tester.pumpWidget(
      page(
        _Refusing(StudyAssistantFailure.dailyLimit),
        onPlanLimit: (_, code) async => limits.add(code),
      ),
    );
    await tester.pumpAndSettle();
    await ask(tester, 'One more');
    expect(limits, [StudyAssistantFailure.dailyLimit]);
  });

  testWidgets('a missing helper is not "this record no longer exists"', (
    tester,
  ) async {
    await tester.pumpWidget(page(_Refusing(StudyAssistantFailure.unavailable)));
    await tester.pumpAndSettle();
    await ask(tester, 'Anything at all');

    expect(find.textContaining('could not answer just now'), findsOne);
    expect(find.textContaining('no longer exists'), findsNothing);
  });

  testWidgets('a server with no AI provider says so, and asks nothing', (
    tester,
  ) async {
    final repository = _Recording();
    await tester.pumpWidget(page(repository, switchedOn: () async => false));
    await tester.pumpAndSettle();

    expect(find.textContaining('not switched on yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Send'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repository.questions, isEmpty);
  });

  testWidgets('the plan, its questions today and what upgrading adds', (
    tester,
  ) async {
    var upgrades = 0;
    await tester.pumpWidget(
      page(
        _Recording(),
        plan: const HelperPlan(
          name: 'Studafy Free',
          askToday: 4,
          askPerDay: 10,
          upgradeTo: 'Studafy Plus',
          upgradeBenefits: ['40 questions a day'],
        ),
        onUpgrade: () async => upgrades++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Studafy Free'), findsOne);
    expect(find.text('Questions today: 4 of 10'), findsOne);
    expect(find.text('Studafy Plus adds:'), findsOne);
    expect(find.text('40 questions a day'), findsOne);
    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(upgrades, 1);
  });

  testWidgets('on the top plan nothing is sold', (tester) async {
    await tester.pumpWidget(
      page(
        _Recording(),
        plan: const HelperPlan(name: 'Studafy Max', askToday: 1, askPerDay: 60),
        onUpgrade: () async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Studafy Max'), findsOne);
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets(
    'with today\'s questions used, it says so and offers the way on',
    (tester) async {
      var upgrades = 0;
      await tester.pumpWidget(
        page(
          _Recording(),
          plan: const HelperPlan(
            name: 'Studafy Free',
            askToday: 10,
            askPerDay: 10,
            upgradeTo: 'Studafy Plus',
          ),
          onUpgrade: () async => upgrades++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("You've used today's questions"), findsOne);
      await tester.tap(find.widgetWithText(FilledButton, 'Upgrade').last);
      await tester.pumpAndSettle();
      expect(upgrades, 1);
    },
  );

  testWidgets('chats are kept, and an old one can be opened again', (
    tester,
  ) async {
    final store = _MemoryChats();
    await tester.pumpWidget(page(_Recording(), chats: store));
    await tester.pumpAndSettle();

    await ask(tester, 'What is gravity?');
    expect(store.saved.single.turns, hasLength(2));

    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();
    // The chat is closed, and listed among the recent ones to go back to.
    expect(find.text('Recent chats'), findsOne);
    expect(find.text('What is gravity?'), findsOne);

    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    expect(find.text('Kept on this device only'), findsOne);
    await tester.tap(find.text('What is gravity?'));
    await tester.pumpAndSettle();

    expect(find.text('What is gravity?'), findsOne);
    expect(find.text('Answer 1'), findsOne);
  });

  testWidgets('the helper opens where the student left off', (tester) async {
    final store = _MemoryChats()
      ..saved.add(
        StudyChat(
          id: 'c1',
          title: 'Fractions',
          createdAt: DateTime(2026, 9, 28),
          updatedAt: DateTime(2026, 9, 28),
          turns: [
            ChatTurn(
              role: ChatRole.student,
              text: 'Fractions',
              at: DateTime(2026, 9, 28),
            ),
            ChatTurn(
              role: ChatRole.assistant,
              text: 'A part of a whole.',
              at: DateTime(2026, 9, 28),
            ),
          ],
        ),
      );
    await tester.pumpWidget(page(_Recording(), chats: store));
    await tester.pumpAndSettle();

    expect(find.text('A part of a whole.'), findsOne);
  });

  testWidgets('an old chat reopened from history is continued with its '
      'messages sent along', (tester) async {
    final store = _MemoryChats();
    final repository = _Recording();
    await tester.pumpWidget(page(repository, chats: store));
    await tester.pumpAndSettle();
    await ask(tester, 'What is gravity?');
    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();
    await ask(tester, 'What is a verb?');

    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What is gravity?'));
    await tester.pumpAndSettle();
    await ask(tester, 'Why do things fall down?');

    // Only that chat, stored on the phone, is read to continue it.
    expect(
      [for (final turn in repository.histories.last) turn.text],
      ['What is gravity?', 'Answer 1'],
    );
    expect(
      store.saved.firstWhere((c) => c.title == 'What is gravity?').turns,
      hasLength(4),
    );
  });

  testWidgets('reads in Arabic', (tester) async {
    await tester.pumpWidget(page(_Recording(), locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      directionOf(tester, find.byType(StudyAssistantPage)),
      TextDirection.rtl,
    );
    expect(find.text('مساعد الدراسة'), findsOneWidget);
  });

  group('chats on the device', () {
    late Directory directory;
    setUp(() => directory = Directory.systemTemp.createTempSync('chats'));
    tearDown(() => directory.deleteSync(recursive: true));

    StudyChat chat(String id, int minute) => StudyChat(
      id: id,
      title: id,
      createdAt: DateTime(2026, 9, 28, 10, minute),
      updatedAt: DateTime(2026, 9, 28, 10, minute),
    );

    test('each account sees only its own, newest first', () async {
      var user = 'student-a';
      final store = FileStudyChatStore(
        currentUserId: () => user,
        directory: () async => directory,
      );
      await store.save(chat('older', 1));
      await store.save(chat('newer', 2));
      expect([for (final c in await store.chats()) c.id], ['newer', 'older']);

      user = 'student-b';
      expect(await store.chats(), isEmpty);
    });

    test('the file does not name its owner', () async {
      final store = FileStudyChatStore(
        currentUserId: () => 'student-a',
        directory: () async => directory,
      );
      await store.save(chat('one', 1));
      final names = directory.listSync().map((f) => f.path).join();
      expect(names, isNot(contains('student-a')));
    });

    test('signing an account out deletes its chats, not others', () async {
      var user = 'student-a';
      final store = FileStudyChatStore(
        currentUserId: () => user,
        directory: () async => directory,
      );
      await store.save(chat('a', 1));
      user = 'student-b';
      await store.save(chat('b', 1));

      await store.forgetUser('student-a');

      expect([for (final c in await store.chats()) c.id], ['b']);
      user = 'student-a';
      expect(await store.chats(), isEmpty);
    });
  });
}

class _Recording implements StudyAssistantRepository {
  _Recording({this.notReadyTimes = 0});

  /// How many times a photo is still being checked before it is not.
  int notReadyTimes;
  final List<String> questions = [];
  final List<List<ChatTurn>> histories = [];
  final List<List<ChatReference>> referencesSent = [];
  final List<List<String>> photosSent = [];

  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async {
    if (photoFileIds.isNotEmpty && notReadyTimes > 0) {
      notReadyTimes--;
      throw const Failure(StudyAssistantFailure.photoNotReady, 'checking');
    }
    questions.add(question);
    histories.add(history);
    referencesSent.add(references);
    photosSent.add(photoFileIds);
    return StudyAnswer(
      answer: 'Answer ${questions.length}',
      remainingToday: 29,
    );
  }
}

class _Refusing implements StudyAssistantRepository {
  _Refusing(this.code);

  final String code;

  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async => throw Failure(code, 'English fallback');
}

/// Holds the first call open so the in-flight guard can be observed.
class _Held implements StudyAssistantRepository {
  final List<String> questions = [];
  final Completer<void> _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<StudyAnswer> ask(
    String question, {
    List<ChatTurn> history = const [],
    List<ChatReference> references = const [],
    List<String> photoFileIds = const [],
  }) async {
    questions.add(question);
    await _gate.future;
    return const StudyAnswer(answer: 'An answer.', remainingToday: 29);
  }
}

class _MemoryChats implements StudyChatStore {
  final List<StudyChat> saved = [];

  @override
  Future<List<StudyChat>> chats() async =>
      [...saved]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> save(StudyChat chat) async => saved
    ..removeWhere((c) => c.id == chat.id)
    ..add(chat);

  @override
  Future<void> delete(String chatId) async =>
      saved.removeWhere((c) => c.id == chatId);

  @override
  Future<void> deleteAll() async => saved.clear();
}

class _Uploads implements FileUploadRepository {
  final purposes = <FilePurpose>[];

  @override
  Future<QuarantinedFile> upload(FileUploadCommand command) async {
    purposes.add(command.purpose);
    return QuarantinedFile(
      id: 'photo-${purposes.length}',
      uploadId: 'upload-${purposes.length}',
      displayName: command.displayName,
      sizeBytes: command.bytes.length,
      scanState: 'pending',
    );
  }

  @override
  Future<DownloadedFile> download(String fileId) => throw UnimplementedError();

  @override
  Future<String> publishToClass({
    required String fileId,
    required FileAudience audience,
  }) => throw UnimplementedError();
}
