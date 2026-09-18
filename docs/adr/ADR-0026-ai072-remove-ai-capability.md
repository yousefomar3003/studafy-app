# ADR-0026: AI-072 — remove the AI capability

- Status: Accepted for local/disposable use
- Date: 2026-09-18
- Decision owner: repository owner (GitHub `@yousefomar3003`), the
  single-owner mapping recorded in `docs/security/sec-001-containment.md`
- Decision log: DL-047 (supersedes DL-035's "direction undecided")
- Amends: ADR-0009 (the two AI products), ADR-0024 (the `aiCoach`/`aiGrading`
  rate-limit flows), ADR-0025 (the declared `ai-grading` queue)

## Context

AI was the only capability with a shipped user interface and no task behind
it. Four student screens and a `study_coach` feature slice called two Edge
Functions:

- `propose-paper-grade` was the original SEC-001 critical vulnerability. It
  signed a caller-selected storage path with service-role credentials and sent
  it to a provider. SEC-001 reduced it to a stable 503.
- `study-coach` was **not** disabled. It forwarded up to 30 lesson-material
  bodies to whatever `STUDY_COACH_URL` named, gated only by that variable.
  Without a `classroom_id` it read every lesson material the caller could see.
  It had no redaction, budget, quota or egress allowlist, and its credentials
  were unregistered until DL-035.

Part 7C allows exactly two outcomes. Enabling requires **both** a signed data
processing agreement with an AI provider **and** a DPIA extended to AI
processing of minors' data. If either is missing, the AI surface must be
removed completely, leaving nothing a reviewer could find disabled (Apple 2.1).

## Evidence: DPA and DPIA

**Both are explicitly absent.** The owner confirmed on 2026-09-18 that neither
exists outside the repository. Every repository reference records them as
outstanding:

| Document | Status | Where the repository records it |
|---|---|---|
| Signed DPA with any AI provider | **Absent** | `inputs.md` (AI provider: "blocked … until a DPA … is signed"); `instructions.md` §22.6; `docs/security/credentials-map.md`; ADR-0009 |
| DPIA extended to AI processing of minors' data | **Absent** | `instructions.md` §15 and §20 Part 7C list it as a precondition; no assessment exists |
| AI provider selection, retention and training opt-out | **Absent** | No provider was ever contracted; only synthetic placeholders existed |

## Decision

**Remove.** The removal path is the only lawful outcome.

Removed:

- Edge Functions `study-coach` and `propose-paper-grade`. The shared
  containment helper loses `rejectFileAttachment` and the AI/upload codes that
  only these functions used.
- Flutter: `student_ai_page`, `student_ai_ask_page`, `student_ai_practice`,
  `student_ai_insights`, the `lib/features/study_coach` slice and its app
  wiring, and the Study Coach tab, so the student shell has four tabs. Also
  removed:
  - the teacher "AI-assisted paper grading" panel with its disabled
    upload/generate buttons;
  - the notebook's Summarise/Quiz me/Flashcards/Ask actions, which promised
    an "AI study screen";
  - the unwired `ApiPaperGradingRepository`, `PaperGradingRepository`,
    `AiGradingDraft`, `QuestionSuggestion` and `GradingStrictness`;
  - the preview-SQLite `saveAiGradeProposal` writer and `ai_grading_runs`
    DDL.
- Credentials: `STUDY_COACH_URL`/`STUDY_COACH_KEY` and the AI-provider slot in
  both `.env.example` files.
- API and contracts:
  - `draftId` and `questionScores` removed from the grade review/correct
    requests. They are strict objects, so a smuggled field is a 400.
  - `coach_attachment` can no longer be requested (`V1UploadablePurpose`).
  - the `aiCoach`/`aiGrading` rate-limit flows and the never-used
    `ai-grading` queue contract are gone.
- Database, via forward migration `202609180007_ai072_retire_ai_surface.sql`:
  - `ai_grading_drafts`, `question_suggestions` and `practice_sessions` lose
    every grant (anon, authenticated, service_role) and every policy.
  - `check (false) not valid` refuses every insert and update, including from
    SECURITY DEFINER code. That makes API-041's draft-approval branch
    permanently unreachable without rewriting `private.api041_command`.
  - `coach_attachment` is disabled and constrained so it cannot come back,
    with an `upload_sessions` backstop because `api050_issue_intent` does not
    itself refuse a missing policy row.
  - `student_ai`/`teacher_ai_grading` are made inactive and unlisted, and a
    constraint keeps them that way.

Deliberately kept:

- **`allowsAiGrading => false`** (`lib/core/runtime_environment.dart`). Nothing
  reads it now, but it stays as a hard-false SEC-001 tripwire and is still
  asserted by tests. Removing it is a separate reviewed change with its own
  ADR and decision-log entry, never a side effect of this one (`instructions.md`
  §21.5 is unchanged).
- The `student_ai`/`teacher_ai_grading` billing feature keys and the
  `coach_attachment` enum value in response schemas. These are retired
  vocabulary, kept so historical ledger rows and legacy file objects stay
  decodable. Postgres enum values are not dropped.
- The legacy rows in the three retired tables, kept under the retention
  schedule and deletable by the retention owner. Nothing is dropped.
- `paper_scan`, which is a teacher uploading a scanned paper for manual
  grading. It is not an AI purpose.

There is no flag and no environment variable that re-enables any of this.

## Consequences

- The shipped app contains no AI surface. The Phase 7 gate condition "the AI
  decision is resolved so no unusable AI surface ships" is met in the
  repository.
- PAY-071 sells two products (Student Notebook; Parent Insights once §29
  clears). The AI SKUs can never be listed without a new migration.
- Privacy disclosures state that no AI processing occurs
  (`docs/release/subscription-disclosure-requirements.md`).
- The two functions deployed to the synthetic project `eamewgaptdfqzpmayavx`
  on 2026-09-09 were deleted there on 2026-09-18 with the owner's go-ahead.
  Both slugs now return 404, and no `STUDY_COACH_*` secret ever existed there
  (see the evidence file). The migration is applied there at the next
  promotion.

## Rollback and future enablement

Reverting this ADR does not re-enable AI. A future AI capability needs a new
ADR, a signed DPA, a DPIA extended to minors' data, and the full enable-path
engineering in `instructions.md` §20 Part 7C:

- a named provider adapter;
- server-owned `file_object_id` only;
- per-request tenant and relationship authorization;
- redaction before egress;
- an egress allowlist;
- quotas and cost caps;
- retained audit;
- teacher review before any proposal affects a grade.

It also needs a new forward migration to replace the `ai072_*` constraints and
restore narrowly scoped grants.

## Verification

`docs/evidence/phase-7/README.md`.
