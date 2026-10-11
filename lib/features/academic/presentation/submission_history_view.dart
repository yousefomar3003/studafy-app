import 'package:flutter/material.dart';

import '../../../core/attachment_opener.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/studafy_formatting.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// Every attempt one student made at one piece of work, newest first.
///
/// One view for the three people who read it - the student, a guardian and
/// the teacher - so they are always looking at the same record. Each attempt
/// keeps its own text and files, and says when a parent handed it in.
class SubmissionHistoryView extends StatefulWidget {
  const SubmissionHistoryView({
    super.key,
    required this.repository,
    required this.assignmentId,
    this.studentId,
    this.uploads,
    this.shrinkWrap = false,
    this.hideWhenEmpty = false,
    this.title,
    this.onLoaded,
  });

  final AssignmentRepository repository;
  final String assignmentId;

  /// Left out by a student reading their own work.
  final String? studentId;
  final FileUploadRepository? uploads;

  /// For placing inside another scrolling page.
  final bool shrinkWrap;

  /// On the hand-in screen an empty history is simply nothing to show.
  final bool hideWhenEmpty;

  /// A heading, shown only when there is something under it.
  final String? title;

  /// Handed the attempts once they load, so a host that also needs them -
  /// the hand-in screen, for the files it can keep - does not ask again.
  final ValueChanged<List<SubmissionAttempt>>? onLoaded;

  @override
  State<SubmissionHistoryView> createState() => SubmissionHistoryViewState();
}

class SubmissionHistoryViewState extends State<SubmissionHistoryView> {
  late Future<List<SubmissionAttempt>> _attempts = _load();

  // Future.sync: a repository that throws before returning a future still
  // lands in the error branch below rather than breaking the page.
  Future<List<SubmissionAttempt>> _load() =>
      Future.sync(
        () => widget.repository.submissionHistory(
          widget.assignmentId,
          studentId: widget.studentId,
        ),
      ).then((attempts) {
        widget.onLoaded?.call(attempts);
        return attempts;
      });

  /// Reloads, for a caller that has just added an attempt.
  Future<void> refresh() async {
    final next = _load();
    setState(() => _attempts = next);
    await next.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FutureBuilder<List<SubmissionAttempt>>(
      future: _attempts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return widget.hideWhenEmpty
              ? const SizedBox.shrink()
              : const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.historyLoadFailed, textAlign: TextAlign.center),
          );
        }
        final attempts = snapshot.data ?? const <SubmissionAttempt>[];
        if (attempts.isEmpty) {
          return widget.hideWhenEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.historyNone)),
                );
        }
        final list = ListView.separated(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: widget.shrinkWrap
              ? EdgeInsets.zero
              : const EdgeInsets.all(12),
          itemCount: attempts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _AttemptCard(
            attempt: attempts[i],
            when: studafyDateTime(context, attempts[i].submittedAt),
            uploads: widget.uploads,
          ),
        );
        final title = widget.title;
        if (title == null) return list;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            widget.shrinkWrap ? list : Expanded(child: list),
          ],
        );
      },
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt, required this.when, this.uploads});

  final SubmissionAttempt attempt;
  final String when;
  final FileUploadRepository? uploads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final byGuardian = attempt.submittedByGuardianId != null;
    final name = attempt.submittedByGuardianName;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.submissionsOn(when),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    attempt.current ? l10n.historyLatest : l10n.historyEarlier,
                  ),
                ),
              ],
            ),
            // Young children hand work in from a parent's phone; whoever
            // reads this should know which attempts those were.
            if (byGuardian)
              Text(
                name == null || name.isEmpty
                    ? l10n.historyByParent
                    : l10n.historyByGuardian(name),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            if ((attempt.answerText ?? '').isEmpty)
              Text(
                l10n.historyNoText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              UserContentText(attempt.answerText!),
            StoredAttachmentList(
              attachments: attempt.attachments,
              uploads: uploads,
            ),
          ],
        ),
      ),
    );
  }
}

/// The history as a screen of its own: a teacher opening one student's work
/// from the class list.
class SubmissionHistoryPage extends StatelessWidget {
  const SubmissionHistoryPage({
    super.key,
    required this.repository,
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
  });

  final AssignmentRepository repository;
  final String assignmentId;
  final String studentId;
  final String studentName;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(studentName)),
    body: SafeArea(
      child: SubmissionHistoryView(
        repository: repository,
        assignmentId: assignmentId,
        studentId: studentId,
      ),
    ),
  );
}
