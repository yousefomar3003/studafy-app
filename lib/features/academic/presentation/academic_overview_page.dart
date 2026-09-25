import 'package:flutter/material.dart';

import '../domain/academic_repository.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/attachment_field.dart';
import '../../../core/platform_attachment_source.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';

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

  /// Opens one row. A student taps an assignment to hand work in; nothing
  /// opens where no handler is given, so other feeds stay read-only.
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

  Future<List<AcademicRecord>> _load() => widget.repository.load(
    feed,
    classroomId: widget.classroomId ?? selectedClassId,
    studentId: widget.studentId,
  );

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
                    final onOpen = widget.onOpenRecord;
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
                            UserContentText(item.detail),
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
                        isThreeLine: _className(item) != null,
                        trailing: Chip(label: Text(item.state)),
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
                onPressed: widget.classroomId == null ? null : _fileNote,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(AppL10n.of(context).academicFileNote),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _fileNote() async {
    final title = TextEditingController();
    final body = TextEditingController();
    String? error;
    var attachments = const <Attachment>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppL10n.of(context).academicNoteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).academicNoteTitleLabel,
                ),
              ),
              TextField(
                controller: body,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AppL10n.of(context).academicNoteBodyLabel,
                ),
              ),
              const SizedBox(height: 8),
              // Each attached file becomes class material in its own right
              // once published, which is how the server models it - the note
              // above is a separate resource, not a carrier for them.
              if (widget.uploads case final uploads?)
                if (widget.schoolId case final schoolId?)
                  AttachmentField(
                    purpose: FilePurpose.lessonResource,
                    schoolId: schoolId,
                    classroomId: widget.classroomId,
                    uploads: uploads,
                    source: widget.attachmentSource ?? pickPlatformAttachment,
                    onChanged: (items) =>
                        setDialogState(() => attachments = items),
                  )
                else
                  Text(AppL10n.of(context).academicAttachmentsUnavailable)
              else
                Text(AppL10n.of(context).academicAttachmentsUnavailable),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppL10n.of(context).academicCancel),
            ),
            FilledButton(
              // Refused while anything is still in flight: a note saved now
              // would be filed without the file the teacher is waiting on.
              onPressed:
                  attachments.any((a) => a.stage == AttachmentStage.uploading)
                  ? null
                  : () async {
                      try {
                        await widget.repository.createResource(
                          TextResourceDraft(
                            classroomId: widget.classroomId!,
                            title: title.text,
                            body: body.text,
                          ),
                        );
                        // Each upload becomes its own piece of class
                        // material. A file that failed or was refused is
                        // simply not among them.
                        final uploads = widget.uploads;
                        if (uploads != null) {
                          for (final item in attachments) {
                            final fileId = item.fileId;
                            if (fileId == null) continue;
                            await uploads.publishToClass(
                              fileId: fileId,
                              audience: FileAudience.students,
                            );
                          }
                        }
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        _refresh();
                      } catch (_) {
                        setDialogState(
                          () =>
                              error = AppL10n.of(context).academicNoteNotSaved,
                        );
                      }
                    },
              child: Text(AppL10n.of(context).academicSaveToSchool),
            ),
          ],
        ),
      ),
    );
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
