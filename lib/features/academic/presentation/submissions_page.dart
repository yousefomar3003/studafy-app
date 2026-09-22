import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

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
  });

  final AcademicRepository repository;
  final String assignmentId;
  final String assignmentTitle;
  final String classroomId;

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

  static String _when(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final handedIn = _students
        .where((s) => _forStudent(s.id)?.submittedAt != null)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.submissionsTitle(widget.assignmentTitle)),
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
                            subtitle: Text(
                              submittedAt == null
                                  ? l10n.submissionsWaiting
                                  : l10n.submissionsOn(_when(submittedAt)),
                            ),
                            onTap: work?.answerText == null
                                ? null
                                : () => showDialog<void>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text(student.displayName),
                                      content: SingleChildScrollView(
                                        child: Text(work!.answerText!),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: Text(
                                            MaterialLocalizations.of(
                                              dialogContext,
                                            ).closeButtonLabel,
                                          ),
                                        ),
                                      ],
                                    ),
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
