import 'package:flutter/material.dart';

import '../../../core/studafy_components.dart';
import '../../../core/studafy_design.dart';
import '../../../core/studafy_formatting.dart';
import '../../../l10n/generated/app_l10n.dart';
import '../domain/study.dart';
import 'notebook_paper.dart';
import 'study_plan_copy.dart';
import 'study_set_pages.dart';

/// What Studafy Plus and Studafy Max do, before what they cost: for each
/// plan the student does not have yet, a worked example drawn with the real
/// notebook and quiz screens (labelled Example), what it includes with its
/// AI allowance stated as the server sets it, then why the student can
/// trust it. Nothing for a student already on Max.
class StudyPlanExplainer extends StatelessWidget {
  const StudyPlanExplainer({
    super.key,
    required this.held,
    this.plusKey,
    this.maxKey,
  });

  /// The plan the student has: plans it includes are not explained again.
  final StudyPlanTier held;

  /// On each plan's heading, so the page can open at that plan.
  final Key? plusKey;
  final Key? maxKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final times = studafyNumber(
      context,
      studyAllowancePlusMonthly ~/ studyAllowanceFreeWeekly,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!held.includes(StudyPlanTier.plus)) ...[
          SectionHeader(l10n.studyLandingPlusTitle, key: plusKey),
          _Lead(l10n.studyLandingPlusLead),
          const StudyPlusExample(),
          const SizedBox(height: 10),
          FeatureCard(
            child: PlanChecklist(
              items: [
                l10n.studyIncludesPlusPhotos,
                l10n.studyIncludesPlusLessons,
                l10n.studyIncludesPlusAllowance(times),
              ],
            ),
          ),
        ],
        if (!held.includes(StudyPlanTier.max)) ...[
          SectionHeader(l10n.studyLandingMaxTitle, key: maxKey),
          _Lead(l10n.studyLandingMaxLead),
          const StudyMaxExample(),
          const SizedBox(height: 10),
          FeatureCard(
            child: PlanChecklist(
              items: [
                l10n.studyIncludesMaxQuizzes,
                l10n.studyIncludesMaxCards,
                l10n.studyIncludesMaxAllowance,
              ],
            ),
          ),
          SectionHeader(l10n.studyTrustTitle),
          FeatureCard(
            child: PlanChecklist(
              icon: Icons.verified_user_outlined,
              items: [
                l10n.studyTrustNames,
                l10n.studyTrustCheck,
                l10n.studyTrustAds,
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One line under a plan's heading.
class _Lead extends StatelessWidget {
  const _Lead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
    child: Text(text, style: const TextStyle(color: studafyInk, height: 1.4)),
  );
}

/// Studafy Plus, worked: a photo of the board, then the tidy note made from
/// it, on the same ruled page and with the same "From a photo" badge as a
/// real note. The photo is drawn, not a picture of anyone's board.
class StudyPlusExample extends StatelessWidget {
  const StudyPlusExample({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final sample = NotebookEntry(
      id: 'example',
      classroomId: null,
      title: l10n.studyExampleNoteTitle,
      body: '',
      fromWhiteboard: true,
      createdAt: DateTime(2026),
    );
    return FeatureCard(
      tint: studafySky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanExampleHeader(
            label: l10n.planExampleLabel,
            note: l10n.studyExamplePlusNote,
          ),
          const SizedBox(height: 12),
          _BoardPhoto(caption: l10n.studyExamplePhoto),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Icon(
              Icons.arrow_downward_rounded,
              color: studafyMuted,
              size: 22,
            ),
          ),
          RuledPage(
            padding: const EdgeInsetsDirectional.fromSTEB(40, 16, 16, 18),
            spacing: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NoteSourceBadge(sample),
                const SizedBox(height: 8),
                Text(
                  sample.title,
                  style: const TextStyle(
                    color: studafyInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in [
                  l10n.studyExampleNoteLine1,
                  l10n.studyExampleNoteLine2,
                  l10n.studyExampleNoteLine3,
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '•',
                          style: TextStyle(color: studafyInk, height: 1.4),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(
                              color: studafyInk,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A board drawn with a few chalk strokes, captioned as a photo.
class _BoardPhoto extends StatelessWidget {
  const _BoardPhoto({required this.caption});

  final String caption;

  static const _board = Color(0xFF263E39);

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: caption,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _board,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8A6A47), width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [.55, .8, .7, .45])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FractionallySizedBox(
                widthFactor: width,
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Studafy Max, worked: a quiz question answered and checked, as the quiz
/// shows it, and a flashcard that turns over when tapped, as the cards do.
class StudyMaxExample extends StatefulWidget {
  const StudyMaxExample({super.key});

  @override
  State<StudyMaxExample> createState() => _StudyMaxExampleState();
}

class _StudyMaxExampleState extends State<StudyMaxExample> {
  bool _back = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return FeatureCard(
      tint: studafySky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanExampleHeader(
            label: l10n.planExampleLabel,
            note: l10n.studyExampleMaxNote,
          ),
          const SizedBox(height: 12),
          QuizQuestionCard(
            number: 1,
            count: 5,
            question: QuizQuestion(
              question: l10n.studyExampleQuizQuestion,
              options: [
                l10n.studyExampleQuizOxygen,
                l10n.studyExampleQuizCarbon,
                l10n.studyExampleQuizNitrogen,
              ],
              answerIndex: 1,
              explanation: l10n.studyExampleQuizWhy,
            ),
            chosen: 1,
            checked: true,
            onChoose: (_) {},
          ),
          SizedBox(
            height: 190,
            child: FlashcardFlip(
              scrollsInside: false,
              front: l10n.practiceExampleFront,
              back: l10n.practiceExampleBack,
              showBack: _back,
              onTap: () => setState(() => _back = !_back),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: studafyMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.practiceTapToFlip,
                  style: const TextStyle(color: studafyMuted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
