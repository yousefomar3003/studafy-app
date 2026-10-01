import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_opener.dart';
import '../../../core/content_links.dart';
import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'create_wellbeing_page.dart';
import 'edit_lesson_sheet.dart';
import 'edit_materials_sheet.dart';

/// Typed, server-authoritative academic feed used by remote teacher, student,
/// and guardian shells. Draft input remains in memory when a request fails;
/// success is shown only after the API returns its canonical resource.
class AcademicOverviewPage extends StatefulWidget {
  const AcademicOverviewPage({
    super.key,
    required this.repository,
    this.classroomId,
    this.studentId,
    this.teacherTools = false,
    this.initialFeed = AcademicFeed.assignments,
    this.actions = const [],
    this.appBarActions = const [],
    this.onOpenRecord,
    this.availableFeeds = AcademicFeed.values,
    this.title,
    this.subtitle,
    this.loadClassChoices,
    this.uploads,
    this.schoolId,
    this.attachmentSource,
    this.students = const [],
    this.onStudentChanged,
    this.onOpenStudentRecord,
  });

  final AcademicRepository repository;

  /// The children a guardian follows. With more than one, the page offers
  /// "All children" and each child; with one, it is simply that child.
  final List<StudentChoice> students;

  /// Called when the person picks a child (null for all of them).
  final ValueChanged<String?>? onStudentChanged;

  /// Opens a piece of work for the child it belongs to - in the combined
  /// view the page knows whose each row is. Wins over [onOpenRecord].
  final void Function(AcademicRecord record, StudentChoice? student)?
  onOpenStudentRecord;
  final List<AcademicFeed> availableFeeds;
  final String? title;

  /// A line under the title. When given, the page is a tab of its own and
  /// opens with a large title rather than an app bar.
  final String? subtitle;

  /// Pins every feed to one class. When set, no chooser is offered - the
  /// host has already decided the scope.
  final String? classroomId;
  final String? studentId;

  /// Supplies the classes this person is in, so the feeds can be narrowed to
  /// one. Null leaves the page as a single flat list across every class.
  final Future<List<ClassChoice>> Function()? loadClassChoices;
  final bool teacherTools;

  /// Opens one assignment row. A student taps one to hand work in; the other
  /// feeds never call it, since every handler expects an assignment.
  final void Function(AcademicRecord record)? onOpenRecord;
  final AcademicFeed initialFeed;

  /// A row of controls supplied by the host shell, under the title.
  final List<Widget> actions;

  /// Controls in the app bar itself, such as a page's options menu.
  final List<Widget> appBarActions;

  /// Lets a teacher attach files to what they are filing. Null - or a null
  /// [schoolId] - leaves the attachment control out entirely rather than
  /// offering one that cannot upload.
  final FileUploadRepository? uploads;
  final String? schoolId;

  /// Overrides the platform picker. Tests supply their own; nothing else
  /// should need to.
  final AttachmentSource? attachmentSource;

  @override
  State<AcademicOverviewPage> createState() => _AcademicOverviewPageState();
}

class _AcademicOverviewPageState extends State<AcademicOverviewPage> {
  late AcademicFeed feed;
  late Future<List<AcademicRecord>> future;

  /// Null means every class. A fixed [AcademicOverviewPage.classroomId] wins
  /// over it, because that host has already chosen the scope.
  String? selectedClassId;
  List<ClassChoice> choices = const [];

  /// The child being shown; null is every child, when there are several.
  String? selectedStudentId;

  /// Whose each loaded row is. Rows of different children are different
  /// objects even for the same assignment, so this is exact.
  final _owners = Expando<StudentChoice>();

  bool get _combined => widget.students.length > 1 && selectedStudentId == null;

  @override
  void initState() {
    super.initState();
    feed = widget.initialFeed;
    selectedStudentId =
        widget.studentId ??
        (widget.students.length == 1 ? widget.students.first.id : null);
    future = _load();
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    final load = widget.loadClassChoices;
    if (load == null) return;
    try {
      final loaded = await load();
      if (mounted) setState(() => choices = loaded);
    } catch (_) {
      // A missing chooser is a smaller failure than a broken page: the feeds
      // still load across every class, which is what this page did before.
    }
  }

  /// The class to label [record] with, or null when the label would say
  /// nothing: the list is already pinned to one class, the record carries no
  /// class, or its class is not one this person has a name for.
  String? _className(AcademicRecord record) {
    if (widget.classroomId != null || selectedClassId != null) return null;
    final id = record.classroomId;
    if (id == null) return null;
    for (final choice in choices) {
      if (choice.id == id) return choice.name;
    }
    return null;
  }

  Future<List<AcademicRecord>> _load() async {
    if (_combined) {
      // Every child at once, each child's rows labelled with them. A few
      // children at most, so one request each, side by side.
      final lists = await Future.wait([
        for (final student in widget.students)
          _loadFor(student.id).then((records) {
            final own = [for (final record in records) record.copy()];
            for (final record in own) {
              _owners[record] = student;
            }
            return own;
          }),
      ]);
      return _ordered([for (final list in lists) ...list]);
    }
    final id = selectedStudentId ?? widget.studentId;
    final records = await _loadFor(id);
    final owner = widget.students.where((s) => s.id == id).firstOrNull;
    if (owner != null) {
      for (final record in records) {
        _owners[record] = owner;
      }
    }
    return _ordered(records);
  }

  Future<List<AcademicRecord>> _loadFor(String? studentId) async {
    final records = await widget.repository.load(
      feed,
      classroomId: widget.classroomId ?? selectedClassId,
      studentId: studentId,
    );
    return feed == AcademicFeed.assessments
        ? [
            for (final record in records)
              if (record.markedAssignmentId == null) record,
          ]
        : records;
  }

  List<AcademicRecord> _ordered(List<AcademicRecord> records) {
    // Graded coursework is listed with the assignment it marks, not a second
    // time among the tests.
    if (feed == AcademicFeed.grades) {
      // Paper marks and marks for online work are kept apart: paper first,
      // each group keeping the server's order.
      return [
        for (final record in records)
          if (record.delivery == 'paper') record,
        for (final record in records)
          if (record.delivery != 'paper') record,
      ];
    }
    return records;
  }

  /// A mark in words. Absent and not graded are said as such - never shown
  /// as a zero - and a mark not entered yet says so.
  String _markText(AppL10n l10n, AcademicRecord record) {
    String number(double value) =>
        value == value.roundToDouble() ? value.toInt().toString() : '$value';
    return switch (record.mark) {
      GradeMark.absent => l10n.paperGradesAbsent,
      GradeMark.notGraded => l10n.paperGradesNotGraded,
      _ when record.score != null && record.outOf != null =>
        '${number(record.score!)} ${l10n.paperGradesOutOf(number(record.outOf!))}',
      _ => l10n.paperGradesUnmarked,
    };
  }

  String _deadlineText(AppL10n l10n, SubmissionDeadline deadline) {
    final at = DateTime.tryParse(deadline.deadlineLocal);
    final localizations = MaterialLocalizations.of(context);
    final when = at == null
        ? deadline.deadlineLocal
        : '${localizations.formatMediumDate(at)} '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
    return switch (deadline.state) {
      SubmissionWindow.closed => l10n.deadlineClosed,
      SubmissionWindow.gradedLocked => l10n.deadlineGraded,
      SubmissionWindow.open => l10n.deadlineDue(when, deadline.timeZone),
    };
  }

  /// A student's (or guardian's) list of work, rather than a teacher's.
  ///
  /// Known by its rows opening the hand-in screen; a plain read-only list
  /// keeps the record states as published or draft.
  bool get _studentWork =>
      !widget.teacherTools &&
      feed == AcademicFeed.assignments &&
      (widget.onOpenRecord != null || widget.onOpenStudentRecord != null);

  /// Where a piece of work stands for the person handing it in. Work with no
  /// deadline stays open; the server is the authority either way.
  SubmissionWindow _window(AcademicRecord record) =>
      record.deadline?.state ?? SubmissionWindow.open;

  /// Open work first, then work past its deadline, then marked work - each
  /// keeping the server's order.
  List<AcademicRecord> _grouped(List<AcademicRecord> records) => [
    for (final window in SubmissionWindow.values)
      for (final record in records)
        if (_window(record) == window) record,
  ];

  String _windowHeading(AppL10n l10n, SubmissionWindow window) =>
      switch (window) {
        SubmissionWindow.open => l10n.workSectionOpen,
        SubmissionWindow.closed => l10n.workSectionClosed,
        SubmissionWindow.gradedLocked => l10n.workSectionGraded,
      };

  StatusPill _windowPill(AppL10n l10n, SubmissionWindow window) =>
      switch (window) {
        SubmissionWindow.open => StatusPill(
          label: l10n.workStateOpen,
          icon: Icons.edit_rounded,
        ),
        SubmissionWindow.closed => StatusPill(
          label: l10n.workStateClosed,
          icon: Icons.lock_clock_rounded,
          color: studafyMuted,
        ),
        SubmissionWindow.gradedLocked => StatusPill(
          label: l10n.workStateGraded,
          icon: Icons.grading_rounded,
          color: studafyTeal,
        ),
      };

  Future<void> _editMaterials(AcademicRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppL10n.of(context).materialsEditSaved;
    final done = await showEditMaterialsSheet(
      context,
      repository: widget.repository,
      work: record,
      isAssessment: feed == AcademicFeed.assessments,
      uploads: widget.uploads,
      schoolId: widget.schoolId,
      attachmentSource: widget.attachmentSource,
    );
    if (done == true && mounted) {
      messenger.showMessage(saved);
      _refresh();
    }
  }

  Future<void> _editLesson(AcademicRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppL10n.of(context).lessonEditSaved;
    final done = await showEditLessonSheet(
      context,
      repository: widget.repository,
      lesson: record,
      uploads: widget.uploads,
      schoolId: widget.schoolId,
      attachmentSource: widget.attachmentSource,
    );
    if (done == true && mounted) {
      messenger.showMessage(saved);
      _refresh();
    }
  }

  bool _canPublish(AcademicRecord record) =>
      widget.teacherTools &&
      record.state == 'draft' &&
      (feed == AcademicFeed.assignments ||
          feed == AcademicFeed.assessments ||
          // A lesson filed before lessons were published on creation, or
          // by any other path, would otherwise sit unseen forever.
          feed == AcademicFeed.content);

  Future<void> _publish(AcademicRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      if (feed == AcademicFeed.assignments) {
        await widget.repository.publishAssignment(record.id, record.version);
      } else if (feed == AcademicFeed.content) {
        await widget.repository.publishResource(record.id, record.version);
      } else {
        await widget.repository.publishAssessment(record.id, record.version);
      }
      messenger.showMessage(l10n.academicPublished);
    } on Object {
      messenger.showMessage(l10n.academicPublishFailed);
    }
    if (mounted) _refresh();
  }

  void _refresh() {
    setState(() {
      future = _load();
    });
  }

  IconData _feedIcon(AcademicFeed value) => switch (value) {
    AcademicFeed.content => Icons.menu_book_rounded,
    AcademicFeed.assignments => Icons.assignment_rounded,
    AcademicFeed.assessments => Icons.quiz_rounded,
    AcademicFeed.grades => Icons.grading_rounded,
    AcademicFeed.attendance => Icons.fact_check_rounded,
    AcademicFeed.wellbeing => Icons.favorite_rounded,
  };

  /// A record's state in words and an icon - never colour alone.
  StatusPill? _statePill(AppL10n l10n, AcademicRecord item) =>
      switch (item.state) {
        'draft' => StatusPill(
          label: l10n.paperGradesStateDraft,
          icon: Icons.edit_note_rounded,
          color: studafyMuted,
        ),
        'published' => StatusPill(
          label: l10n.paperGradesStatePublished,
          icon: Icons.check_circle_rounded,
        ),
        'withdrawn' || 'archived' => StatusPill(
          label: l10n.academicStateWithdrawn,
          icon: Icons.visibility_off_outlined,
          color: studafyMuted,
        ),
        'strength' => StatusPill(
          label: l10n.wellbeingKindStrength,
          icon: Icons.emoji_events_outlined,
          color: studafyCyan,
        ),
        'note' => StatusPill(
          label: l10n.wellbeingKindNote,
          icon: Icons.sticky_note_2_outlined,
        ),
        'concern' => StatusPill(
          label: l10n.wellbeingKindConcern,
          icon: Icons.report_problem_outlined,
          color: studafyDanger,
        ),
        'present' => StatusPill(
          label: l10n.attendancePresent,
          icon: Icons.check_circle_rounded,
        ),
        'absent' => StatusPill(
          label: l10n.attendanceAbsent,
          icon: Icons.cancel_outlined,
          color: studafyDanger,
        ),
        'late' => StatusPill(
          label: l10n.attendanceTardy,
          icon: Icons.schedule_rounded,
          color: studafyCyan,
        ),
        'excused' => StatusPill(
          label: l10n.attendanceExcused,
          icon: Icons.verified_outlined,
          color: studafyMuted,
        ),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final canAddWellbeing =
        widget.teacherTools &&
        feed == AcademicFeed.wellbeing &&
        (widget.classroomId != null || choices.isNotEmpty);
    final largeTitle = widget.subtitle != null;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Scaffold(
      appBar: largeTitle
          ? null
          : AppBar(
              title: Text(widget.title ?? l10n.academicTitle),
              actions: widget.appBarActions,
            ),
      body: Column(
        children: [
          if (largeTitle)
            StudafyLargeTitle(
              title: widget.title ?? l10n.academicTitle,
              subtitle: widget.subtitle,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 12),
            ),
          if (widget.actions.isNotEmpty)
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                children: widget.actions,
              ),
            ),
          // Whose record this is comes first of all: a parent of two thinks
          // "Layla, then what is due".
          if (widget.students.length > 1) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: studafyMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.learningFilterByChild,
                    style: const TextStyle(
                      color: studafyMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            PillTabs<String?>(
              values: [null, for (final student in widget.students) student.id],
              selected: selectedStudentId,
              label: (id) => id == null
                  ? l10n.announcementsAllChildren
                  : widget.students.firstWhere((s) => s.id == id).name,
              icon: (id) =>
                  id == null ? Icons.groups_rounded : Icons.child_care_rounded,
              onSelected: (id) {
                setState(() {
                  selectedStudentId = id;
                  future = _load();
                });
                widget.onStudentChanged?.call(id);
              },
            ),
            const SizedBox(height: 10),
          ],
          // The class filter sits above the feed switcher because it is the
          // coarser choice: a student thinks "maths, then what is due", not
          // "assignments, then which class".
          if (widget.classroomId == null && choices.isNotEmpty) ...[
            PillTabs<String?>(
              values: [null, for (final choice in choices) choice.id],
              selected: selectedClassId,
              label: (id) => id == null
                  ? l10n.academicAllClasses
                  : choices.firstWhere((c) => c.id == id).name,
              icon: (id) => id == null
                  ? Icons.apps_rounded
                  : subjectIcon(choices.firstWhere((c) => c.id == id).name),
              onSelected: (id) => setState(() {
                selectedClassId = id;
                future = _load();
              }),
            ),
            const SizedBox(height: 10),
          ],
          PillTabs<AcademicFeed>(
            values: widget.availableFeeds,
            selected: feed,
            label: (value) => _feedLabel(l10n, value),
            icon: _feedIcon,
            onSelected: (value) => setState(() {
              feed = value;
              future = _load();
            }),
          ),
          if (canAddWellbeing)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _addWellbeing,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.wellbeingAdd),
                ),
              ),
            ),
          Expanded(
            // A short cross-fade when the tab or class changes, so the new
            // list arrives rather than snapping in.
            child: AnimatedSwitcher(
              duration: motion,
              child: KeyedSubtree(
                key: ValueKey((feed, selectedClassId, selectedStudentId)),
                child: _feedList(context, l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedList(BuildContext context, AppL10n l10n) =>
      FutureBuilder<List<AcademicRecord>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Unavailable(onRetry: _refresh);
          }
          final loaded = snapshot.data ?? const <AcademicRecord>[];
          final items = _studentWork ? _grouped(loaded) : loaded;
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                children: [
                  StudafyEmptyState(
                    icon: _feedIcon(feed),
                    title: l10n.academicNoRecords,
                    message: widget.teacherTools
                        ? l10n.academicEmptyTeacherHint
                        : null,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _recordCard(context, items, index),
            ),
          );
        },
      );

  Widget _recordCard(
    BuildContext context,
    List<AcademicRecord> items,
    int index,
  ) {
    final item = items[index];
    final l10n = AppL10n.of(context);
    // Only an assignment opens anything. Every caller hands the record to
    // an assignment screen - hand-in for a student or guardian, the roster
    // for a teacher - so a grade or an assessment tapped here used to open
    // "hand in work" with an id that is not an assignment's.
    final onOpenStudent = widget.onOpenStudentRecord;
    final void Function(AcademicRecord)? onOpen =
        feed != AcademicFeed.assignments
        ? null
        : onOpenStudent != null
        ? (record) => onOpenStudent(record, _owners[record])
        : widget.onOpenRecord;
    // In the combined view each row says whose it is, and where.
    final owner = _combined ? _owners[item] : null;
    final grades = feed == AcademicFeed.grades;
    final paper = item.delivery == 'paper';
    final student = _studentWork;
    final window = _window(item);
    final newSection =
        (grades &&
            (index == 0 || (items[index - 1].delivery == 'paper') != paper)) ||
        (student && (index == 0 || _window(items[index - 1]) != window));
    final className = _className(item);
    // "Published" says nothing to the person handing work in, or reading
    // their marks; whether work is still open does.
    final pill = student
        ? _windowPill(l10n, window)
        : grades && !widget.teacherTools
        ? null
        : _statePill(l10n, item);
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: studafyMuted, fontWeight: FontWeight.w600);

    Widget? trailing;
    if (student && onOpen != null) {
      // Says what a tap does before it is made: hand the work in while it is
      // open, otherwise look at it and at what was handed in.
      trailing = _ActionHint(
        label: window == SubmissionWindow.open
            ? l10n.submitSend
            : l10n.workView,
        prominent: window == SubmissionWindow.open,
      );
    } else if (_canPublish(item)) {
      trailing = FilledButton.tonal(
        onPressed: () => _publish(item),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text(l10n.academicPublish),
      );
    } else if (widget.teacherTools && feed == AcademicFeed.content) {
      trailing = IconButton(
        tooltip: l10n.lessonEdit,
        onPressed: () => _editLesson(item),
        icon: const Icon(Icons.edit_outlined),
      );
    } else if (widget.teacherTools &&
        (feed == AcademicFeed.assignments ||
            feed == AcademicFeed.assessments)) {
      trailing = IconButton(
        tooltip: l10n.materialsEditTitle,
        onPressed: () => _editMaterials(item),
        icon: const Icon(Icons.attach_file_rounded),
      );
    }

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FeatureCard(
        onTap: onOpen == null ? null : () => onOpen(item),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              icon: grades && paper
                  ? Icons.description_rounded
                  : _feedIcon(feed),
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titles and details are school-authored content, so they
                  // render verbatim in their own direction.
                  UserContentText(
                    item.title,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (grades)
                    // The mark itself, large: it is what the row is for.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _markText(l10n, item),
                        style: TextStyle(
                          color: item.mark == GradeMark.scored
                              ? studafyDeep
                              : studafyMuted,
                          fontSize: item.mark == GradeMark.scored ? 20 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (item.detail.trim().isNotEmpty)
                    LinkedText(item.detail),
                  if (grades && paper)
                    Text(l10n.paperGradesPaperLabel, style: labelStyle),
                  if (item.deadline case final deadline?)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: studafyMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _deadlineText(l10n, deadline),
                              style: labelStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.maximumScore case final score?)
                    Text(
                      l10n.academicGradedOutOf(
                        score == score.roundToDouble()
                            ? score.toInt().toString()
                            : score.toString(),
                      ),
                      style: labelStyle,
                    ),
                  // The teacher's material, openable from the list itself -
                  // the only place graded work is shown.
                  StoredAttachmentList(
                    attachments: item.attachments,
                    uploads: widget.uploads,
                    dense: true,
                  ),
                  if (pill != null || className != null || owner != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (owner != null)
                            StatusPill(
                              label: owner.schoolName.isEmpty
                                  ? owner.name
                                  : '${owner.name} · ${owner.schoolName}',
                              icon: Icons.child_care_rounded,
                              color: studafyDeep,
                            ),
                          ?pill,
                          // Only while the list spans classes. Once it is
                          // narrowed the pill would repeat the chosen tab
                          // above on every row.
                          if (className != null)
                            StatusPill(
                              label: className,
                              icon: subjectIcon(className),
                              color: studafyMuted,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    if (!newSection) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          student
              ? _windowHeading(l10n, window)
              : paper
              ? l10n.paperGradesPaperSection
              : l10n.paperGradesOnlineSection,
          padding: EdgeInsetsDirectional.fromSTEB(4, index == 0 ? 4 : 14, 0, 8),
        ),
        card,
      ],
    );
  }

  /// Opens the new wellbeing note form. Inside a class it is for that
  /// class; across classes the teacher picks one, starting from the class
  /// they are filtering by.
  Future<void> _addWellbeing() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final classroomId = widget.classroomId;
    final classes = classroomId != null
        ? [
            ClassOption(
              id: classroomId,
              name: widget.title ?? l10n.academicThisClass,
            ),
          ]
        : [
            for (final choice in choices)
              ClassOption(id: choice.id, name: choice.name),
          ];
    final saved = await Navigator.of(context).pushOnce<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateWellbeingPage(
          repository: widget.repository,
          classes: classes,
          initialClassroomId: classroomId ?? selectedClassId,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    messenger.showMessage(saved);
    _refresh();
  }
}

/// What tapping a row of work does, said in a word beside it.
class _ActionHint extends StatelessWidget {
  const _ActionHint({required this.label, required this.prominent});

  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 6, end: 4, top: 2),
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: prominent ? studafyNavy : studafyWash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: prominent ? Colors.white : studafyNavy,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(
            forwardChevron(context),
            size: 18,
            color: prominent ? Colors.white : studafyNavy,
          ),
        ],
      ),
    ),
  );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: StudafyEmptyState(
      icon: Icons.wifi_off_rounded,
      title: AppL10n.of(context).academicUnavailable,
      actionLabel: AppL10n.of(context).academicRetry,
      onAction: onRetry,
    ),
  );
}

/// The reader's name for a feed tab. The enum names are the app's vocabulary,
/// never the user's.
String _feedLabel(AppL10n l10n, AcademicFeed feed) => switch (feed) {
  AcademicFeed.content => l10n.feedContent,
  AcademicFeed.assignments => l10n.feedAssignments,
  AcademicFeed.assessments => l10n.feedAssessments,
  AcademicFeed.grades => l10n.feedGrades,
  AcademicFeed.attendance => l10n.feedAttendance,
  AcademicFeed.wellbeing => l10n.feedWellbeing,
};
