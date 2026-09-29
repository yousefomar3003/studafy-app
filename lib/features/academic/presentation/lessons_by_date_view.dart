import 'package:flutter/material.dart';

import '../../../core/attachment_opener.dart';
import '../../../core/content_links.dart';
import '../../../core/file_upload_repository.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// One class's lessons, newest first, under a heading for each day.
///
/// Lessons are free for every enrolled student. [actionsFor] lets the host
/// put study tools under a lesson - quizzes and flashcards live in another
/// feature, so this view offers the slot rather than importing them.
class LessonsByDateView extends StatefulWidget {
  const LessonsByDateView({
    super.key,
    required this.repository,
    required this.classroomId,
    this.studentId,
    this.uploads,
    this.actionsFor,
    this.header,
  });

  final AcademicContentRepository repository;
  final String classroomId;
  final String? studentId;
  final FileUploadRepository? uploads;
  final Widget Function(BuildContext context, AcademicRecord lesson)?
  actionsFor;

  /// Above the lessons - or above "no lessons yet" - so what the host offers
  /// for them is visible before there is anything to use it on.
  final Widget Function(BuildContext context, {required bool hasLessons})?
  header;

  @override
  State<LessonsByDateView> createState() => _LessonsByDateViewState();
}

class _LessonsByDateViewState extends State<LessonsByDateView> {
  late Future<List<AcademicRecord>> _lessons = _load();

  Future<List<AcademicRecord>> _load() => Future.sync(
    () => widget.repository.load(
      AcademicFeed.content,
      classroomId: widget.classroomId,
      studentId: widget.studentId,
    ),
  );

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _heading(DateTime? day) {
    if (day == null) return AppL10n.of(context).lessonsUndated;
    final today = _day(DateTime.now());
    if (day == today) return AppL10n.of(context).notebookToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return AppL10n.of(context).notebookYesterday;
    }
    return MaterialLocalizations.of(context).formatFullDate(day);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AcademicRecord>>(
    future: _lessons,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppL10n.of(context).lessonsLessonsCouldNotBeLoaded),
                TextButton(
                  onPressed: () => setState(() => _lessons = _load()),
                  child: Text(AppL10n.of(context).studySetTryAgain),
                ),
              ],
            ),
          ),
        );
      }
      final lessons = [...?snapshot.data]
        ..sort((a, b) {
          final ad = a.date, bd = b.date;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
      final header = widget.header;
      if (lessons.isEmpty) {
        final empty = Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppL10n.of(context).lessonsNoLessonsYetTheyAppear,
            textAlign: TextAlign.center,
          ),
        );
        if (header == null) return Center(child: empty);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [header(context, hasLessons: false), empty],
        );
      }
      final children = <Widget>[
        if (header != null) header(context, hasLessons: true),
      ];
      DateTime? current;
      var first = true;
      for (final lesson in lessons) {
        final day = lesson.date == null ? null : _day(lesson.date!);
        if (first || day != current) {
          children.add(
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 6),
              child: Semantics(
                header: true,
                child: Text(
                  _heading(day),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          );
          current = day;
          first = false;
        }
        children.add(
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserContentText(
                    lesson.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (lesson.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    LinkedText(lesson.detail),
                  ],
                  StoredAttachmentList(
                    attachments: lesson.attachments,
                    uploads: widget.uploads,
                  ),
                  if (widget.actionsFor case final actions?)
                    actions(context, lesson),
                ],
              ),
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          final next = _load();
          setState(() => _lessons = next);
          await next.then((_) {}, onError: (_) {});
        },
        child: ListView(padding: const EdgeInsets.all(12), children: children),
      );
    },
  );
}
