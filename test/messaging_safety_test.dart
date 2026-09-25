import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/failures.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/blocked_people_page.dart';
import 'package:studafy/features/messaging/presentation/conversation_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';
import 'package:studafy/features/messaging/presentation/messaging_strings.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

/// SAFE-043 / store UGC requirements: labelled report-content,
/// report-user and block-user controls are reachable from every
/// conversation, blocks are reversible, and nothing reveals who blocked
/// whom when it was the other person.
const _me = 'user-me';
const _teacher = 'user-teacher';
const _school = 'school-1';

final _conversation = Conversation(
  id: 'conversation-1',
  schoolId: _school,
  updatedAt: DateTime(2026, 9, 19, 10),
  lastReadAt: DateTime(2026, 9, 19, 10),
  participants: const [
    ConversationParticipant(
      userId: _me,
      displayName: 'Nadia Hassan',
      role: MessagingRole.guardian,
    ),
    ConversationParticipant(
      userId: _teacher,
      displayName: 'Rana Haddad',
      role: MessagingRole.staff,
    ),
  ],
);

class _Fake implements MessagingRepository, SafetyRepository {
  final List<BlockedPerson> blockList = [];
  final List<Map<String, Object?>> reports = [];
  final List<String> sentClientIds = [];
  bool failNextSend = false;

  @override
  Future<bool> messagingEnabled(String schoolId) async => true;
  @override
  Future<List<Conversation>> conversations() async => [_conversation];
  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) async =>
      MessagePage(
        items: [
          ChatMessage(
            id: 'message-1',
            conversationId: conversationId,
            senderId: _teacher,
            body: 'Please see me after class',
            createdAt: DateTime(2026, 9, 19, 9),
          ),
        ],
      );
  @override
  Future<ChatMessage> send(
    String conversationId,
    String body, {
    required String clientMessageId,
    List<String> attachmentFileIds = const [],
  }) async {
    sentClientIds.add(clientMessageId);
    if (failNextSend) {
      failNextSend = false;
      throw Failure.network;
    }
    return ChatMessage(
      id: clientMessageId,
      conversationId: conversationId,
      senderId: _me,
      body: body,
      createdAt: DateTime(2026, 9, 19, 11),
    );
  }

  @override
  Future<void> createAnnouncement(AnnouncementDraft draft) async {}
  @override
  Future<List<Announcement>> announcements({String? classroomId}) async =>
      const [];
  @override
  Future<List<MessagingContact>> contacts(String schoolId) async => const [];
  @override
  Future<Conversation> startConversation({
    required String schoolId,
    required List<String> participantIds,
    String? subject,
  }) async => _conversation;
  @override
  Future<void> report({
    required String schoolId,
    required ReportTarget target,
    required String details,
    String? messageId,
    String? conversationId,
    String? subjectUserId,
    required bool contactConsent,
  }) async => reports.add({
    'target': target,
    'details': details,
    'messageId': messageId,
    'subjectUserId': subjectUserId,
  });
  @override
  Future<BlockedPerson> block({
    required String schoolId,
    required String userId,
  }) async {
    final block = BlockedPerson(
      blockId: 'block-${blockList.length}',
      schoolId: schoolId,
      blockerId: _me,
      blockedId: userId,
      createdAt: DateTime(2026),
    );
    blockList.add(block);
    return block;
  }

  @override
  Future<void> unblock(String blockId) async =>
      blockList.removeWhere((b) => b.blockId == blockId);
  @override
  Future<List<BlockedPerson>> blocks(String schoolId) async =>
      List.of(blockList);
}

Widget _app(_Fake fake, Widget home, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: StudafyLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        StudafyLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Above the Navigator, as in main.dart, so sheets and dialogs on the
      // root overlay can reach the scope.
      builder: (context, child) => MessagingScope(
        interactor: MessagingInteractor(
          messaging: fake,
          safety: fake,
          telemetry: const NoopTelemetry(),
        ),
        child: child!,
      ),
      home: home,
    );

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.flag_outlined));
  await tester.pumpAndSettle();
}

void main() {
  const page = ConversationPage(conversation: _conversationRef, myUserId: _me);

  test('every messaging string exists in English and Arabic', () {
    final keys = messagingStringKeys();
    expect(keys['ar'], keys['en']);
  });

  testWidgets('report and block controls are labelled in the conversation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Fake(), page));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(find.text('Report conversation'), findsOneWidget);
    expect(find.text('Report Rana Haddad'), findsOneWidget);
    expect(find.text('Block Rana Haddad'), findsOneWidget);
    expect(find.text('Blocked people'), findsOneWidget);
  });

  testWidgets('a message can be reported with a long press', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(_app(fake, page));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Please see me after class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bullying or harassment'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(fake.reports.single['target'], ReportTarget.message);
    expect(fake.reports.single['messageId'], 'message-1');
    expect(fake.reports.single['subjectUserId'], _teacher);
    expect(
      (fake.reports.single['details']! as String).length,
      greaterThanOrEqualTo(10),
    );
    expect(find.text('Report sent. Thank you for telling us.'), findsOneWidget);
  });

  testWidgets('blocking hides the composer and can be undone', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(_app(fake, page));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(find.text('Block Rana Haddad'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();
    expect(fake.blockList.single.blockedId, _teacher);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.textContaining('You blocked someone'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        fake,
        const BlockedPeoplePage(
          schoolId: _school,
          myUserId: _me,
          knownPeople: {_teacher: 'Rana Haddad'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rana Haddad'), findsOneWidget);
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(fake.blockList, isEmpty);
  });

  testWidgets('a block made by the other person is not attributed or listed', (
    tester,
  ) async {
    final fake = _Fake()
      ..blockList.add(
        BlockedPerson(
          blockId: 'theirs',
          schoolId: _school,
          blockerId: _teacher,
          blockedId: _me,
          createdAt: DateTime(2026),
        ),
      );
    await tester.pumpWidget(_app(fake, page));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.textContaining('You blocked someone'), findsNothing);

    await tester.pumpWidget(
      _app(fake, const BlockedPeoplePage(schoolId: _school, myUserId: _me)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unblock'), findsNothing);
    expect(find.text('You have not blocked anyone.'), findsOneWidget);
  });

  testWidgets('a failed send retries with the same client message id', (
    tester,
  ) async {
    final fake = _Fake()..failNextSend = true;
    await tester.pumpWidget(_app(fake, page));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thank you');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Not sent. Tap send to try again.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(fake.sentClientIds, hasLength(2));
    expect(fake.sentClientIds.first, fake.sentClientIds.last);
    expect(find.text('Thank you'), findsOneWidget);
  });

  testWidgets('the report sheet is fully translated in Arabic', (tester) async {
    await tester.pumpWidget(_app(_Fake(), page, locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    expect(find.text('الإبلاغ عن المحادثة'), findsOneWidget);
    await tester.tap(find.text('الإبلاغ عن المحادثة'));
    await tester.pumpAndSettle();
    expect(find.text('إرسال البلاغ'), findsOneWidget);
    expect(find.text('Send report'), findsNothing);
  });
}

// A const alias so the page can be const in tests.
const _conversationRef = _ConstConversation();

class _ConstConversation implements Conversation {
  const _ConstConversation();
  @override
  String get id => _conversation.id;
  @override
  String get schoolId => _conversation.schoolId;
  @override
  String? get subject => _conversation.subject;
  @override
  List<ConversationParticipant> get participants => _conversation.participants;
  @override
  DateTime get updatedAt => _conversation.updatedAt;
  @override
  DateTime? get lastReadAt => _conversation.lastReadAt;
  @override
  List<ConversationParticipant> others(String myUserId) =>
      _conversation.others(myUserId);
  @override
  bool get hasUnread => _conversation.hasUnread;
  @override
  String? participantName(String userId) =>
      _conversation.participantName(userId);
}
