import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/features/session/presentation/role_page.dart';
import 'package:studafy/features/session/presentation/splash_page.dart';
import 'package:studafy/main.dart';

void main() {
  group('SEC-001 runtime policy', () {
    test('accepts every named environment', () {
      expect(
        RuntimePolicy.parse('synthetic').environment,
        StudafyEnvironment.synthetic,
      );
      expect(
        RuntimePolicy.parse('development').environment,
        StudafyEnvironment.development,
      );
      expect(
        RuntimePolicy.parse('staging').environment,
        StudafyEnvironment.staging,
      );
      expect(
        RuntimePolicy.parse('production').environment,
        StudafyEnvironment.production,
      );
    });

    test('rejects unknown environments', () {
      expect(() => RuntimePolicy.parse('prod'), throwsFormatException);
      expect(() => RuntimePolicy.parse(''), throwsFormatException);
    });

    test('AI grading stays off in every environment', () {
      // ADR-0026 removed it. No later change may turn this on as a side
      // effect of enabling something else.
      for (final environment in StudafyEnvironment.values) {
        expect(RuntimePolicy(environment).allowsAiGrading, isFalse);
      }
    });

    test('uploads are on everywhere except production', () {
      // FILE-050/051 shipped the scanning and delivery pipeline, so the
      // client adapter is wired. Production stays off until an external
      // malware provider is contracted - the worker fails closed without
      // one, and the app should not offer a control that cannot work.
      for (final environment in StudafyEnvironment.values) {
        expect(
          RuntimePolicy(environment).allowsRemoteFileUploads,
          environment != StudafyEnvironment.production,
          reason: 'environment: ${environment.name}',
        );
      }
    });

    test('only production blocks application startup', () {
      for (final environment in StudafyEnvironment.values) {
        expect(
          RuntimePolicy(environment).blocksApplicationStartup,
          environment == StudafyEnvironment.production,
        );
      }
    });

    test('synthetic mode cannot initialize a remote backend', () {
      expect(
        const RuntimePolicy(StudafyEnvironment.synthetic).requiresRemoteBackend,
        isFalse,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.development)
            .requiresRemoteBackend,
        isTrue,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.staging).requiresRemoteBackend,
        isTrue,
      );
      expect(
        const RuntimePolicy(StudafyEnvironment.production)
            .requiresRemoteBackend,
        isFalse,
      );
    });
  });

  testWidgets('production renders only the readiness block', (tester) async {
    await tester.pumpWidget(
      const StudafyApp(
        runtimePolicy: RuntimePolicy(StudafyEnvironment.production),
      ),
    );
    await tester.pump();

    expect(find.text('Studafy is not production-ready'), findsOneWidget);
    expect(find.text('Reference: SEC-001'), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(RolePage), findsNothing);
  });

  testWidgets('synthetic mode displays the real-data warning', (tester) async {
    await tester.pumpWidget(const StudafyApp());
    await tester.pump();
    expect(
      find.text('SYNTHETIC DATA — NOT FOR REAL SCHOOL USE'),
      findsOneWidget,
    );
  });
}
