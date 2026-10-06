import 'package:flutter/material.dart';

import '../../../core/navigation.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
import 'coursework_messages.dart';
import 'gradebook_page.dart';
import 'submission_history_view.dart';

/// What students have handed in for one assignment.
///
/// The roster is the spine, not the submissions: a teacher needs to see who
/// has *not* handed in as much as who has, and a list of submissions alone
/// silently omits exactly those students.
class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.classroomId,
    this.graded = false,
    this.assignmentVersion,
    this.timeZone,
  });

  final AcademicRepository repository;
  final String assignmentId;
  final String assignmentTitle;
  final String classroomId;

  /// Graded work is marked in the gradebook; this offers the way there.
  final bool graded;

  /// Needed to reopen the work for the class; without it that is not offered.
  final int? assignmentVersion;

  /// The school's zone, in which extra time and reopening are picked.
  final String? timeZone;

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  List<ClassStudent> _students = const [];
  List<SubmittedWork> _work = const [];
  Map<String, AssignmentExtension> _extensions = const {};
  bool _loading = true;
  String? _error;
  late String _loadFailed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFailed = AppL10n.of(context).submissionsLoadFailed;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await widget.repository.classStudents(
        widget.classroomId,
      );
      final work = await widget.repository.submissionsFor(widget.assignmentId);
      // Extra time is detail on the roster, not the roster: if it cannot
      // be read, the teacher still sees who handed in.
      var extensions = const <AssignmentExtension>[];
      try {
        extensions = await widget.repository.assignmentExtensions(
          widget.assignmentId,
        );
      } on Object {
        extensions = const [];
      }
      if (!mounted) return;
      setState(() {
        _students = students;
        _work = work;
        _extensions = {for (final x in extensions) x.studentId: x};
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _loadFailed;
      });
    }
  }

  SubmittedWork? _forStudent(String studentId) =>
      _work.where((item) => item.studentId == studentId).firstOrNull;

  /// Asks for a date, a time on the school's clock and a reason.
  Future<(String, String)?> _askUntil(String title) async {
    final l10n = AppL10n.of(context);
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      helpText: title,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      helpText: widget.timeZone == null
          ? title
          : l10n.deadlineSchoolTime(widget.timeZone!),
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null || !mounted) return null;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reason,
          maxLength: 500,
          decoration: InputDecoration(labelText: l10n.deadlineReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.paperGradesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deadlineSave),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return null;
    String two(int value) => value.toString().padLeft(2, '0');
    final local =
        '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-'
        '${two(day.day)}T${two(time.hour)}:${two(time.minute)}';
    return (local, text);
  }

  Future<void> _run(Future<void> Function() command) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await command();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deadlineSaved)));
      await _load();
    } on CourseworkRefusal catch (refusal) {
      messenger.showSnackBar(
        SnackBar(content: Text(courseworkMessage(l10n, refusal))),
      );
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.courseworkFailed)));
    }
  }

  Future<void> _extend(ClassStudent student) async {
    final l10n = AppL10n.of(context);
    final answer = await _askUntil(l10n.deadlineExtend);
    if (answer == null) return;
    if (answer.$2.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.courseworkReasonRequired)));
      }
      return;
    }
    await _run(
      () => widget.repository.grantExtension(
        widget.assignmentId,
        student.id,
        answer.$1,
        answer.$2,
      ),
    );
  }

  Future<void> _reopen() async {
    final version = widget.assignmentVersion;
    if (version == null) return;
    final l10n = AppL10n.of(context);
    final answer = await _askUntil(l10n.deadlineReopen);
    if (answer == null) return;
    if (answer.$2.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.courseworkReasonRequired)));
      }
      return;
    }
    await _run(
      () => widget.repository.reopenAssignment(
        widget.assignmentId,
        version,
        answer.$1,
        answer.$2,
      ),
    );
  }

  String _when(String local) {
    final at = DateTime.tryParse(local);
    if (at == null) return local;
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(at)} '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final handedIn = _students
        .where((s) => _forStudent(s.id)?.submittedAt != null)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.submissionsTitle(widget.assignmentTitle)),
        actions: [
          if (widget.graded)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushOnce(
                MaterialPageRoute<void>(
                  builder: (_) => ClassGradebookPage(
                    repository: widget.repository,
                    classroomId: widget.classroomId,
                    classroomName: widget.assignmentTitle,
                    focusAssignmentId: widget.assignmentId,
                  ),
                ),
              ),
              icon: const Icon(Icons.grade_outlined),
              label: Text(l10n.submissionsGrade),
            ),
          if (widget.assignmentVersion != null)
            IconButton(
              tooltip: l10n.deadlineReopen,
              onPressed: _loading ? null : _reopen,
              icon: const Icon(Icons.lock_open_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : _students.isEmpty
            ? Center(child: Text(l10n.submissionsNone))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.submissionsCount(handedIn, _students.length),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StudafyRefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _students.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final student = _students[i];
                          final work = _forStudent(student.id);
                          final submittedAt = work?.submittedAt;
                          return ListTile(
                            leading: Icon(
                              submittedAt == null
                                  ? Icons.schedule_outlined
                                  : Icons.check_circle_outline,
                              color: submittedAt == null
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(student.displayName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  submittedAt == null
                                      ? l10n.submissionsWaiting
                                      : l10n.submissionsOn(
                                          studafyDateTime(context, submittedAt),
                                        ),
                                ),
                                // Young children hand work in from a parent's
                                // phone. Marking it without knowing that is
                                // marking work without knowing whose it is.
                                if (_extensions[student.id] case final x?)
                                  Text(
                                    l10n.deadlineExtendedUntil(
                                      _when(x.untilLocal),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                if (work?.submittedByGuardianId != null)
                                  Text(
                                    l10n.submissionsByGuardian,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                              ],
                            ),
                            // Every attempt, not only the latest: what was
                            // replaced, when, and which a parent filed.
                            onTap: submittedAt == null
                                ? null
                                : () => Navigator.of(context).pushOnce(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SubmissionHistoryPage(
                                        repository: widget.repository,
                                        assignmentId: widget.assignmentId,
                                        studentId: student.id,
                                        studentName: student.displayName,
                                      ),
                                    ),
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  onSelected: (choice) => choice == 'extend'
                                      ? _extend(student)
                                      : _run(
                                          () =>
                                              widget.repository.revokeExtension(
                                                widget.assignmentId,
                                                student.id,
                                              ),
                                        ),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'extend',
                                      child: Text(l10n.deadlineExtend),
                                    ),
                                    if (_extensions.containsKey(student.id))
                                      PopupMenuItem(
                                        value: 'revoke',
                                        child: Text(
                                          l10n.deadlineRemoveExtension,
                                        ),
                                      ),
                                  ],
                                ),
                                if (submittedAt != null)
                                  Icon(forwardChevron(context)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
