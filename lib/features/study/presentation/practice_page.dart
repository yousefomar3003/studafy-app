import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation.dart';
import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/user_content_text.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'notebook_paper.dart';
import 'study_set_pages.dart';

/// Flashcards and quizzes from the student's own notes (ADR-0045).
///
/// Every student sees what they are, with an example card; on Studafy Max
/// they choose notes and make one. Without Max the page says plainly that
/// Max includes it and what they can still do, and offers the plans once -
/// no list to fill in only to be refused at the end.
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.study,
    this.initialKind = StudySetKind.flashcards,
    this.preselected = const [],
    this.onOpenPlans,
    this.inClass = false,
  });

  final StudyRepository study;
  final StudySetKind initialKind;

  /// Notes already chosen, as when opened from a note's page.
  final List<String> preselected;
  final Future<void> Function()? onOpenPlans;

  /// The student is in a class, where lessons have their own buttons too.
  final bool inClass;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _Note {
  const _Note(this.entry, this.notebook);
  final NotebookEntry entry;
  final String notebook;
}

class _PracticePageState extends State<PracticePage> {
  late StudySetKind _kind = widget.initialKind;
  late final Set<String> _chosen = {...widget.preselected};
  StudyPlan? _plan;
  List<_Note>? _notes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final plan = await widget.study.plan();
      final personal = await widget.study.personalNotebook();
      List<NotebookGroup> classes;
      try {
        classes = await widget.study.myNotebooks();
      } on Object {
        // Class notebooks are an addition; the personal one is enough.
        classes = const [];
      }
      if (!mounted) return;
      final l10n = AppL10n.of(context);
      setState(() {
        _plan = plan;
        _notes = [
          for (final entry in personal) _Note(entry, l10n.nbPersonal),
          for (final group in classes)
            for (final entry in group.entries) _Note(entry, group.className),
        ];
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _make() {
    final ids = _chosen.take(20).toList();
    if (ids.isEmpty) return;
    final notes = _notes ?? const <_Note>[];
    final titles = [
      for (final note in notes)
        if (ids.contains(note.entry.id)) note.entry.title,
    ];
    final l10n = AppL10n.of(context);
    Navigator.of(context).pushOnce(
      MaterialPageRoute<void>(
        builder: (_) => StudySetPage(
          title: titles.length == 1 ? titles.first : l10n.practiceTitle,
          kind: _kind,
          plan: _plan,
          onOpenPlans: widget.onOpenPlans == null
              ? null
              : () => unawaited(widget.onOpenPlans!()),
          load: (_) => widget.study.practiseNotes(_kind, ids),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final plan = _plan;
    final notes = _notes;
    final max = plan?.canMakeStudySets ?? false;
    final on = plan?.studySetsOn ?? true;
    return Scaffold(
      backgroundColor: studafyCanvas,
      appBar: AppBar(backgroundColor: studafyCanvas),
      bottomNavigationBar: !max || !on || notes == null || notes.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.practiceChosen(_chosen.length),
                      style: const TextStyle(color: studafyMuted),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _chosen.isEmpty ? null : _make,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: Icon(
                        _kind == StudySetKind.quiz
                            ? Icons.quiz_outlined
                            : Icons.style_outlined,
                      ),
                      label: Text(
                        _kind == StudySetKind.quiz
                            ? l10n.practiceMakeQuiz
                            : l10n.practiceMakeFlashcards,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 32),
        children: [
          StudafyLargeTitle(
            title: l10n.practiceTitle,
            subtitle: l10n.practiceSubtitle,
            padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 12),
          ),
          SegmentedButton<StudySetKind>(
            segments: [
              ButtonSegment(
                value: StudySetKind.flashcards,
                icon: const Icon(Icons.style_outlined),
                label: Text(l10n.todayToolFlashcards),
              ),
              ButtonSegment(
                value: StudySetKind.quiz,
                icon: const Icon(Icons.quiz_outlined),
                label: Text(l10n.todayToolQuizzes),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (value) => setState(() => _kind = value.first),
          ),
          const SizedBox(height: 14),
          Text(
            _kind == StudySetKind.quiz
                ? l10n.practiceQuizBody
                : l10n.practiceFlashcardsBody,
            style: const TextStyle(color: studafyInk, height: 1.45),
          ),
          const SizedBox(height: 14),
          const _ExampleCard(),
          if (plan == null && !_failed)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed)
            StudafyEmptyState(
              icon: Icons.wifi_off_rounded,
              title: l10n.noteLoadFailed,
              actionLabel: l10n.todayRetry,
              onAction: _load,
            )
          else if (!on)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.studySetSwitchedOff,
                style: const TextStyle(color: studafyMuted),
              ),
            )
          else if (!max)
            _MaxCard(onOpenPlans: widget.onOpenPlans)
          else ...[
            SectionHeader(l10n.practiceChooseNotes),
            if (notes == null || notes.isEmpty)
              Text(
                l10n.practiceNoNotes,
                style: const TextStyle(color: studafyMuted),
              )
            else
              FeatureCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final note in notes)
                      CheckboxListTile(
                        value: _chosen.contains(note.entry.id),
                        onChanged:
                            !_chosen.contains(note.entry.id) &&
                                _chosen.length >= 20
                            ? null
                            : (on) => setState(() {
                                if (on == true) {
                                  _chosen.add(note.entry.id);
                                } else {
                                  _chosen.remove(note.entry.id);
                                }
                              }),
                        title: UserContentText(
                          note.entry.title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: studafyInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: UserContentText(
                          note.notebook,
                          maxLines: 1,
                          style: const TextStyle(color: studafyMuted),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (widget.inClass)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                l10n.practiceFromLessons,
                style: const TextStyle(color: studafyMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a card looks like, before anything is made: tap to turn it over.
class _ExampleCard extends StatefulWidget {
  const _ExampleCard();

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      button: true,
      label: '${l10n.practiceExample}. ${l10n.practiceTapToFlip}',
      child: GestureDetector(
        onTap: () => setState(() => _back = !_back),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: RuledPage(
            key: ValueKey(_back),
            padding: const EdgeInsetsDirectional.fromSTEB(40, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.practiceExample.toUpperCase(),
                  style: const TextStyle(
                    color: studafyMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _back ? l10n.practiceExampleBack : l10n.practiceExampleFront,
                  style: TextStyle(
                    color: studafyInk,
                    fontSize: _back ? 16 : 18,
                    fontWeight: _back ? FontWeight.w500 : FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: studafyMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.practiceTapToFlip,
                      style: const TextStyle(
                        color: studafyMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaxCard extends StatelessWidget {
  const _MaxCard({this.onOpenPlans});

  final Future<void> Function()? onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PlanBadge(StudyPlanTier.max),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.practiceMaxTitle,
                    style: const TextStyle(
                      color: studafyInk,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.practiceMaxBody,
              style: const TextStyle(color: studafyMuted, height: 1.45),
            ),
            if (onOpenPlans != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => unawaited(onOpenPlans!()),
                child: Text(l10n.nbSeePlans),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
