import 'package:flutter/material.dart';

import '../../../core/ai_tokens.dart';
import '../../../core/feedback.dart';
import '../../../core/studafy_design.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/academic_repository.dart';

/// How far each of a lesson's files and links has been read for the AI
/// helper (ADR-0037), with "Read again" for a teacher when one failed or
/// could not be read.
Future<void> showLessonReadingSheet(
  BuildContext context, {
  required LessonReadingRepository repository,
  required String resourceId,
  required String title,
  bool canRetry = true,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppL10n.of(context).readingTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(title, style: const TextStyle(color: studafyMuted)),
          const SizedBox(height: 8),
          Text(
            AppL10n.of(context).readingExplained,
            style: const TextStyle(color: studafyMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          LessonReadingList(
            repository: repository,
            resourceId: resourceId,
            canRetry: canRetry,
          ),
        ],
      ),
    ),
  ),
);

class LessonReadingList extends StatefulWidget {
  const LessonReadingList({
    super.key,
    required this.repository,
    required this.resourceId,
    this.canRetry = false,
  });

  final LessonReadingRepository repository;
  final String resourceId;
  final bool canRetry;

  @override
  State<LessonReadingList> createState() => _LessonReadingListState();
}

class _LessonReadingListState extends State<LessonReadingList> {
  List<LessonReadingSource>? _sources;
  bool _failed = false;
  String? _retrying;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await widget.repository.lessonReading(widget.resourceId);
      if (mounted) setState(() => _sources = sources);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _retry(LessonReadingSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    setState(() => _retrying = source.id);
    try {
      final sources = await widget.repository.retryLessonReading(
        widget.resourceId,
        source.id,
      );
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _retrying = null;
      });
      messenger.showMessage(l10n.readingRetried);
    } on Object {
      if (!mounted) return;
      setState(() => _retrying = null);
      messenger.showMessage(l10n.readingRetryFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sources = _sources;
    if (sources == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: _failed
              ? Text(l10n.readingLoadFailed)
              : const CircularProgressIndicator(),
        ),
      );
    }
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(l10n.readingNothing),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final source in sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              source.isLink
                  ? Icons.link_rounded
                  : Icons.insert_drive_file_outlined,
            ),
            title: Text(source.name),
            subtitle: Text(readingStateText(l10n, source)),
            trailing: switch (source.state) {
              ReadingState.processing => const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              ReadingState.ready => Icon(
                Icons.check_circle_rounded,
                color: source.partly ? studafySteel : studafyTeal,
              ),
              _ when widget.canRetry => TextButton(
                onPressed: _retrying == null ? () => _retry(source) : null,
                child: Text(l10n.readingRetry),
              ),
              _ => const Icon(Icons.error_outline_rounded, color: studafyMuted),
            },
          ),
      ],
    );
  }
}

/// "Ready for the AI helper", "Reading…", "Can't be read: it's a video".
String readingStateText(AppL10n l10n, LessonReadingSource source) =>
    switch (source.state) {
      ReadingState.processing => l10n.readingStateProcessing,
      ReadingState.ready =>
        source.partly ? l10n.readingPartly : l10n.readingReady,
      ReadingState.unsupported => l10n.readingStateCannot(
        readingReasonText(l10n, source.reason),
      ),
      ReadingState.failed => l10n.readingStateCannot(
        readingReasonText(l10n, source.reason),
      ),
    };
