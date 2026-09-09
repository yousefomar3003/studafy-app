import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/studafy_design.dart';
import 'core/studafy_domain.dart';
import 'core/studafy_localizations.dart';
import 'core/runtime_environment.dart';
import 'data/backend.dart';
import 'data/supabase_repository.dart';
import 'studafy_database.dart';
import 'teacher_features.dart';
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
  if (runtimePolicy.requiresRemoteBackend &&
      !BackendConfig.fromEnvironment.isConfigured) {
    runApp(
      const StudafyConfigurationBlockedApp(
        reason: 'Development and staging require an explicitly configured remote backend.',
      ),
    );
    return;
  }
  if (runtimePolicy.requiresRemoteBackend) {
    await StudafyBackend.initialize();
  }
  await StudafyDatabase.instance.database;
  runApp(StudafyApp(runtimePolicy: runtimePolicy));
}

class StudafyApp extends StatelessWidget {
  const StudafyApp({
    super.key,
    this.runtimePolicy = const RuntimePolicy(StudafyEnvironment.synthetic),
  });

  final RuntimePolicy runtimePolicy;

  @override
  Widget build(BuildContext c) {
    final routes = runtimePolicy.blocksApplicationStartup
        ? <String, WidgetBuilder>{}
        : <String, WidgetBuilder>{
            '/roles': (_) => const RolePage(),
            '/teacher': (_) => const TeacherShell(),
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
          if (!runtimePolicy.isSynthetic) {
            return child ?? const SizedBox.shrink();
          }
          return Column(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF5E3B00),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
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

class StudafyLogo extends StatelessWidget {
  const StudafyLogo({super.key, this.size = 46});
  final double size;
  @override
  Widget build(BuildContext c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size * .56,
        height: size * .56,
        margin: EdgeInsets.only(right: size * .05),
        decoration: BoxDecoration(
          color: cyan.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size * .18),
        ),
        child: Icon(Icons.add_rounded, color: cyan, size: size * .45),
      ),
      Text(
        'studafy',
        style: TextStyle(
          fontSize: size,
          height: 1,
          letterSpacing: -2,
          fontWeight: FontWeight.w900,
          color: navy,
        ),
      ),
    ],
  );
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RolePage()),
        );
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => const Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudafyLogo(size: 64),
          SizedBox(height: 18),
          Text(
            'School life, connected.',
            style: TextStyle(color: muted, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

enum UserRole { teacher, student, parent }

class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class RolePage extends StatefulWidget {
  const RolePage({super.key});
  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  UserRole? selected;
  @override
  Widget build(BuildContext c) => AuthFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudafyLogo(size: 36),
        const SizedBox(height: 44),
        Text(
          'How will you use Studafy?',
          style: Theme.of(c).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose your role to personalize your experience.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 32),
        ...UserRole.values.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RoleTile(
              role: r,
              selected: selected == r,
              onTap: () => setState(() => selected = r),
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: selected == null
              ? null
              : () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => LoginPage(role: selected!)),
                ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

class RoleTile extends StatelessWidget {
  const RoleTile({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) {
    final d = switch (role) {
      UserRole.teacher => (
        Icons.school_outlined,
        'Teacher',
        'Manage classes, attendance and learning',
      ),
      UserRole.student => (
        Icons.menu_book_outlined,
        'Student',
        'Learn, submit work and stay updated',
      ),
      UserRole.parent => (
        Icons.family_restroom_outlined,
        'Parent',
        'Follow progress and school updates',
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0EFFF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? navy : const Color(0xFFDCE0EE),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: selected ? navy : canvas,
              child: Icon(d.$1, color: selected ? Colors.white : navy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: ink,
                    ),
                  ),
                  Text(
                    d.$3,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? navy : muted,
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.role});
  final UserRole role;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool accepted = false;
  bool signingIn = false;
  bool completingRemoteLogin = false;
  String? error;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    if (StudafyBackend.isRemote) {
      authSubscription = StudafyBackend.client.auth.onAuthStateChange.listen((
        state,
      ) {
        if (state.session != null) _completeRemoteLogin();
      });
      if (StudafyBackend.client.auth.currentSession != null) {
        _completeRemoteLogin();
      }
    }
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  StudafyRole get selectedRole => switch (widget.role) {
    UserRole.teacher => StudafyRole.teacher,
    UserRole.parent => StudafyRole.parent,
    UserRole.student => StudafyRole.student,
  };

  Future<void> login(OAuthProvider provider) async {
    if (!accepted) return;
    if (StudafyBackend.isRemote) {
      setState(() {
        signingIn = true;
        error = null;
      });
      try {
        await StudafyBackend.client.auth.signInWithOAuth(
          provider,
          redirectTo: 'io.studafy.app://login-callback',
        );
      } catch (caught) {
        if (mounted) {
          setState(() {
            signingIn = false;
            error = '$caught';
          });
        }
      }
      return;
    }
    ActiveContextController.instance.startDemoRole(selectedRole);
    _openRole();
  }

  Future<void> _completeRemoteLogin() async {
    if (!mounted || completingRemoteLogin) return;
    completingRemoteLogin = true;
    try {
      if (accepted) {
        await StudafyBackend.client.rpc(
          'record_policy_consent',
          params: {
            'requested_purpose': 'terms_and_privacy',
            'requested_version': '2026-09-09',
            'requested_locale':
                StudafyLocaleController.instance.locale.languageCode,
          },
        );
      }
      final profile = await SupabaseStudafyRepository().currentProfile();
      final membership = profile?.memberships
          .where((item) => item.active && item.role == selectedRole)
          .firstOrNull;
      if (profile == null || membership == null) {
        await StudafyBackend.client.auth.signOut();
        throw StateError(
          'This account does not have the selected school role.',
        );
      }
      ActiveContextController.instance.hydrate(
        authenticatedProfile: profile,
        activeMembership: membership,
      );
      if (mounted) _openRole();
    } catch (caught) {
      if (mounted) {
        setState(() {
          signingIn = false;
          error = '$caught'.replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      completingRemoteLogin = false;
    }
  }

  void _openRole() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => switch (widget.role) {
          UserRole.teacher => const TeacherShell(),
          UserRole.parent => const ParentShell(),
          UserRole.student => const StudentShell(),
        },
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext c) => AuthFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudafyLogo(size: 36),
        const SizedBox(height: 40),
        Text(
          'Welcome, ${widget.role.name}',
          textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Use your school or personal account to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 30),
        for (final x in [
          ('G', 'Google', OAuthProvider.google),
          ('M', 'Microsoft', OAuthProvider.azure),
          ('●', 'Apple', OAuthProvider.apple),
        ])
          SocialButton(
            mark: x.$1,
            label: 'Continue with ${x.$2}',
            onTap: signingIn ? () {} : () => login(x.$3),
          ),
        if (signingIn)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: accepted,
          onChanged: (v) => setState(() => accepted = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Wrap(
            children: [
              const Text('I agree to the '),
              LinkText(
                'Terms of Use',
                onTap: () => showPolicy(c, 'Terms of Use'),
              ),
              const Text(' and '),
              LinkText(
                'Privacy Policy',
                onTap: () => showPolicy(c, 'Privacy Policy'),
              ),
              const Text('.'),
            ],
          ),
        ),
        if (!accepted)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'Please accept before signing in.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.pop(c),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Change role'),
        ),
      ],
    ),
  );
}

class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.mark,
    required this.onTap,
  });
  final String label, mark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Color(0xFFDCE0EE)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              mark,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
          ),
          Expanded(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 42),
        ],
      ),
    ),
  );
}

class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: onTap,
    child: Text(
      text,
      style: const TextStyle(
        color: navy,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}

void showPolicy(BuildContext c, String title) => showModalBottomSheet(
  context: c,
  showDragHandle: true,
  builder: (c) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 14),
        Text(
          title == 'Privacy Policy'
              ? 'Studafy uses account, school, class, attendance, and communication data only to provide and secure the service. Schools control student records. We do not sell personal data. Contact your school to access, correct, or delete eligible records.'
              : 'Use Studafy only for authorized school communication. Keep accounts secure, respect students and staff, and do not upload harmful or unlawful content. School policies continue to apply. Misuse may lead to account suspension.',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ),
      ],
    ),
  ),
);

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});
  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int index = 0;
  final pages = const [
    TeacherHome(),
    DatabaseClassesPage(),
    ContentPage(),
    GradebookPage(),
    CommsPage(),
  ];
  @override
  Widget build(BuildContext c) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: StudafyNavigationBar(
      selectedIndex: index,
      onSelected: (value) => setState(() => index = value),
      items: [
        StudafyNavItem(
          StudafyLocalizations.of(c).text('today'),
          Icons.home_outlined,
          Icons.home_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(c).text('classes'),
          Icons.diversity_3_outlined,
          Icons.diversity_3_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(c).text('teaching'),
          Icons.auto_stories_outlined,
          Icons.auto_stories_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(c).text('gradebook'),
          Icons.fact_check_outlined,
          Icons.fact_check_rounded,
        ),
        StudafyNavItem(
          StudafyLocalizations.of(c).text('inbox'),
          Icons.forum_outlined,
          Icons.forum_rounded,
        ),
      ],
      accent: navy,
    ),
  );
}

class TeacherHeader extends StatelessWidget {
  const TeacherHeader({super.key, this.title = 'Al-Noor International'});
  final String title;
  @override
  Widget build(BuildContext c) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StudafyLogo(size: 23),
                const SizedBox(height: 5),
                Text(title, style: const TextStyle(color: muted)),
              ],
            ),
          ),
          Badge(
            label: const Text('3'),
            child: IconButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ChatsPage()),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          FutureBuilder<int>(
            future: StudafyDatabase.instance.unreadNotificationCount(),
            builder: (context, snapshot) => Badge(
              isLabelVisible: (snapshot.data ?? 0) > 0,
              backgroundColor: Colors.red,
              label: Text('${snapshot.data ?? 0}'),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
                icon: const Icon(Icons.notifications_none),
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => const MyStudafyPage()),
            ),
            borderRadius: BorderRadius.circular(24),
            child: const CircleAvatar(
              backgroundColor: navy,
              child: Text(
                'RH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Column(
    children: [
      const TeacherHeader(),
      Expanded(
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          child: ListView(
            key: const PageStorageKey('teacher-home-scroll'),
            controller: _scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 48),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good morning, Rana',
                          style: Theme.of(c).textTheme.headlineSmall,
                        ),
                        const Text(
                          'Thursday, August 27',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionTitle("Today's sessions"),
              const SizedBox(height: 12),
              SessionCard(
                time: '08:30–09:20',
                title: 'Biology · Grade 10 B',
                room: 'Lab 2',
                status: 'NOW',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '09:30–10:20',
                title: 'Biology · Grade 9 A',
                room: 'Lab 2',
                status: 'NEXT',
              ),
              const SizedBox(height: 12),
              SessionCard(
                time: '11:00–11:50',
                title: 'Chemistry · Grade 10 A',
                room: 'Lab 1',
                completed: true,
              ),
              const SizedBox(height: 26),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SectionTitle('Pending grading'),
                  Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFF087D99),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    SmallRow(
                      'Photosynthesis lab report',
                      'Grade 10 B',
                      '6 to grade',
                      navy,
                    ),
                    Divider(),
                    SmallRow(
                      'Cell diagram worksheet',
                      'Grade 9 A',
                      '4 to grade',
                      cyan,
                    ),
                    Divider(),
                    SmallRow(
                      'Titration write-up',
                      'Grade 10 A',
                      '2 to grade',
                      Color(0xFF7737EE),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle('Recent submissions'),
              const SizedBox(height: 12),
              const InfoCard(
                child: Column(
                  children: [
                    StudentRow(
                      'LH',
                      'Layla Hassan',
                      'Photosynthesis report · 18 min ago',
                    ),
                    Divider(),
                    StudentRow(
                      'OF',
                      'Omar Fathy',
                      'Photosynthesis report · 1 hour ago',
                    ),
                    Divider(),
                    StudentRow(
                      'MA',
                      'Mariam Adel',
                      'Cell diagram worksheet · Late',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.time,
    required this.title,
    required this.room,
    this.status,
    this.completed = false,
  });
  final String time, title, room;
  final String? status;
  final bool completed;
  @override
  Widget build(BuildContext c) => InfoCard(
    accent: status != null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              time,
              style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
            if (status != null) ...[
              const SizedBox(width: 9),
              Chip(
                label: Text(status!),
                visualDensity: VisualDensity.compact,
                backgroundColor: navy,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                side: BorderSide.none,
              ),
            ],
          ],
        ),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: ink,
          ),
        ),
        Text(room, style: const TextStyle(color: muted)),
        const SizedBox(height: 16),
        if (!completed)
          FilledButton(
            onPressed: () => showAttendance(c, title),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Take attendance'),
          )
        else ...[
          const Wrap(
            spacing: 8,
            children: [
              Pill('Attendance recorded', true),
              Pill('Notebook missing', false),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showNotebook(c, title),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Add lesson notebook'),
          ),
        ],
      ],
    ),
  );
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child, this.accent = false});
  final Widget child;
  final bool accent;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border(
        left: BorderSide(color: accent ? navy : Colors.transparent, width: 4),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B171441),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext c) => Text(
    text,
    style: const TextStyle(
      color: ink,
      fontWeight: FontWeight.w800,
      fontSize: 20,
    ),
  );
}

class Pill extends StatelessWidget {
  const Pill(this.text, this.good, {super.key});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: good ? const Color(0xFFD8FAE9) : const Color(0xFFFFE4E6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: good ? const Color(0xFF16875B) : const Color(0xFFD33A47),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class SmallRow extends StatelessWidget {
  const SmallRow(
    this.title,
    this.subtitle,
    this.trailing,
    this.color, {
    super.key,
  });
  final String title, subtitle, trailing;
  final Color color;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(width: 3, height: 38, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F9FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF087D99),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class StudentRow extends StatelessWidget {
  const StudentRow(this.initials, this.name, this.detail, {super.key});
  final String initials, name, detail;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: navy,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              Text(detail, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
        const Pill('New', true),
      ],
    ),
  );
}

class ClassesPage extends StatelessWidget {
  const ClassesPage({super.key});
  @override
  Widget build(BuildContext c) => Column(
    children: [
      const TeacherHeader(title: 'My classes'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionTitle('Classes'),
                FilledButton.icon(
                  onPressed: () => showCreateClass(c),
                  icon: const Icon(Icons.add),
                  label: const Text('Create a new classroom'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final x in [
              ('Biology', 'Grade 10 · Section B', '28 students', cyan),
              ('Biology', 'Grade 9 · Section A', '25 students', navy),
              (
                'Chemistry',
                'Grade 10 · Section A',
                '27 students',
                Color(0xFF7737EE),
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoCard(
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: x.$4.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.science_outlined, color: x.$4),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              x.$1,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${x.$2} · ${x.$3}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => showInvite(c, '${x.$1} ${x.$2}'),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class EmptyPage extends StatelessWidget {
  const EmptyPage(this.icon, this.title, this.subtitle, {super.key});
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      TeacherHeader(title: title),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: cyan),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(c).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> showCreateClass(BuildContext c) =>
    showDialog(context: c, builder: (_) => const ClassDialog());

class ClassDialog extends StatefulWidget {
  const ClassDialog({super.key});
  @override
  State<ClassDialog> createState() => _ClassDialogState();
}

class _ClassDialogState extends State<ClassDialog> {
  String grade = '10', section = 'A';
  final name = TextEditingController();
  TimeOfDay time = const TimeOfDay(hour: 8, minute: 30);
  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Create a new classroom'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Class name',
                hintText: 'e.g. Biology',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField(
                    initialValue: grade,
                    decoration: const InputDecoration(labelText: 'Grade'),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: '${i + 1}',
                        child: Text('Grade ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => grade = v!),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField(
                    initialValue: section,
                    decoration: const InputDecoration(labelText: 'Section'),
                    items: ['A', 'B', 'C', 'D']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (v) => setState(() => section = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: canvas,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.schedule, color: navy),
              title: const Text('Class time'),
              subtitle: Text(time.format(c)),
              onTap: () async {
                final v = await showTimePicker(context: c, initialTime: time);
                if (v != null) setState(() => time = v);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () async {
          if (name.text.trim().isEmpty) return;
          await StudafyDatabase.instance.addClass({
            'name': name.text.trim(),
            'grade': int.parse(grade),
            'section': section,
            'room': 'TBD',
            'start_time':
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            'end_time':
                '${(time.hour + 1).toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            'color': 0xFF241D73,
          });
          if (!c.mounted) return;
          Navigator.pop(c);
          ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(
              content: Text('Class created. You can now invite students.'),
            ),
          );
        },
        child: const Text('Create class'),
      ),
    ],
  );
}

void showAttendance(BuildContext c, String className) async {
  final classId = await StudafyDatabase.instance.classIdForLabel(className);
  if (classId == null || !c.mounted) return;
  final students = await StudafyDatabase.instance.students(classId);
  if (!c.mounted) return;
  final values = {
    for (final s in students)
      s['id'] as int: <String, String?>{'status': 'present', 'reason': null},
  };
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Take attendance', style: Theme.of(c).textTheme.headlineSmall),
            Text(className, style: const TextStyle(color: muted)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...students.map(
                    (student) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: canvas,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${student['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<String>(
                            initialValue: values[student['id']]!['status'],
                            items: const [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text('Present'),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text('Absent'),
                              ),
                              DropdownMenuItem(
                                value: 'tardy',
                                child: Text('Tardy'),
                              ),
                              DropdownMenuItem(
                                value: 'excused',
                                child: Text('Excused absence'),
                              ),
                            ],
                            onChanged: (v) => setSheet(
                              () => values[student['id'] as int]!['status'] = v,
                            ),
                          ),
                          if (values[student['id']]!['status'] ==
                              'excused') ...[
                            const SizedBox(height: 7),
                            TextFormField(
                              onChanged: (v) =>
                                  values[student['id'] as int]!['reason'] = v,
                              decoration: const InputDecoration(
                                labelText: 'Reason for excused absence',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () async {
                await StudafyDatabase.instance.saveAttendanceDetails(
                  classId,
                  DateTime.now(),
                  values,
                );
                if (!c.mounted) return;
                Navigator.pop(c);
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance saved successfully.'),
                  ),
                );
              },
              child: const Text('Save attendance'),
            ),
          ],
        ),
      ),
    ),
  );
}

void showNotebook(BuildContext c, String className) async {
  final classId = await StudafyDatabase.instance.classIdForLabel(className);
  if (classId == null || !c.mounted) return;
  final lesson = TextEditingController(), homework = TextEditingController();
  showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lesson notebook', style: Theme.of(c).textTheme.headlineSmall),
          Text(className, style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          TextField(
            controller: lesson,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Lesson covered',
              hintText: 'What did you teach today?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: homework,
            decoration: const InputDecoration(labelText: 'Homework (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (lesson.text.trim().isEmpty) return;
              await StudafyDatabase.instance.saveNotebook(
                classId,
                lesson.text.trim(),
                homework.text.trim(),
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save notebook'),
          ),
        ],
      ),
    ),
  );
}

void showInvite(BuildContext c, String className) => showDialog(
  context: c,
  builder: (c) => AlertDialog(
    title: const Text('Invite students'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(className, style: const TextStyle(color: muted)),
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Student email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: canvas,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.link, color: navy),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Class code: STD-10B-84',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.copy, color: muted),
            ],
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Send invite'),
      ),
    ],
  ),
);
