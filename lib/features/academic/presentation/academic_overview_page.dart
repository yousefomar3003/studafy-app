import 'package:flutter/material.dart';

import '../../../core/attachment_field.dart';
import '../../../core/attachment_opener.dart';
import '../../../core/content_links.dart';
import '../../../core/feedback.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'create_lesson_page.dart';

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
    this.onOpenRecord,
    this.availableFeeds = AcademicFeed.values,
    this.title,
    this.loadClassChoices,
    this.uploads,
    this.schoolId,
    this.attachmentSource,
  });

  final AcademicRepository repository;
  final List<AcademicFeed> availableFeeds;
  final String? title;

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

  /// App bar actions supplied by the host shell, such as its account entry.
  final List<Widget> actions;

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

  @override
  void initState() {
    super.initState();
    feed = widget.initialFeed;
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
    final records = await widget.repository.load(
      feed,
      classroomId: widget.classroomId ?? selectedClassId,
      studentId: widget.studentId,
    );
    // Graded coursework is listed with the assignment it marks, not a second
    // time among the tests.
    return feed == AcademicFeed.assessments
        ? [
            for (final record in records)
              if (record.markedAssignmentId == null) record,
          ]
        : records;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title ?? AppL10n.of(context).academicTitle),
    ),
    body: Column(
      children: [
        if (widget.actions.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: widget.actions,
            ),
          ),
        // The class filter sits above the feed switcher because it is the
        // coarser choice: a student thinks "maths, then what is due", not
        // "assignments, then which class".
        if (widget.classroomId == null && choices.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(AppL10n.of(context).academicAllClasses),
                    selected: selectedClassId == null,
                    onSelected: (_) => setState(() {
                      selectedClassId = null;
                      future = _load();
                    }),
                  ),
                ),
                for (final choice in choices)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(choice.name),
                      selected: selectedClassId == choice.id,
                      onSelected: (_) => setState(() {
                        selectedClassId = choice.id;
                        future = _load();
                      }),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final value in widget.availableFeeds)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_feedLabel(AppL10n.of(context), value)),
                    selected: feed == value,
                    onSelected: (_) => setState(() {
                      feed = value;
                      future = _load();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AcademicRecord>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Unavailable(onRetry: _refresh);
              }
              final items = snapshot.data ?? const <AcademicRecord>[];
              if (items.isEmpty) {
                return Center(
                  child: Text(AppL10n.of(context).academicNoRecords),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Titles and details are school-authored content, so
                    // they render verbatim in their own direction.
                    // Only an assignment opens anything. Every caller hands the
                    // record to an assignment screen - hand-in for a student
                    // or guardian, the roster for a teacher - so a grade or an
                    // assessment tapped here used to open "hand in work" with
                    // an id that is not an assignment's.
                    final onOpen = feed == AcademicFeed.assignments
                        ? widget.onOpenRecord
                        : null;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: UserContentText(item.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinkedText(item.detail),
                            if (item.maximumScore case final score?)
                              Text(
                                AppL10n.of(context).academicGradedOutOf(
                                  score == score.roundToDouble()
                                      ? score.toInt().toString()
                                      : score.toString(),
                                ),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            // The teacher's material, openable from the list
                            // itself - the only place graded work is shown.
                            StoredAttachmentList(
                              attachments: item.attachments,
                              uploads: widget.uploads,
                              dense: true,
                            ),
                            // Only while the list spans classes. Once it is
                            // narrowed the chip would repeat the chosen chip
                            // above on every row.
                            if (_className(item) case final name?)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  name,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine:
                            _className(item) != null ||
                            item.attachments.isNotEmpty,
                        // Work a teacher has created but not released is
                        // invisible to the class; say so and offer the fix
                        // right where the teacher is looking.
                        trailing: _canPublish(item)
                            ? TextButton(
                                onPressed: () => _publish(item),
                                child: Text(
                                  AppL10n.of(context).academicPublish,
                                ),
                              )
                            : Chip(label: Text(item.state)),
                        onTap: onOpen == null ? null : () => onOpen(item),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (widget.teacherTools && feed == AcademicFeed.content)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                // Needs a class to file into: this page's own, or one of the
                // teacher's to choose from.
                onPressed: widget.classroomId == null && choices.isEmpty
                    ? null
                    : _addLesson,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(AppL10n.of(context).academicAddLesson),
              ),
            ),
          ),
      ],
    ),
  );

  /// Opens the new-lesson form. Inside a class it is for that class; on the
  /// all-classes Teaching tab the teacher picks one, starting from the class
  /// they are filtering by.
  Future<void> _addLesson() async {
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
    final added = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CreateLessonPage(
          repository: widget.repository,
          classes: classes,
          initialClassroomId: classroomId ?? selectedClassId,
          schoolId: widget.schoolId,
          uploads: widget.uploads,
          attachmentSource: widget.attachmentSource,
        ),
      ),
    );
    if (added == null || !mounted) return;
    messenger.showMessage(added);
    _refresh();
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppL10n.of(context).academicUnavailable),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppL10n.of(context).academicRetry),
        ),
      ],
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
