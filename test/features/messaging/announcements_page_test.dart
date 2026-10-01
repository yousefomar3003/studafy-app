import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/messaging/application/messaging_interactor.dart';
import 'package:studafy/features/messaging/domain/messaging.dart';
import 'package:studafy/features/messaging/presentation/announcements_page.dart';
import 'package:studafy/features/messaging/presentation/messaging_scope.dart';

import '../../support/localized_app.dart';

/// A parent's Announcements: every school their children attend, each item
/// saying where it came from, a filter by child, and nothing to post with.
void main() {
  testWidgets('announcements from each school, labelled, filtered by child', (
    tester,
  ) async {
    final repository = _Schools();
    await tester.pumpWidget(
      localizedApp(
        scopes: (child) => MessagingScope(
          interactor: MessagingInteractor(
            messaging: repository,
            safety: _NoSafety(),
            telemetry: const NoopTelemetry(),
          ),
          child: child,
        ),
        home: const AnnouncementsPage(
          sources: [
            AnnouncementSource(
              schoolId: 'noor',
              schoolName: 'Al-Noor',
              children: {'layla': 'Layla'},
            ),
            AnnouncementSource(
              schoolId: 'river',
              schoolName: 'Riverside',
              children: {'omar': 'Omar'},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.asked, unorderedEquals(['noor', 'river']));
    expect(find.text('Trip on Thursday'), findsOne);
    expect(find.text('Sports day'), findsOne);
    expect(find.textContaining('Al-Noor'), findsOne);
    // Reading only: no way to post one here.
    expect(find.textContaining('New announcement'), findsNothing);

    repository.asked.clear();
    await tester.tap(find.text('Omar'));
    await tester.pumpAndSettle();
    expect(repository.asked, ['river']);
    expect(find.text('Trip on Thursday'), findsNothing);
    expect(find.text('Sports day'), findsOne);
  });
}

class _Schools implements MessagingRepository {
  final asked = <String?>[];

  @override
  Future<List<Announcement>> announcements({
    String? schoolId,
    String? classroomId,
  }) async {
    asked.add(schoolId);
    return [
      Announcement(
        id: 'a-$schoolId',
        title: schoolId == 'noor' ? 'Trip on Thursday' : 'Sports day',
        body: '',
        important: false,
        createdAt: DateTime(2026, 10, 1),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoSafety implements SafetyRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
