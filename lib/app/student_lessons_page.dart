import 'package:flutter/material.dart';

import '../core/file_upload_repository.dart';
import '../core/material_selection.dart';
import '../core/navigation.dart';
import '../core/platform_attachment_source.dart';
import '../core/studafy_components.dart';
import '../core/studafy_design.dart';
import '../core/studafy_formatting.dart';
import '../core/user_content_text.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/lessons_by_date_view.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/study/domain/study.dart';
import '../features/study/presentation/my_notebooks_page.dart';
import '../features/study/presentation/notebook_view.dart';
import '../features/study/presentation/study_notebook_shelf.dart';
import '../features/study/presentation/study_plan_copy.dart';
import '../features/study/presentation/study_plans_page.dart';
import '../features/study/presentation/study_set_pages.dart';
import '../l10n/generated/app_l10n.dart';
import 'material_picker.dart';

/// The student's Lessons tab: their classes, and in each class its lessons by
/// date and their own notebook for it.
///
/// Composed here, in the app layer, because a class page draws on three
/// features - classes, academic (lessons) and study (notebook, quizzes,
/// plans) - and features may not import each other.
class StudentLessonsPage extends StatefulWidget {
  const StudentLessonsPage({
    super.key,
    required this.classes,
    required this.academic,
    required this.study,
    this.onAskHelper,
    this.studyPlans,
    this.uploads,
    this.schoolId,
  });

  final ClassListInteractor classes;
  final AcademicRepository academic;
  final StudyRepository study;

  /// Opens the AI helper about one lesson (ADR-0037). Null hides the button.
  final void Function(String lessonId, String title)? onAskHelper;
  final StudyPlanSubscriptionRepository? studyPlans;
  final FileUploadRepository? uploads;
  final String? schoolId;

  @override
  State<StudentLessonsPage> createState() => _StudentLessonsPageState();
}

class _StudentLessonsPageState extends State<StudentLessonsPage> {
  late Future<List<ClassroomSummary>> _classes = _load();
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<List<ClassroomSummary>> _load() async {
    final result = await widget.classes.loadClasses();
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await widget.study.plan();
      if (mounted) setState(() => _plan = plan);
    } on Object {
      // Without the plan the card is left out; Plans is still in the header.
    }
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudyPlansPage(
          study: widget.study,
          subscriptions: widget.studyPlans,
        ),
      ),
    );
    // A plan bought there changes what is offered here.
    await _loadPlan();
  }

  void _openClass(ClassroomSummary classroom, {int tab = 0}) =>
      Navigator.of(context).pushOnce(
        MaterialPageRoute<void>(
          builder: (_) => StudentClassPage(
            classroom: classroom,
            academic: widget.academic,
            study: widget.study,
            studyPlans: widget.studyPlans,
            uploads: widget.uploads,
            schoolId: widget.schoolId,
            initialTab: tab,
            onAskHelper: widget.onAskHelper,
            pick: (context, request) => pickMaterials(
              context,
              request,
              classes: widget.classes,
              academic: widget.academic,
              study: widget.study,
            ),
          ),
        ),
      );

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _classes = next);
    await Future.wait<void>([next.then((_) {}, onError: (_) {}), _loadPlan()]);
  }

  /// The plan, what the next one adds, and the way to it. On Studafy Max
  /// there is nothing to sell, so it only says what the student has.
  Widget? _planCard(AppL10n l10n) {
    final plan = _plan;
    // The plans are the AI study tools: nothing to sell where there are none.
    if (plan == null || !plan.anyToolOn) return null;
    final next = plan.tier.next;
    final copy = studyPlanCopy[plan.tier]!;
    return PlanSummaryCard(
      eyebrow: l10n.studyPlansYourPlan,
      planName: copy.name,
      detail: next == null ? l10n.planEverything : null,
      benefitsTitle: next == null
          ? null
          : l10n.planAdds(studyPlanCopy[next]!.name),
      benefits: next == null
          ? const []
          : [for (final line in studyPlanCopy[next]!.adds) line(l10n)],
      actionLabel: next == null
          ? l10n.planSeePlans
          : l10n.planUpgradeTo(studyPlanCopy[next]!.name),
      onAction: _openPlans,
      compact: next == null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final upgradable = _plan?.tier.next != null;
    final aiOn = _plan?.anyToolOn ?? false;
    return Scaffold(
      body: Column(
        children: [
          StudafyLargeTitle(
            title: l10n.feedContent,
            subtitle: l10n.studentLessonsSubtitle,
          ),
          // Every notebook, by class - a deleted class's included - and the
          // plans, labelled rather than hidden behind icons.
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
              children: [
                if (aiOn) ...[
                  StudafyPillButton(
                    icon: Icons.workspace_premium_rounded,
                    label: upgradable
                        ? l10n.upgradeButton
                        : l10n.studentLessonsPlans,
                    prominent: upgradable,
                    onPressed: _openPlans,
                  ),
                  const SizedBox(width: 8),
                ],
                StudafyPillButton(
                  icon: Icons.edit_note_rounded,
                  label: l10n.notebookMyNotebooks,
                  onPressed: () => Navigator.of(context).pushOnce(
                    MaterialPageRoute<void>(
                      builder: (_) => MyNotebooksPage(study: widget.study),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ClassroomSummary>>(
              future: _classes,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: StudafyEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: l10n.studentLessonsYourClassesCouldNotBe,
                      actionLabel: l10n.todayRetry,
                      onAction: () => setState(() {
                        _classes = _load();
                      }),
                    ),
                  );
                }
                final classes = snapshot.data ?? const <ClassroomSummary>[];
                final plan = _planCard(l10n);
                return StudafyRefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      28,
                    ),
                    children: [
                      SectionHeader(l10n.studentTodayYourClasses),
                      if (classes.isEmpty)
                        StudafyEmptyState(
                          icon: Icons.group_add_outlined,
                          title: l10n.studentTodayNoClassesYet,
                          message: l10n.studentLessonsJoinAClassToSee,
                        ),
                      for (final classroom in classes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ClassCard(
                            classroom: classroom,
                            onLessons: () => _openClass(classroom),
                            onNotebook: () => _openClass(classroom, tab: 1),
                          ),
                        ),
                      if (plan != null) ...[
                        SectionHeader(l10n.accountSectionSubscription),
                        plan,
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One class: what it is, and its two ways in - the lessons the teacher
/// shared, and the student's own notebook.
class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.classroom,
    required this.onLessons,
    required this.onNotebook,
  });

  final ClassroomSummary classroom;
  final VoidCallback onLessons;
  final VoidCallback onNotebook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final color = classroom.colorValue == null
        ? studafyNavy
        : Color(classroom.colorValue!);
    return FeatureCard(
      onTap: onLessons,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(icon: subjectIcon(classroom.name), color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UserContentText(
                      classroom.name,
                      style: const TextStyle(
                        color: studafyInk,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.studentTodayGradeSection(
                        classroom.grade,
                        classroom.section,
                      ),
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(forwardChevron(context), color: studafyMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ClassEntry(
                  icon: Icons.menu_book_rounded,
                  label: l10n.feedContent,
                  onTap: onLessons,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ClassEntry(
                  icon: Icons.edit_note_rounded,
                  label: l10n.studentClassNotebook,
                  onTap: onNotebook,
                  color: studafyTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassEntry extends StatelessWidget {
  const _ClassEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = studafyNavy,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .08),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One class: its lessons by date, and the student's notebook for it.
class StudentClassPage extends StatefulWidget {
  const StudentClassPage({
    super.key,
    required this.classroom,
    required this.academic,
    required this.study,
    this.studyPlans,
    this.uploads,
    this.schoolId,
    this.initialTab = 0,
    this.onAskHelper,
    this.pick,
  });

  /// Chooses exactly what an AI study tool uses (ADR-0039).
  final MaterialPicker? pick;

  /// 0 opens the lessons, 1 the notebook.
  final int initialTab;

  /// Opens the AI helper about one lesson. Null hides the button.
  final void Function(String lessonId, String title)? onAskHelper;

  final ClassroomSummary classroom;
  final AcademicRepository academic;
  final StudyRepository study;
  final StudyPlanSubscriptionRepository? studyPlans;
  final FileUploadRepository? uploads;
  final String? schoolId;

  @override
  State<StudentClassPage> createState() => _StudentClassPageState();
}

class _StudentClassPageState extends State<StudentClassPage> {
  StudyPlan? _plan;

  /// The class's study notebooks: the lesson buttons and the shelf show
  /// the same ones, and both follow one being written.
  late final _notebooks = NotebookTracker(
    repository: widget.study,
    classroomId: widget.classroom.id.value,
  );
  late final _host = NotebookHost(
    study: widget.study,
    tracker: _notebooks,
    className: widget.classroom.name,
    plan: () => _plan,
    onOpenPlans: _openPlans,
    pick: (context, request) => (widget.pick ?? _noPicker)(context, request),
  );

  static Future<MaterialSelection?> _noPicker(
    BuildContext context,
    MaterialPickRequest request,
  ) async => null;

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _notebooks.load();
  }

  @override
  void dispose() {
    _notebooks.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await widget.study.plan();
      if (mounted) setState(() => _plan = plan);
    } on Object {
      // Without the plan the study buttons show locked; a tap still goes
      // to the server, which is the authority on the plan anyway.
    }
  }

  /// One of this class's published lessons, for the notebook to use.
  Future<LessonChoice?> _pickLesson(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final lessons = await widget.academic.load(
      AcademicFeed.content,
      classroomId: widget.classroom.id.value,
    );
    if (!context.mounted) return null;
    return showModalBottomSheet<LessonChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  l10n.notebookPickLesson,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (lessons.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.notebookNoLessons),
                ),
              for (final lesson in lessons)
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text(lesson.title),
                  subtitle: lesson.date == null
                      ? null
                      : Text(studafyMediumDate(sheetContext, lesson.date!)),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    LessonChoice(
                      id: lesson.id,
                      title: lesson.title,
                      text: lesson.detail,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudyPlansPage(
          study: widget.study,
          subscriptions: widget.studyPlans,
        ),
      ),
    );
    // A plan bought on that screen unlocks the buttons here.
    await _loadPlan();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // What the server offers this student of the AI study tools. Nothing
    // is shown before the plan says, nor anything it says is off.
    final studySetsOn = _plan?.studySetsOn ?? false;
    final notebooksOn = _plan?.notebooksOn ?? false;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: UserContentText(widget.classroom.name),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(86),
            child: Builder(
              builder: (tabContext) {
                final controller = DefaultTabController.of(tabContext);
                return Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Two clear ways into the class: the lessons, and the
                      // student's own notebook for it.
                      Container(
                        height: 46,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: studafyWash,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: studafyAbyss.withValues(alpha: .08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: studafyNavy,
                          unselectedLabelColor: studafyMuted,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          tabs: [
                            Tab(
                              height: 38,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(child: Text(l10n.feedContent)),
                                ],
                              ),
                            ),
                            Tab(
                              height: 38,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit_note_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(l10n.studentClassNotebook),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // What the open part holds, in a line.
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) => Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: Text(
                            controller.index == 0
                                ? l10n.studentClassLessonsDetail
                                : l10n.studentClassNotebookDetail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: studafyMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        body: TabBarView(
          children: [
            LessonsByDateView(
              repository: widget.academic,
              classroomId: widget.classroom.id.value,
              uploads: widget.uploads,
              header: !studySetsOn
                  ? null
                  : (context, {required bool hasLessons}) => StudyToolsCard(
                      plan: _plan,
                      hasLessons: hasLessons,
                      onOpenPlans: _openPlans,
                      // From here nothing is chosen yet: the student chooses.
                      onMake: widget.pick == null
                          ? null
                          : (kind) => openStudySetFromSelection(
                              context,
                              study: widget.study,
                              pick: widget.pick!,
                              kind: kind,
                              request: MaterialPickRequest(
                                action: kind == StudySetKind.quiz
                                    ? MaterialAction.quiz
                                    : MaterialAction.flashcards,
                              ),
                              plan: _plan,
                              onOpenPlans: _openPlans,
                            ),
                    ),
              actionsFor: (context, lesson) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.onAskHelper case final ask?)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => ask(lesson.id, lesson.title),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(AppL10n.of(context).helperAskAboutLesson),
                      ),
                    ),
                  if (notebooksOn)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: LessonNotebookButton(
                          host: _host,
                          resourceId: lesson.id,
                          lessonTitle: lesson.title,
                        ),
                      ),
                    ),
                  if (studySetsOn)
                    StudySetButtons(
                      study: widget.study,
                      resourceId: lesson.id,
                      lessonTitle: lesson.title,
                      plan: _plan,
                      onOpenPlans: _openPlans,
                      pick: widget.pick,
                    ),
                ],
              ),
            ),
            NotebookView(
              study: widget.study,
              classroomId: widget.classroom.id.value,
              schoolId: widget.schoolId,
              uploads: widget.uploads,
              source: pickPlatformAttachment,
              onOpenPlans: _openPlans,
              pickLesson: _pickLesson,
              header: notebooksOn ? StudyNotebookShelf(host: _host) : null,
              pick: widget.pick,
            ),
          ],
        ),
      ),
    );
  }
}
