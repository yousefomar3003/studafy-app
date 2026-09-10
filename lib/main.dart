import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_bootstrap.dart';
import 'app/app_dependencies.dart';
import 'app/teacher_shell.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'features/parent/presentation/parent_repository_scope.dart';
import 'features/session/presentation/role_page.dart';
import 'features/session/presentation/splash_page.dart';
import 'features/study_coach/presentation/study_coach_scope.dart';
import 'features/teacher_dashboard/presentation/teacher_dashboard_repository_scope.dart';
import 'parent_features.dart';
import 'student_features.dart';

const navy = Color(0xFF241D73),
    cyan = Color(0xFF20C6E8),
    ink = Color(0xFF171441),
    muted = Color(0xFF8D94AF),
    canvas = Color(0xFFF7F6FE);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final RuntimePolicy runtimePolicy;
  try {
    runtimePolicy = RuntimePolicy.fromEnvironment();
  } on FormatException {
    runApp(
      const StudafyConfigurationBlockedApp(
        reason: 'Invalid APP_ENV. This build has been blocked for safety.',
      ),
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
    final deps = dependencies ?? AppDependencies.forPolicy(runtimePolicy);
    final routes = runtimePolicy.blocksApplicationStartup
        ? <String, WidgetBuilder>{}
        : <String, WidgetBuilder>{
            '/roles': (_) => RolePage(session: deps.session),
            '/teacher': (_) => TeacherShell(dependencies: deps),
            '/parent': (_) => const ParentShell(),
            '/student': (_) => const StudentShell(),
          };
    return ListenableBuilder(
      listenable: StudafyLocaleController.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Studafy',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(
            seedColor: navy,
            primary: navy,
            secondary: cyan,
            tertiary: const Color(0xFFFF6B6B),
            surface: Colors.white,
          ),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: ink),
            titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
            titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
            bodyMedium: TextStyle(color: ink, height: 1.35),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCE0EE)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: .1,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              side: const BorderSide(color: Color(0xFFD8DCEC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: cyan.withValues(alpha: .08),
            selectedColor: const Color(0xFF7737EE).withValues(alpha: .15),
            side: BorderSide(color: cyan.withValues(alpha: .16)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            labelStyle: const TextStyle(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
          ),
        ),
        supportedLocales: StudafyLocalizations.supportedLocales,
        locale: StudafyLocaleController.instance.locale,
        localizationsDelegates: const [
          StudafyLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
                          'SYNTHETIC DATA — NOT FOR REAL SCHOOL USE',
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
          return ParentRepositoryScope(
            repository: deps.parent,
            subscription: deps.parentSubscription,
            signOut: deps.session.signOut,
            isRemote: runtimePolicy.requiresRemoteBackend,
            child: TeacherDashboardRepositoryScope(
              repository: deps.teacherDashboard,
              child: StudyCoachScope(
                interactor: deps.studyCoach,
                child: content,
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
  const StudafyConfigurationBlockedApp({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ProductionReadinessBlockedPage(reason: reason),
  );
}

class ProductionReadinessBlockedPage extends StatelessWidget {
  const ProductionReadinessBlockedPage({
    super.key,
    this.reason = 'Production access is blocked until security and data-integrity gates pass.',
  });

  final String reason;

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
                const Text(
                  'Studafy is not production-ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Reference: SEC-001',
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
