import 'package:flutter/material.dart';

import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Who is in a class, and who to talk to about them.
///
/// Guardians are shown by name only. Contact runs through Studafy's own
/// messaging, which is moderated and logged, rather than by handing a
/// teacher a family's phone number.
class ClassRosterPage extends StatefulWidget {
  const ClassRosterPage({
    super.key,
    required this.repository,
    required this.classroomId,
    required this.classroomName,
    this.onMessageGuardian,
  });

  final AcademicRepository repository;
  final String classroomId;
  final String classroomName;

  /// Opens a conversation with a guardian. Null where messaging is not
  /// available, and the contact action is then hidden rather than offered
  /// and then refused.
  final void Function(StudentGuardian guardian)? onMessageGuardian;

  @override
  State<ClassRosterPage> createState() => _ClassRosterPageState();
}

class _ClassRosterPageState extends State<ClassRosterPage> {
  List<ClassStudent> _students = const [];
  late final String _loadFailedMessage;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations are inherited, so copy used off the build path is
    // resolved here rather than in initState.
    _loadFailedMessage = AppL10n.of(context).rosterLoadFailed;
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
      if (!mounted) return;
      setState(() {
        _students = students;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _loadFailedMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppL10n.of(context).rosterTitle(widget.classroomName)),
    ),
    body: SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Message(text: _error!, onRetry: _load)
          : _students.isEmpty
          ? _Message(text: AppL10n.of(context).rosterEmpty)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _students.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _StudentTile(
                  student: _students[i],
                  onMessageGuardian: widget.onMessageGuardian,
                ),
              ),
            ),
    ),
  );
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onMessageGuardian});

  final ClassStudent student;
  final void Function(StudentGuardian guardian)? onMessageGuardian;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(student.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            student.studafyId,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (student.guardians.isEmpty)
            // Said plainly rather than left blank: no linked guardian means
            // there is nobody for the teacher to reach.
            Text(
              AppL10n.of(context).rosterNoGuardian,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final guardian in student.guardians)
                  onMessageGuardian == null
                      ? Chip(
                          avatar: const Icon(Icons.person_outline, size: 18),
                          label: Text(guardian.displayName),
                        )
                      : ActionChip(
                          avatar: const Icon(Icons.forum_outlined, size: 18),
                          label: Text(guardian.displayName),
                          onPressed: () => onMessageGuardian!(guardian),
                        ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppL10n.of(context).rosterTryAgain),
            ),
          ],
        ],
      ),
    ),
  );
}
