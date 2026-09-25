import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_bootstrap.dart';
import 'app/account_hub_page.dart';
import 'app/account_scope.dart';
import 'app/app_dependencies.dart';
import 'app/class_join_link_guard.dart';
import 'app/onboarding_page.dart';
import 'app/class_join_link_listener.dart';
import 'app/oauth_callback_guard.dart';
import 'app/studafy_theme.dart';
import 'app/teacher_shell.dart';
import 'core/app_routes.dart';
import 'core/locale_controller.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'l10n/generated/app_l10n.dart';
import 'features/family/presentation/family_scope.dart';
import 'features/messaging/presentation/messaging_scope.dart';
import 'features/notifications/presentation/notifications_scope.dart';
import 'features/parent/presentation/parent_repository_scope.dart';
import 'features/session/presentation/role_page.dart';
import 'features/session/presentation/splash_page.dart';
import 'features/teacher_dashboard/presentation/teacher_dashboard_repository_scope.dart';
import 'parent_features.dart';
import 'student_features.dart';
import 'core/uploads_scope.dart';

/// Holds a class join link tapped before the app had somewhere to show it.
final classJoinLinks = ClassJoinLinkGuard();

final _navigatorKey = GlobalKey<NavigatorState>();

const navy = Color(0xFF241D73),
    cyan = Color(0xFF20C6E8),
    ink = Color(0xFF171441),
    muted = Color(0xFF8D94AF),
    canvas = Color(0xFFF7F6FE);

/// Locale delegates every entry point needs: Studafy's own generated copy,
/// plus Material, Widgets and Cupertino, which supply the built-in component
/// strings and the right-to-left direction for Arabic.
const _localizationsDelegates = <LocalizationsDelegate<Object>>[
  AppL10n.delegate,
  StudafyLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Registered before runApp so it precedes the observer WidgetsApp installs
  // and is offered the provider callback first.
  WidgetsBinding.instance.addObserver(OAuthCallbackGuard());
  // Same reason: nothing routes a class join link either, so it is claimed
  // before WidgetsApp can try to push it as a named route.
  WidgetsBinding.instance.addObserver(classJoinLinks);
  late final RuntimePolicy runtimePolicy;
  try {
    runtimePolicy = RuntimePolicy.fromEnvironment();
  } on FormatException {
    runApp(
      // No composition root exists yet, so this one reason cannot come from
      // the localizations; the page translates the rest.
      const StudafyConfigurationBlockedApp(),
    );
    return;
  }
  StudafyRuntime.initialize(runtimePolicy);
  if (runtimePolicy.blocksApplicationStartup) {
    runApp(StudafyApp(runtimePolicy: runtimePolicy));
    return;
  }
  try {
    final dependencies = await AppBootstrap.initialize(runtimePolicy);
    runApp(
      StudafyApp(runtimePolicy: runtimePolicy, dependencies: dependencies),
    );
  } on StateError catch (error) {
    runApp(StudafyConfigurationBlockedApp(reason: error.message));
  }
}

class StudafyApp extends StatelessWidget {
  const StudafyApp({
    super.key,
    this.runtimePolicy = const RuntimePolicy(StudafyEnvironment.synthetic),
    this.dependencies,
  });

  final RuntimePolicy runtimePolicy;

  /// Composition root output; built lazily when omitted so plain test pumps
  /// of [StudafyApp] work without constructing adapters.
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext c) {
    // A blocked build renders only the readiness page, so it constructs no
    // adapters at all. Building the composition root anyway would make the
    // containment page depend on backend configuration it must never need.
    final deps = runtimePolicy.blocksApplicationStartup
        ? null
        : (dependencies ?? AppDependencies.forPolicy(runtimePolicy));
    final routes = deps == null
        ? <String, WidgetBuilder>{}
        : <String, WidgetBuilder>{
            rolesRoute: (_) => RolePage(session: deps.session),
            // The role arrives as a route argument because the person already
            // chose it on RolePage; onboarding only has to explain one step.
            onboardingRoute: (context) => OnboardingPage(
              role:
                  ModalRoute.of(context)?.settings.arguments as UserRole? ??
                  UserRole.student,
              session: deps.session,
              classes: deps.classes,
              teacherWorkspace: deps.teacherWorkspace,
            ),
            teacherRoute: (_) => TeacherShell(dependencies: deps),
            parentRoute: (_) => ParentShell(
              academic: deps.academic,
              insights: deps.familyInsights,
            ),
            studentRoute: (_) => StudentShell(
              academic: deps.academic,
              classes: deps.classes,
              notebookSubscription: deps.notebookSubscription,
              session: deps.session,
              studyAssistant: deps.studyAssistant,
              fileUploads: deps.fileUploads,
            ),
          };
    // A blocked build has no composition root, so it has no locale controller
    // either; it still needs the delegates and the device's own language.
    final locale = deps?.locale;
    return ListenableBuilder(
      listenable: locale ?? Listenable.merge(const []),
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Studafy',
        theme: studafyTheme(),
        supportedLocales: kSupportedLocales,
        // The controller is the single authority: it also decides the code
        // published to the profile, so the rendered language and the one the
        // server sends email and push in can never drift apart. It observes
        // the binding, so a system language change still reaches here.
        locale: locale?.resolvedLocale,
        localeResolutionCallback: (device, _) =>
            matchSupportedLocale(device == null ? null : [device]) ??
            kFallbackLocale,
        localizationsDelegates: _localizationsDelegates,
        navigatorKey: _navigatorKey,
        routes: routes,
        builder: (context, child) {
          Widget content = child ?? const SizedBox.shrink();
          if (runtimePolicy.isSynthetic) {
            content = Column(
              children: [
                Material(
                  color: const Color(0xFFFFE0A3),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 30,
                      child: Center(
                        child: Text(
                          AppL10n.of(context).syntheticBanner,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF5E3B00),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            );
          }
          if (deps == null) return content;
          content = ClassJoinLinkListener(
            guard: classJoinLinks,
            classes: deps.classes,
            session: deps.session,
            navigatorKey: _navigatorKey,
            child: content,
          );
          // Outermost, because feature presentation opens the language picker
          // and must reach the controller from anywhere in the tree.
          return LocaleScope(
            controller: deps.locale,
            child: SessionScope(
              session: deps.session,
              child: AccountScope(
                account: deps.account,
                // Above the Navigator, so a pushed conversation or hand-in
                // screen can still reach the upload pipeline.
                child: UploadsScope(
                  uploads: deps.fileUploads,
                  child: NotificationsScope(
                    interactor: deps.notifications,
                    child: MessagingScope(
                      interactor: deps.messaging,
                      child: FamilyScope(
                        interactor: deps.family,
                        child: ParentRepositoryScope(
                          repository: deps.parent,
                          subscription: deps.parentSubscription,
                          signOut: deps.session.signOut,
                          isRemote: runtimePolicy.requiresRemoteBackend,
                          child: TeacherDashboardRepositoryScope(
                            repository: deps.teacherDashboard,
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        home: runtimePolicy.blocksApplicationStartup
            ? const ProductionReadinessBlockedPage()
            : const SplashPage(),
      ),
    );
  }
}

class StudafyConfigurationBlockedApp extends StatelessWidget {
  const StudafyConfigurationBlockedApp({super.key, this.reason});

  /// Why the build is blocked, when the caller can say. Null falls back to
  /// the localized invalid-environment message, because this runs before any
  /// localizations are available to the caller.
  final String? reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    // This runs before the composition root exists, so there is no stored
    // preference to read: it follows the device only. Without the delegates
    // it rendered English left-to-right even on an Arabic phone.
    supportedLocales: kSupportedLocales,
    localeResolutionCallback: (device, _) =>
        matchSupportedLocale(device == null ? null : [device]) ??
        kFallbackLocale,
    localizationsDelegates: _localizationsDelegates,
    home: ProductionReadinessBlockedPage(reason: reason),
  );
}

class ProductionReadinessBlockedPage extends StatelessWidget {
  const ProductionReadinessBlockedPage({super.key, this.reason});

  /// An explicit reason, or null for the general one. Nullable rather than a
  /// default string because the default has to come from the localizations,
  /// which need a BuildContext.
  final String? reason;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 54, color: navy),
                const SizedBox(height: 18),
                Text(
                  AppL10n.of(context).blockedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason ?? AppL10n.of(context).blockedDefaultReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  AppL10n.of(context).blockedReference,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
