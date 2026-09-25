import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/app/account_hub_page.dart';
import 'package:studafy/app/account_scope.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/studafy_localizations.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/account/application/account_interactor.dart';
import 'package:studafy/features/account/domain/account_repository.dart';
import 'package:studafy/features/academic/data/preview_academic_repository.dart';
import 'package:studafy/features/family/application/family_interactor.dart';
import 'package:studafy/features/family/domain/family.dart';
import 'package:studafy/features/family/presentation/family_scope.dart';
import 'package:studafy/parent_features.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/l10n/generated/app_l10n.dart';

import 'support/session_repository_fake.dart';

/// Apple 5.1.1(v) / Google Play: sign-out must be reachable in every role
/// shell, guardians included.
class _Account implements AccountRepository {
  @override
  Future<DeletionImpact> deletionImpact() => throw UnimplementedError();
  @override
  Future<DeletionRequest> requestAccountDeletion({
    required String reasonCode,
  }) => throw UnimplementedError();
  @override
  Future<bool> cancelAccountDeletion() async => false;
}

class _Family implements FamilyRepository, PurchaseApprovalRepository {
  @override
  Future<List<GuardianChild>> children() async => const [];
  @override
  Future<LocatedStudent?> locate(
    String studafyId, {
    String? captchaToken,
  }) async => null;
  @override
  Future<GuardianChild> requestLink(String studentId, {String? relationship}) =>
      throw UnimplementedError();
  @override
  Future<ChildProgress> progress(String studentId) =>
      throw UnimplementedError();
  @override
  Future<List<PurchaseApprovalRequest>> pending() async => const [];
  @override
  Future<void> decide(String approvalId, {required bool approve}) async {}
}

class _Session extends FakeSessionRepositoryBase {
  _Session({this.failServerCall = false});

  /// Stands for the real repository's server leg failing: offline, 5xx, or a
  /// token the API would not accept any more.
  final bool failServerCall;

  @override
  bool get hasCurrentSession => true;
  @override
  Stream<bool> get sessionChanges => const Stream<bool>.empty();
  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}
  @override
  Future<UserProfile?> currentProfile() async => null;

  @override
  Future<void> signOut({
    SignOutScope scope = SignOutScope.currentDevice,
  }) async {
    if (failServerCall) throw StateError('sign-out endpoint unreachable');
    return super.signOut(scope: scope);
  }
}

Future<void> _pumpParentShell(WidgetTester tester, _Session repository) async {
  StudafyRuntime.initialize(const RuntimePolicy(StudafyEnvironment.synthetic));
  final session = SessionInteractor(
    repository: repository,
    context: ActiveContextController.instance,
    telemetry: const NoopTelemetry(),
    runtimePolicy: const RuntimePolicy(StudafyEnvironment.synthetic),
  );
  final family = _Family();

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: StudafyLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        StudafyLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => SessionScope(
        session: session,
        child: AccountScope(
          account: AccountInteractor(_Account()),
          child: FamilyScope(
            interactor: FamilyInteractor(
              family: family,
              approvals: family,
              confirmRecentAuth: () async {},
              telemetry: const NoopTelemetry(),
            ),
            child: child!,
          ),
        ),
      ),
      routes: {'/roles': (_) => const Text('Roles')},
      home: ParentShell(academic: PreviewAcademicRepository()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => ActiveContextController.instance.signOut());

  testWidgets('a guardian can reach sign out from the parent shell', (
    tester,
  ) async {
    final repository = _Session();
    await _pumpParentShell(tester, repository);

    expect(find.byIcon(Icons.account_circle_outlined), findsWidgets);
    await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(repository.signOutScopes, isNotEmpty);
    expect(find.text('Roles'), findsOneWidget);
  });

  testWidgets('a guardian is signed out even when the server call fails', (
    tester,
  ) async {
    // The dead-button case: the API leg threw, so nothing cleared and nothing
    // navigated. Leaving must not depend on the network being up.
    final repository = _Session(failServerCall: true);
    await _pumpParentShell(tester, repository);

    await tester.tap(find.byIcon(Icons.account_circle_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Roles'), findsOneWidget);
    expect(ActiveContextController.instance.role, isNull);
  });
}
