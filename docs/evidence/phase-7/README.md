# Phase 7 evidence

## Part 7C — AI capability (`AI-072`): removed

Date: 2026-09-18 · Decision: **REMOVE** · Owner: repository owner (GitHub
`@yousefomar3003`) · Record: ADR-0026, DL-047 · Branch:
`feat/ai072-remove-ai-capability` · Target: local/disposable only.

### Decision evidence

| Precondition for enabling | Status | Reference |
|---|---|---|
| Signed DPA with an AI provider | **Absent.** Confirmed by the owner 2026-09-18; the repository records it as outstanding | `inputs.md`, `instructions.md` §22.6, `docs/security/credentials-map.md`, ADR-0009 |
| DPIA extended to AI processing of minors' data | **Absent.** Confirmed by the owner 2026-09-18 | `instructions.md` §15, §20 Part 7C |

With either one missing, removal is the only lawful outcome (§20 Part 7C).

### Removal inventory

| Layer | Removed | Retired but kept (with reason) |
|---|---|---|
| Edge Functions | `study-coach`, `propose-paper-grade`; `rejectFileAttachment` and the AI/upload containment codes only they used | — |
| Flutter screens | Four student AI pages; Study Coach tab (the student shell now has four tabs); teacher "AI-assisted paper grading" panel with its disabled buttons; notebook Summarise/Quiz me/Flashcards/Ask actions ("…ready for the AI study screen") | — |
| Flutter code | `lib/features/study_coach/**`, app wiring and `StudyCoachScope`; `ApiPaperGradingRepository`, `PaperGradingRepository`, `AiGradingDraft`, `QuestionSuggestion`, `GradingStrictness`; `FilePurpose.coachAttachment`; SQLite `saveAiGradeProposal` and the `ai_grading_runs` DDL | `allowsAiGrading => false`, retained as the SEC-001 tripwire (ADR-0026) |
| Credentials | `STUDY_COACH_URL`, `STUDY_COACH_KEY`, the AI-provider slot in both `.env.example` files | — |
| API/contracts | `draftId`/`questionScores` on grade review/correct; `coach_attachment` in upload requests; `aiCoach`/`aiGrading` rate-limit flows; the declared `ai-grading` queue and `AiGradingJobV1` | `student_ai`/`teacher_ai_grading` billing keys, and `coach_attachment` in response schemas, so historical rows stay decodable |
| Database (`202609180007`) | Every grant and policy on `ai_grading_drafts`, `question_suggestions`, `practice_sessions`; all writes refused; `coach_attachment` disabled and constrained; AI store products inactive, unlisted and constrained | Legacy rows are kept for the retention owner; no table, column or enum value is dropped |

`scripts/verify-synthetic-attachment-containment.ts` probed the two deleted
functions. It is replaced by `scripts/verify-synthetic-ai-removal.ts`, which is
read-only and expects 404 from both slugs.

### Tests (removal-path form of the Part 7C list)

| Required test | How it is satisfied on the removal path | Where |
|---|---|---|
| No AI route, screen or credential remains | Function directories, slice and pages are absent. A source scan of `lib` and `supabase/functions` finds no AI route, credential, control or `AI` label. Neither `.env.example` declares an AI variable. The student shell renders 4 tabs and no Study Coach. The route catalogue, permissions, rate-limit flows and queue inventory name no AI capability | `test/ai072_removal_test.dart`, `apps/api/test/ai072/removal.test.ts` |
| Path and URL substitution denied | Review/correct reject `draftId`, `questionScores`, `privateScan`, `storage_path`, `attachment_path` and `providerUrl`. `coach_attachment` cannot be requested. A draft insert carrying a substituted private path is refused by the database | `apps/api/test/ai072/removal.test.ts`, `supabase/tests/ai072_removal.sql` |
| Cross-tenant material denied | Another school's teacher, a same-school student and `service_role` all get `42501` on the retired relations, because no grant exists. A review naming a draft returns `invalid_state` and leaves the grade `draft:null:1` | `supabase/tests/ai072_removal.sql` |
| Egress-allowlist bypass denied | No egress path exists. No Edge Function calls `fetch`, and no runnable source reads an AI credential or names an AI provider host | `apps/api/test/ai072/removal.test.ts`, `test/release_containment_test.dart` |
| AI SKUs cannot be sold | No AI product is active or listed. No environment's catalogue offers one. Re-activating or inserting one violates `ai072_ai_products_retired` | `supabase/tests/ai072_removal.sql` |
| Redaction proven | **Not applicable.** Nothing leaves the tenant, so there is nothing to redact. No test is claimed | — |
| Quota exhaustion | **Not applicable.** No AI request exists to meter; the AI rate-limit flows are removed | — |
| Provider outage and timeout | **Not applicable.** There is no provider | — |

**The pgTAP test is proven not to pass vacuously.** Run against the schema at
`202609180006` (every migration except AI-072), `ai072_removal_seed.sql`
fails 16 of 20 assertions. The four that still pass are pre-existing
guarantees kept as regression guards: no authenticated grant on drafts, a
grade left unchanged, non-AI purposes intact, and non-AI products active. With
`202609180007` applied, all 20 pass.

### Verification results (2026-09-18, local)

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 150 passed, 0 failed |
| `dart run tools/check_dart_bounds.dart` | 61 feature files, 0 violations |
| `deno test --frozen=true` | 1 passed, 0 failed |
| `bun run typecheck` | api, worker, infrastructure exit 0. The first run failed because the PAY-071 billing dependencies were not installed; `bun install --frozen-lockfile` installed them exactly as locked, and the lockfile is unchanged |
| `bun run lint` / `format:check` / `generate:check` / `check:bounds` | Pass (204 / 227 files; generation current; 0 boundary violations) |
| `bun test apps packages` (Redis from `docker-compose.dev.yml`) | 520 passed, 0 failed on two consecutive runs. One earlier run had a single failure in `OPS-061 … backlog drain … zero lag`, a timing-sensitive test this change does not touch. It passes in isolation and in both reruns |
| Local Supabase, CI database job replica | Upgrade path: pre-DB-020 legacy seed → all migrations, including `202609180007`, over legacy draft rows → `db020_upgrade` 18/18. DB-021 upgrade seed → `db021_upgrade` + `db021_grants` 33/33. Full replay from zero, then `supabase db lint --level error` is clean |
| Every pgTAP entry point in `supabase/tests` (28 runs; `db021_grants` runs twice, as in CI) | 772 assertions, all PASS, including `ai072_removal_seed.sql` 20/20, the updated `api041_academic_seed.sql` 30/30 and `db021_grants.sql` 25/25 |
| Query-plan verifiers (db020, db021, api041, file050, file051, ops061) | All exit 0 |

CI runs the new pgTAP file as "Verify AI-072 removal leaves no AI data path"
(`.github/workflows/ci.yml`).

### Pending owner actions (not performed: remote systems are out of scope)

1. **Delete the deployed functions from the synthetic project.** Both
   `study-coach` and `propose-paper-grade` were ACTIVE at version 1 in
   `eamewgaptdfqzpmayavx` at the last inspection (2026-09-10). Removing them
   from the repository does not undeploy them. Run
   `supabase functions delete study-coach --project-ref eamewgaptdfqzpmayavx`,
   then the same for `propose-paper-grade`.
2. **Unset any `STUDY_COACH_URL` / `STUDY_COACH_KEY` project secret** in that
   project (`supabase secrets list` / `unset`), and confirm that no AI-provider
   key exists anywhere.
3. **Verify:** `supabase projects api-keys --project-ref eamewgaptdfqzpmayavx
   --output json | bun scripts/verify-synthetic-ai-removal.ts
   --project-ref=eamewgaptdfqzpmayavx` must print `"passed":true`, with both
   slugs returning 404.
4. **Apply `202609180007` to the synthetic project** when migrations are next
   promoted there, following the usual dry-run procedure.
5. **Retention owner:** decide when to delete legacy rows in the three retired
   relations. None exist in the synthetic project, which has zero data.

Until items 1–3 are done, the repository and the synthetic project disagree.
Security-owner approval of this change remains pending, as for every earlier
phase.
