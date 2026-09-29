import 'package:flutter/material.dart';

import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';
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
  });

  final AcademicRepository repository;
  final String assignmentId;
  final String assignmentTitle;
  final String classroomId;

  /// Graded work is marked in the gradebook; this offers the way there.
  final bool graded;

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  List<ClassStudent> _students = const [];
  List<SubmittedWork> _work = const [];
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
      if (!mounted) return;
      setState(() {
        _students = students;
        _work = work;
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
              onPressed: () => Navigator.of(context).push(
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
                    child: RefreshIndicator(
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
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SubmissionHistoryPage(
                                        repository: widget.repository,
                                        assignmentId: widget.assignmentId,
                                        studentId: student.id,
                                        studentName: student.displayName,
                                      ),
                                    ),
                                  ),
                            trailing: submittedAt == null
                                ? null
                                : Icon(forwardChevron(context)),
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
