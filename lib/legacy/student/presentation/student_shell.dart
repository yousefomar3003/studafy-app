import 'package:flutter/material.dart';

import '../../../app/account_hub_page.dart';
import '../../../app/student_today_page.dart';
import '../../../app/student_notebook_subscription_page.dart';
import '../../../features/notebook/domain/notebook_subscription_repository.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../../../features/classes/application/class_list_interactor.dart';
import '../../../features/classes/presentation/join_class_page.dart';
import '../../../features/academic/presentation/submit_work_page.dart';
import '../../../core/file_upload_repository.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_localizations.dart';
import '../../../core/studafy_domain.dart';
import '../../../features/academic/domain/academic_repository.dart';
import '../../../features/academic/presentation/academic_overview_page.dart';
import '../../../features/messaging/presentation/conversations_page.dart';
import '../../../features/messaging/presentation/messaging_scope.dart';
import '../../../features/session/application/session_interactor.dart';
import '../../../features/study_assistant/application/study_assistant_interactor.dart';
import '../../../features/study_assistant/presentation/study_assistant_page.dart';
import 'student_shared.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({
    super.key,
    required this.academic,
    this.classes,
    this.notebookSubscription,
    this.session,
    this.studyAssistant,
    this.fileUploads,
  });
  final NotebookSubscriptionRepository? notebookSubscription;
  final AcademicRepository academic;

  /// Lets a student join a class from a link they were sent. Optional so the
  /// preview shell, which has no school service behind it, still builds.
  final ClassListInteractor? classes;

  /// Re-reads the profile after a join, because the membership that makes the
  /// rest of this shell work is created on the server. Optional for the same
  /// reason as [classes].
  final SessionInteractor? session;

  /// The study helper. Null when the server has no AI provider configured,
  /// and the tab is then absent rather than present and always failing.
  final StudyAssistantInteractor? studyAssistant;

  /// Lets a student attach documents and photos to the work they hand in.
  /// Null in builds with no upload pipeline, and the control is then absent.
  final FileUploadRepository? fileUploads;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int index = 0;

  /// Signed in, but not in any class yet.
  ///
  /// Every student starts here: they make an account before a teacher has
  /// sent them anything. Being in no class is an empty state, not a locked
  /// door, so the shell opens and says what to do next rather than refusing
  /// to load. The feeds are skipped rather than shown failing, because
  /// without a membership every one of them would error identically and say
  /// nothing useful.
  bool get _hasNoClassYet =>
      ActiveContextController.instance.membership == null;

  Future<void> _joinClass() async {
    final classes = widget.classes;
    if (classes == null) return;
    final joined = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<void>(builder: (_) => JoinClassPage(classes: classes)),
    );
    if (joined == null || !mounted) return;
    // The server made the membership; this is how the client learns of it.
    await widget.session?.completeRemoteLogin(
      role: StudafyRole.student,
      consentAccepted: false,
      locale: Localizations.localeOf(context).languageCode,
    );
    if (mounted) setState(() {});
  }

  /// Supplies the class filter its options. Kept here rather than in the
  /// academic slice because only the shell may reach across features.
  Future<List<ClassChoice>> _classChoices() async {
    final classes = widget.classes;
    if (classes == null) return const [];
    final result = await classes.loadClasses();
    return result.fold(
      onSuccess: (items) => [
        for (final item in items)
          ClassChoice(id: item.id.value, name: item.name),
      ],
      onFailure: (_) => const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.academic;
    final studentId = ActiveContextController.instance.selectedStudent?.id;
    final messaging = MessagingScope.isAvailable(context);
    final assistant = widget.studyAssistant;
    // Today, Notebook, Work, then the two optional tabs in that order.
    final messagesIndex = 3 + (assistant == null ? 0 : 1);
    final pages = <Widget>[
      StudentTodayPage(
        academic: repository,
        onWork: () => setState(() => index = 2),
        onNotebook: () => setState(() => index = 1),
        classes: widget.classes,
      ),
      StudentNotebookSubscriptionPage(
        subscription: widget.notebookSubscription,
        visible: index == 1,
        contentBuilder: (_) => AcademicOverviewPage(
          repository: repository,
          studentId: studentId,
          title: AppL10n.of(context).notebookTitle,
          initialFeed: AcademicFeed.content,
          availableFeeds: const [AcademicFeed.content],
          actions: const [AccountButton()],
          // Material belongs to the class it was taught in, and a student
          // taking six subjects was reading one undivided list of all of
          // them. Every other feed already offered this chooser.
          loadClassChoices: widget.classes == null ? null : _classChoices,
        ),
      ),
      // My work and Grades were two tabs over the same screen, differing only
      // in which feeds they offered - and a student looking at an assignment
      // wants its mark in the same place. One tab, every feed.
      AcademicOverviewPage(
        repository: repository,
        studentId: studentId,
        initialFeed: AcademicFeed.assignments,
        availableFeeds: const [
          AcademicFeed.assignments,
          AcademicFeed.assessments,
          AcademicFeed.grades,
          AcademicFeed.attendance,
          AcademicFeed.wellbeing,
        ],
        actions: const [AccountButton()],
        loadClassChoices: widget.classes == null ? null : _classChoices,
        // Only published work can be handed in; a draft is not the
        // student's to see as open.
        onOpenRecord: (record) async {
          final messenger = ScaffoldMessenger.of(context);
          final done = await Navigator.of(context).push<String>(
            MaterialPageRoute<String>(
              builder: (_) => SubmitWorkPage(
                repository: repository,
                assignmentId: record.id,
                assignmentTitle: record.title,
                canSubmit: record.state == 'published',
                uploads: widget.fileUploads,
                schoolId: ActiveContextController.instance.membership?.schoolId,
                studentId: studentId,
              ),
            ),
          );
          if (done != null) {
            messenger.showSnackBar(SnackBar(content: Text(done)));
          }
        },
      ),
      if (assistant != null)
        StudyAssistantPage(
          assistant: assistant,
          actions: const [AccountButton()],
        ),
      if (messaging) ConversationsPage(visible: index == messagesIndex),
    ];
    final classes = widget.classes;
    if (_hasNoClassYet && classes != null) {
      return Scaffold(
        body: SafeArea(
          child: _NoClassYet(
            onJoin: _joinClass,
            actions: const [AccountButton()],
          ),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      // Always reachable, not only from an empty state: a student joins a
      // second class on the same day they join their first, and the link
      // often arrives in a chat app rather than as something tappable.
      floatingActionButton: classes == null || index != 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _joinClass,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(AppL10n.of(context).joinClassAction),
            ),
      bottomNavigationBar: StudafyNavigationBar(
        selectedIndex: index,
        onSelected: (value) => setState(() => index = value),
        items: [
          StudafyNavItem(
            StudafyLocalizations.of(context).text('today'),
            Icons.home_outlined,
            Icons.home_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(context).text('notebook'),
            Icons.library_books_outlined,
            Icons.library_books_rounded,
          ),
          StudafyNavItem(
            StudafyLocalizations.of(context).text('work'),
            Icons.assignment_outlined,
            Icons.assignment_rounded,
          ),
          if (assistant != null)
            StudafyNavItem(
              AppL10n.of(context).studyAssistantTab,
              Icons.school_outlined,
              Icons.school_rounded,
            ),
          if (messaging)
            StudafyNavItem(
              StudafyLocalizations.of(context).text('messages'),
              Icons.forum_outlined,
              Icons.forum_rounded,
            ),
        ],
        accent: studentNavy,
      ),
    );
  }
}

/// The student home before they are in any class.
///
/// Deliberately the whole screen rather than a banner over empty feeds: a
/// grades tab and an assignments tab that are both empty for the same reason
/// tell a new student nothing, and every one of them would have to explain
/// the same single next step.
class _NoClassYet extends StatelessWidget {
  const _NoClassYet({required this.onJoin, required this.actions});

  final Future<void> Function() onJoin;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_add_outlined, size: 56),
                    const SizedBox(height: 20),
                    Text(
                      l10n.onboardingStudentTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.onboardingStudentBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: onJoin,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(l10n.joinClassAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
