import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/core/ids.dart';
import 'package:studafy/core/runtime_environment.dart';
import 'package:studafy/core/studafy_domain.dart';
import 'package:studafy/core/telemetry.dart';
import 'package:studafy/features/session/application/session_interactor.dart';
import 'package:studafy/features/session/domain/session_repository.dart';
import 'package:studafy/features/session/presentation/login_page.dart';
import 'package:studafy/features/session/presentation/password_reauth_dialog.dart';
import 'package:studafy/features/session/presentation/role_page.dart';

import '../../support/localized_app.dart';
import '../../support/session_repository_fake.dart';

const _urlLauncher = MethodChannel('plugins.flutter.io/url_launcher');

/// The secondary "Sign in with email" path: how the app store reviewers get
/// in with the demo accounts Studafy provisions (docs/store/reviewer-access.md).
/// It must be visible in every build, offer no sign-up or reset, and say
/// plainly what went wrong - in English and in Arabic.
void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, (call) async => true);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, null);
    ActiveContextController.instance.signOut();
  });

  Future<_PasswordAccounts> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    PasswordSignInError? failWith,
    StudafyEnvironment environment = StudafyEnvironment.development,
  }) async {
    final policy = RuntimePolicy(environment);
    StudafyRuntime.initialize(policy);
    final repository = _PasswordAccounts(failWith: failWith);
    addTearDown(repository.close);
    final session = SessionInteractor(
      repository: repository,
      context: ActiveContextController.instance,
      telemetry: const NoopTelemetry(),
      runtimePolicy: policy,
    );
    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        home: LoginPage(role: UserRole.teacher, session: session),
        routes: {
          '/teacher': (_) => const Text('teacher home'),
          '/onboarding': (_) => const Text('teacher setup'),
        },
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> acceptTerms(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    final button = find.byKey(const Key('loginWithEmail'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester tester, {
    String email = 'teacher@review.studafy.com',
    String password = 'correct horse',
  }) async {
    await tester.enterText(find.byKey(const Key('emailSignInAddress')), email);
    await tester.enterText(
      find.byKey(const Key('emailSignInPassword')),
      password,
    );
    await tester.tap(find.byKey(const Key('emailSignInSubmit')));
    await tester.pumpAndSettle();
  }

  String? errorText(WidgetTester tester) {
    final error = find.byKey(const Key('emailSignInError'));
    if (error.evaluate().isEmpty) return null;
    return tester.widget<Text>(error).data;
  }

  testWidgets('the email option is on the sign-in screen, under the '
      'providers, as a button a screen reader can find', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    final button = find.byKey(const Key('loginWithEmail'));
    expect(button, findsOneWidget);
    expect(find.text('Sign in with email'), findsOneWidget);
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getTopLeft(find.text('Continue with Google')).dy),
    );
    // Below the terms, so on this short test surface it is scrolled to.
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Sign in with email',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('it waits for the terms like every other way in', (tester) async {
    await pump(tester);
    await openSheet(tester);
    expect(find.byKey(const Key('emailSignInAddress')), findsNothing);
    final reminder = tester.widget<Text>(
      find.text('Please accept before signing in.'),
    );
    expect(reminder.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('the sheet is for provisioned accounts only: no sign-up and '
      'no password reset', (tester) async {
    await pump(tester);
    await acceptTerms(tester);
    await openSheet(tester);
    expect(find.text('For accounts set up by Studafy.'), findsOneWidget);
    expect(find.byKey(const Key('emailSignInAddress')), findsOneWidget);
    expect(find.byKey(const Key('emailSignInPassword')), findsOneWidget);
    expect(
      find.textContaining(
        RegExp('create|sign up|forgot|reset', caseSensitive: false),
      ),
      findsNothing,
    );
    final password = tester.widget<TextField>(
      find.byKey(const Key('emailSignInPassword')),
    );
    expect(password.obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('emailSignInPassword')))
          .obscureText,
      isFalse,
    );
  });

  testWidgets('missing or malformed input is caught before any request', (
    tester,
  ) async {
    final repository = await pump(tester);
    await acceptTerms(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('emailSignInSubmit')));
    await tester.pumpAndSettle();
    expect(errorText(tester), 'Enter your email address.');

    await submit(tester, email: 'teacher', password: 'x');
    expect(errorText(tester), 'Enter a valid email address.');

    await submit(tester, password: '');
    expect(errorText(tester), 'Enter your password.');
    expect(repository.attempts, isEmpty);
  });

  testWidgets('a wrong password says so and clears only the password', (
    tester,
  ) async {
    final repository = await pump(
      tester,
      failWith: PasswordSignInError.invalidCredentials,
    );
    await acceptTerms(tester);
    await openSheet(tester);
    await submit(tester, email: '  teacher@review.studafy.com ');
    expect(
      errorText(tester),
      "That email and password don't match an account set up by Studafy.",
    );
    expect(repository.attempts, ['teacher@review.studafy.com']);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller!.text, '  teacher@review.studafy.com ');
    expect(fields.last.controller!.text, isEmpty);
    expect(find.text('teacher home'), findsNothing);
  });

  for (final (failure, message) in [
    (
      PasswordSignInError.tooManyAttempts,
      'Too many attempts. Wait a few minutes, then try again.',
    ),
    (
      PasswordSignInError.network,
      "Couldn't reach Studafy. Check your connection and try again.",
    ),
    (
      PasswordSignInError.unavailable,
      "Email sign-in isn't available right now. Please try again later.",
    ),
  ]) {
    testWidgets('${failure.name} is explained', (tester) async {
      await pump(tester, failWith: failure);
      await acceptTerms(tester);
      await openSheet(tester);
      await submit(tester);
      expect(errorText(tester), message);
    });
  }

  testWidgets('a right password closes the sheet and signs in like any '
      'provider', (tester) async {
    final repository = await pump(tester);
    await acceptTerms(tester);
    await openSheet(tester);
    await submit(tester);
    expect(repository.attempts, ['teacher@review.studafy.com']);
    expect(find.byKey(const Key('emailSignInAddress')), findsNothing);
    expect(find.text('teacher home'), findsOneWidget);
    expect(
      ActiveContextController.instance.membership?.role,
      StudafyRole.teacher,
    );
  });

  testWidgets('in Arabic, the option, the sheet and its errors are '
      'translated and laid out right to left', (tester) async {
    await pump(
      tester,
      locale: const Locale('ar'),
      failWith: PasswordSignInError.invalidCredentials,
    );
    expect(find.text('تسجيل الدخول بالبريد الإلكتروني'), findsOneWidget);
    await acceptTerms(tester);
    await openSheet(tester);
    expect(find.text('للحسابات التي أعدّتها Studafy.'), findsOneWidget);
    expect(
      directionOf(tester, find.text('للحسابات التي أعدّتها Studafy.')),
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(const Key('emailSignInSubmit')));
    await tester.pumpAndSettle();
    expect(errorText(tester), 'أدخل عنوان بريدك الإلكتروني.');

    await submit(tester);
    expect(
      errorText(tester),
      'البريد الإلكتروني وكلمة المرور لا يطابقان حسابًا أعدّته Studafy.',
    );
    // An address is typed left to right whatever the language.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('emailSignInAddress')))
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('a synthetic build has no server, so it opens the demo as '
      'the provider buttons do', (tester) async {
    final repository = await pump(
      tester,
      environment: StudafyEnvironment.synthetic,
    );
    await acceptTerms(tester);
    await openSheet(tester);
    expect(find.byKey(const Key('emailSignInAddress')), findsNothing);
    expect(find.text('teacher home'), findsOneWidget);
    expect(repository.attempts, isEmpty);
  });

  group('asking a password account for its password again', () {
    Future<Future<String?>> open(WidgetTester tester, Locale locale) async {
      late BuildContext captured;
      await tester.pumpWidget(
        localizedApp(
          locale: locale,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final answer = showPasswordReauthDialog(
        captured,
        'parent@review.studafy.com',
      );
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('hands back what was typed', (tester) async {
      final answer = await open(tester, const Locale('en'));
      expect(
        find.text('Enter the password for parent@review.studafy.com.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('reauthPasswordConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('Enter your password.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reauthPassword')), 'pw');
      await tester.tap(find.byKey(const Key('reauthPasswordConfirm')));
      await tester.pumpAndSettle();
      expect(await answer, 'pw');
    });

    testWidgets('and nothing when cancelled, in Arabic too', (tester) async {
      final answer = await open(tester, const Locale('ar'));
      expect(find.text('تأكيد هويتك'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });
  });
}

/// A teacher account that signs in with a password, or fails as told.
class _PasswordAccounts extends FakeSessionRepositoryBase {
  _PasswordAccounts({this.failWith});

  final PasswordSignInError? failWith;
  final _sessions = StreamController<bool>.broadcast();
  final attempts = <String>[];
  bool _signedIn = false;

  @override
  bool get hasCurrentSession => _signedIn;
  @override
  String? get currentUserId => _signedIn ? 'teacher-1' : null;
  @override
  Stream<bool> get sessionChanges => _sessions.stream;

  Future<void> close() async {
    await _sessions.close();
    await closeLifecycle();
  }

  @override
  Future<void> signInWithProvider(LoginProvider provider) async {}

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    attempts.add(email.trim());
    final failure = failWith;
    if (failure != null) throw PasswordSignInException(failure);
    _signedIn = true;
    _sessions.add(true);
  }

  @override
  Future<TermInfo?> activeTermForSchool(SchoolId school) async => null;

  @override
  Future<UserProfile?> currentProfile() async => const UserProfile(
    id: 'teacher-1',
    displayName: 'Review Teacher',
    email: 'teacher@review.studafy.com',
    accountKind: AccountKind.adult,
    memberships: [
      SchoolMembership(
        id: 'membership-1',
        schoolId: 'school-1',
        schoolName: 'Cedar Grove Review School',
        role: StudafyRole.teacher,
        active: true,
      ),
    ],
  );
}
