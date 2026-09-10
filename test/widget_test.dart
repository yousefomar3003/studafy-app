import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/session/presentation/splash_page.dart';
import 'package:studafy/main.dart';

void main() {
  testWidgets('splash transitions to role selection', (tester) async {
    await tester.pumpWidget(const StudafyApp());
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('How will you use Studafy?'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('School administrator'), findsNothing);
  });
}
