import 'package:flutter/material.dart';

import '../core/file_upload_repository.dart';
import '../core/platform_attachment_source.dart';
import '../core/studafy_design.dart';
import '../features/academic/domain/academic_repository.dart';
import '../features/academic/presentation/lessons_by_date_view.dart';
import '../features/classes/application/class_list_interactor.dart';
import '../features/classes/domain/classroom.dart';
import '../features/study/domain/study.dart';
import '../features/study/presentation/notebook_view.dart';
import '../features/study/presentation/study_plans_page.dart';
import '../features/study/presentation/study_set_pages.dart';
import 'account_hub_page.dart';

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
    this.studyPlans,
    this.uploads,
    this.schoolId,
  });

  final ClassListInteractor classes;
  final AcademicRepository academic;
  final StudyRepository study;
  final StudyPlanSubscriptionRepository? studyPlans;
  final FileUploadRepository? uploads;
  final String? schoolId;

  @override
  State<StudentLessonsPage> createState() => _StudentLessonsPageState();
}

class _StudentLessonsPageState extends State<StudentLessonsPage> {
  late Future<List<ClassroomSummary>> _classes = _load();

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<List<ClassroomSummary>> _load() async {
    final result = await widget.classes.loadClasses();
    return result.fold(
      onSuccess: (list) => list,
      onFailure: (failure) => throw failure,
    );
  }

  void _openPlans() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          StudyPlansPage(study: widget.study, subscriptions: widget.studyPlans),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t('Lessons', 'الدروس')),
      actions: [
        TextButton.icon(
          onPressed: _openPlans,
          icon: const Icon(Icons.workspace_premium_outlined),
          label: Text(_t('Plans', 'الخطط')),
        ),
        const AccountButton(),
      ],
    ),
    body: FutureBuilder<List<ClassroomSummary>>(
      future: _classes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _classes = _load()),
              child: Text(
                _t(
                  'Your classes could not be loaded. Try again',
                  'تعذّر تحميل صفوفك. حاول مرة أخرى',
                ),
              ),
            ),
          );
        }
        final classes = snapshot.data ?? const [];
        if (classes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _t(
                  'Join a class to see its lessons here.',
                  'انضم إلى صف لترى دروسه هنا.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final classroom in classes)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      classroom.colorValue ?? studafyNavy.toARGB32(),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    classroom.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _t('Lessons and your notebook', 'الدروس ودفترك'),
                  ),
                  trailing: Icon(forwardChevron(context)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StudentClassPage(
                        classroom: classroom,
                        academic: widget.academic,
                        study: widget.study,
                        studyPlans: widget.studyPlans,
                        uploads: widget.uploads,
                        schoolId: widget.schoolId,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
  });

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

  String _t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadPlan();
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

  Future<void> _openPlans() async {
    await Navigator.of(context).push(
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
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.classroom.name),
        bottom: TabBar(
          tabs: [
            Tab(text: _t('Lessons', 'الدروس')),
            Tab(text: _t('My notebook', 'دفتري')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          LessonsByDateView(
            repository: widget.academic,
            classroomId: widget.classroom.id.value,
            uploads: widget.uploads,
            actionsFor: (context, lesson) => StudySetButtons(
              study: widget.study,
              resourceId: lesson.id,
              lessonTitle: lesson.title,
              plan: _plan,
              onOpenPlans: _openPlans,
            ),
          ),
          NotebookView(
            study: widget.study,
            classroomId: widget.classroom.id.value,
            schoolId: widget.schoolId,
            uploads: widget.uploads,
            source: pickPlatformAttachment,
            onOpenPlans: _openPlans,
          ),
        ],
      ),
    ),
  );
}
