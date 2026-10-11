import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/file_upload_repository.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/conversation_page.dart';
import 'package:studafy/features/messaging/presentation/conversations_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// WhatsApp's ticks: one grey when sent, two grey when it reaches the other
/// person's app, two blue once they open the chat. How the server derives
/// them - including "everyone" for a group - is proven against real SQL in
/// apps/api/test/communications; this is what the screens show and report.
void main() {
  const me = 'user-me';
  const them = 'user-them';

  final conversation = Conversation(
    id: 'c1',
    schoolId: 'school-1',
    updatedAt: DateTime(2026, 9, 27, 10),
    participants: const [
      ConversationParticipant(
        userId: me,
        displayName: 'Me',
        role: MessagingRole.staff,
      ),
      ConversationParticipant(
        userId: them,
        displayName: 'Huda',
        role: MessagingRole.guardian,
      ),
    ],
  );

  ChatMessage mine(String id, MessageStatus status, int minute) => ChatMessage(
    id: id,
    conversationId: 'c1',
    senderId: me,
    body: 'Mine $id',
    createdAt: DateTime(2026, 9, 27, 10, minute),
    status: status,
  );

  Widget chat(_Receipts fake, {Duration refresh = const Duration(hours: 1)}) =>
      localizedApp(
        home: MessagingScope(
          interactor: MessagingInteractor(
            messaging: fake,
            safety: fake,
            telemetry: const NoopTelemetry(),
          ),
          child: ConversationPage(
            conversation: conversation,
            myUserId: me,
            refreshEvery: refresh,
          ),
        ),
      );

  Icon tickOf(WidgetTester tester, String body) {
    final bubble = find.ancestor(
      of: find.text(body),
      matching: find.byType(Column),
    );
    return tester.widget<Icon>(
      find.descendant(of: bubble.first, matching: find.byType(Icon)).last,
    );
  }

  testWidgets('each state shows its tick', (tester) async {
    final fake = _Receipts([
      mine('a', MessageStatus.read, 3),
      mine('b', MessageStatus.delivered, 2),
      mine('c', MessageStatus.sent, 1),
    ]);
    await tester.pumpWidget(chat(fake));
    await tester.pumpAndSettle();

    final sent = tickOf(tester, 'Mine c');
    expect(sent.icon, Icons.done_rounded);
    expect(sent.color, Colors.white70);

    final delivered = tickOf(tester, 'Mine b');
    expect(delivered.icon, Icons.done_all_rounded);
    expect(delivered.color, Colors.white70);

    final read = tickOf(tester, 'Mine a');
    expect(read.icon, Icons.done_all_rounded);
    expect(read.color, MessageTicks.readColor);
  });

  testWidgets("other people's messages show no ticks", (tester) async {
    final fake = _Receipts([
      ChatMessage(
        id: 'x',
        conversationId: 'c1',
        senderId: them,
        body: 'From Huda',
        createdAt: DateTime(2026, 9, 27, 10),
      ),
    ]);
    await tester.pumpWidget(chat(fake));
    await tester.pumpAndSettle();
    expect(find.byType(MessageTicks), findsNothing);
  });

  testWidgets('opening a chat marks it read', (tester) async {
    final fake = _Receipts([mine('a', MessageStatus.sent, 1)]);
    await tester.pumpWidget(chat(fake));
    await tester.pumpAndSettle();
    expect(fake.read, ['c1']);
  });

  testWidgets('an open chat picks up the other person reading it', (
    tester,
  ) async {
    final fake = _Receipts([mine('a', MessageStatus.sent, 1)]);
    await tester.pumpWidget(chat(fake, refresh: const Duration(seconds: 4)));
    await tester.pumpAndSettle();
    expect(tickOf(tester, 'Mine a').color, Colors.white70);

    // They open it on their phone; the next refresh shows blue.
    fake.items = [mine('a', MessageStatus.read, 1)];
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tickOf(tester, 'Mine a').color, MessageTicks.readColor);
  });

  testWidgets('a reply arriving in an open chat is shown and marked read', (
    tester,
  ) async {
    final fake = _Receipts([mine('a', MessageStatus.delivered, 1)]);
    await tester.pumpWidget(chat(fake, refresh: const Duration(seconds: 4)));
    await tester.pumpAndSettle();
    fake.read.clear();

    fake.items = [
      ChatMessage(
        id: 'reply',
        conversationId: 'c1',
        senderId: them,
        body: 'Thanks!',
        createdAt: DateTime(2026, 9, 27, 10, 5),
      ),
      mine('a', MessageStatus.read, 1),
    ];
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Thanks!'), findsOne);
    expect(fake.read, ['c1']);
  });

  testWidgets('a message sent while a refresh is on its way stays shown', (
    tester,
  ) async {
    final fake = _Receipts([mine('a', MessageStatus.read, 1)]);
    await tester.pumpWidget(chat(fake, refresh: const Duration(seconds: 4)));
    await tester.pumpAndSettle();

    // The refresh leaves before the send and comes back after it, without
    // the new message in it.
    fake.hold = Completer<void>();
    await tester.pump(const Duration(seconds: 5));
    fake.sent = mine('new', MessageStatus.sent, 6);
    await tester.enterText(find.byType(TextField), 'Mine new');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mine new'), findsOne);

    fake.hold!.complete();
    fake.hold = null;
    await tester.pumpAndSettle();
    expect(find.text('Mine new'), findsOne);
    expect(find.text('Mine a'), findsOne);
  });

  testWidgets('a file still being checked is looked at again every second', (
    tester,
  ) async {
    ChatMessage voice(String scanState) => ChatMessage(
      id: 'v',
      conversationId: 'c1',
      senderId: me,
      body: '',
      createdAt: DateTime(2026, 9, 27, 10, 2),
      status: MessageStatus.sent,
      attachments: [
        StoredAttachment(
          id: 'f1',
          displayName: 'Voice message',
          sizeBytes: 100,
          scanState: scanState,
          mediaType: 'audio/mp4',
        ),
      ],
    );
    final fake = _Receipts([voice('quarantined')]);
    // The usual refresh is an hour away: only the quick look can see it.
    await tester.pumpWidget(chat(fake));
    await tester.pumpAndSettle();
    final before = fake.reads;

    fake.items = [voice('clean')];
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(fake.reads, greaterThan(before));

    // Cleared: back to the usual pace.
    final settled = fake.reads;
    await tester.pump(const Duration(seconds: 5));
    expect(fake.reads, settled);
  });

  testWidgets('the inbox tells the server this device has its messages', (
    tester,
  ) async {
    ActiveContextController.instance.hydrate(
      authenticatedProfile: const UserProfile(
        id: me,
        displayName: 'Me',
        email: 'me@example.test',
        memberships: [],
      ),
    );
    addTearDown(ActiveContextController.instance.signOut);
    final fake = _Receipts(const []);
    await tester.pumpWidget(
      localizedApp(
        home: MessagingScope(
          interactor: MessagingInteractor(
            messaging: fake,
            safety: fake,
            telemetry: const NoopTelemetry(),
          ),
          child: const ConversationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.acknowledged, greaterThan(0));
  });
}

class _Receipts implements MessagingRepository, SafetyRepository {
  _Receipts(this.items);

  List<ChatMessage> items;
  final read = <String>[];
  int acknowledged = 0;

  /// While set, a read of the messages waits for it, answering with what
  /// was there when it was asked.
  Completer<void>? hold;

  /// What the next send returns.
  ChatMessage? sent;

  /// Reads of the messages so far.
  int reads = 0;

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) async {
    reads++;
    final page = MessagePage(items: List.of(items));
    await hold?.future;
    return page;
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
    List<String> attachmentFileIds = const [],
  }) async => sent!;

  @override
  Future<List<Conversation>> conversations() async => const [];

  @override
  Future<bool> messagingEnabled(String schoolId) async => true;

  @override
  Future<List<BlockedPerson>> blocks(String schoolId) async => const [];

  @override
  Future<void> markRead(String conversationId) async =>
      read.add(conversationId);

  @override
  Future<void> acknowledgeDelivery() async => acknowledged++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
