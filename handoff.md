# Handoff: Studafy study AI, notebooks and material selection

Date: 2026-10-07. Branch: `feat/mvp-school-operations-and-hosted-testing` (not merged to `main`).

## 1. Goal

Make Studafy's AI study features dependable and clear for students:

- **Grounded AI and allowances.** The AI reads lesson attachments (PDF, Word, PowerPoint, images, links) and cites them. It runs under one shared token allowance per student: Free 40k a week, Plus 3M a month, Max 6M a month. This is ADR-0037.
- **Quizzes, flashcards and notebooks.** Quizzes and flashcards work again. Students can make organised study notebooks from lessons, with their own notes, highlights, bookmarks and sections. This is ADR-0038.
- **Exact material.** Every AI feature (AI Helper, summaries, quizzes, flashcards, notebooks) uses exactly the material the student picks, in one shared picker. The server enforces it. This is ADR-0039.
- **No token numbers.** AI usage appears as a bar with plain labels. Token accounting stays on the server.
- **Phone testing.** The owner tests on an iPhone 14 Pro and an iOS simulator against the Fly test copy.

## 2. Current status

- **Everything is committed.** The latest commit is `7255221`. The working tree holds only files that must stay uncommitted (see the end of section 6).
- **Deployed.** Migrations up to `202610070003_material_selection.sql` are applied to the hosted Frankfurt test database, and the Fly test API (`studafy-api-test`) and worker are redeployed.
- **On the devices.** The latest build is installed on the iPhone (profile build) and running on the simulator.
- **Tests pass:**
  - 945 backend tests (`bun test apps packages`);
  - all 37 database test suites, run in CI order on the throwaway database;
  - 743 Flutter tests.
  - Analyze, lint, typecheck, the generated-code check and the Dart bounds check are clean.
- **Known gate failure.** `bun run check:migrations` fails on `202610060001_online_assessments.sql` and `202610070001_grounded_material_and_token_allowances.sql`. Both rename functions to wrap them, which ADR-0030 bans. This predates the latest work, and CI will fail on it.
- **Not yet checked by a person.** No one has used the new features signed in as a student on the test copy. Automated tests and a direct run of the real model on sample material pass.
- **Real model behaviour seen:**
  - an English notebook takes about 14s;
  - an Arabic notebook takes 8–14s;
  - a quiz takes about 6–9s;
  - flashcards take about 4–5s;
  - the provider (Together, Qwen3.5-9B) once returned a transient 503.

## 3. Active files

**Backend (`apps/api/src/study/`)**
- `selection.ts`: resolves and validates the chosen references, gathers exactly that material, and fingerprints it.
- `selectionRoutes.ts`: `POST /v1/study-sets` and `POST /v1/classrooms/{id}/notebook/summary`.
- `studyNotebookRoutes.ts`: notebook routes, including background generation.
- `material.ts`, `metering.ts`: material retrieval and AI usage metering, used by the routes above.
- `apps/api/src/study-assistant/routes.ts`: the helper uses the exact selection.
- `apps/api/src/composition/routes.ts`: where modules are mounted (the order must match the catalogue).
- `apps/api/src/authorization/catalogue.ts`: permissions, including `study_notebook.*` and `material_set.generate`.

**Contracts (`packages/contracts/src/v1/`)**
- `materialSelection.ts`, `studyNotebooks.ts`, `studyAssistant.ts`, `routes.ts`.

**Domain and infrastructure**
- `packages/domain/src/study/notebook.ts`: notebook parsing.
- `packages/domain/src/study/studyContent.ts`: stricter quiz and flashcard parsers that also recover cut-off replies.
- `packages/infrastructure/src/studyAssistant.ts`: the model calls.

**Database**
- Migrations: `supabase/migrations/202610070002_study_notebooks.sql` and `202610070003_material_selection.sql`.
- Tests: `supabase/tests/study_notebooks.sql`, `material_selection.sql`, and `auth030_grants.sql` (the reviewed list of API functions).

**App**
- Shared code:
  - `lib/core/material_selection.dart`;
  - `lib/core/material_unavailable_dialog.dart`;
  - `lib/core/ai_usage.dart`;
  - `lib/core/ai_tokens.dart`.
- Pages that compose features: `lib/app/material_picker.dart`, `student_lessons_page.dart`, `student_shell.dart`, `account_hub_page.dart`.
- Study screens (`lib/features/study/presentation/`):
  - `study_set_pages.dart`;
  - `study_notebook_page.dart`;
  - `study_notebook_shelf.dart`;
  - `notebook_cover.dart`;
  - `notes_text.dart`;
  - `notebook_view.dart`.
- Study data: `lib/features/study/domain/study.dart`, `study_notebook.dart`, and `data/api_study_repository.dart`.
- Helper: `lib/features/study_assistant/` (domain, data and presentation).
- Other:
  - `lib/data/contracts/v1_http_transport.dart` (notebook reads are marked live);
  - `scripts/generate-dart-client.ts` (handles nullable lists);
  - `lib/l10n/app_en.arb` and `app_ar.arb`.

**Docs**
- `docs/adr/ADR-0037…`, `ADR-0038-study-notebooks.md`, `ADR-0039-exact-material-selection-and-ai-usage.md`.

## 4. Changes made

**Quizzes and flashcards (`22489ac`, `9c21ac8`)**
- **Root cause:** the generated Dart client crashed on the `null` half of a study set. A quiz has `cards: null` and flashcards have `questions: null`. The generator now reads nullable lists as nullable.
- **Reply parsing:**
  - study sets have their own 1,400-token output budget;
  - a reply cut off at the limit keeps its complete items;
  - duplicate or malformed items are dropped;
  - a set with fewer than 3 questions or 4 cards fails, and the AI usage held for it is released.
- **Quizzes:** answer everything, then check, with a score and explanations.
- **Flashcards:** they flip, and the student marks "I knew it" or "Still learning".
- **Every set:** loading, empty and error states, with Try again.

**Study notebooks (`9c21ac8`, ADR-0038)**
- **Writing:** a notebook is written in the background from one lesson, in a fixed structure with citations. Generation is metered once per generation.
- **The notebook itself:**
  - a cover, contents and numbered pages, on lined, plain or grid paper;
  - notes, highlights, bookmarks, the student's own sections, and renamed headings;
  - saves are versioned and merged with copies saved elsewhere.
- **Updates:** "Update available" appears when the lesson changes. Updating rewrites only the AI part.
- **Practice:** quizzes and flashcards from a notebook are kept per notebook version.
- **Old entries:** old notebook entries render Markdown properly.

**App icon (`9c23886`)**
- The Studafy icon replaces Flutter's on iOS, Android and macOS. The source image is `assets/brand/source/app_icon.png`.

**Exact material selection and AI usage (`7255221`, ADR-0039)**
- **References:**
  - `lesson` means the whole lesson;
  - `text` means the lesson's own text only;
  - `file` and `link` mean one attachment;
  - `note` means one of the student's notes, for the helper only.
- **Server refusals:**
  - lessons the student cannot see;
  - files that are not on the lesson named;
  - more than 10 lessons.
- **Unreadable files:** the server returns `MATERIAL_UNAVAILABLE` naming each file. They are skipped only when the request says `skipUnavailable`.
- **Bug fixed:** the helper used to widen a whole-lesson choice to every file of every chosen lesson.
- **New routes:** quizzes and flashcards from a selection (Max), and summaries into the class notebook (Plus). Results are kept in `private.material_outputs` by a fingerprint of the selection, and access is re-checked on every read.
- **Notebooks:** they record `whole_lesson` and `include_text`.
- **One picker in the app:**
  - class, then lesson, then the lesson's text and each attachment;
  - search, filters, a persistent summary line, a review sheet and specific action buttons;
  - a whole class only after a confirmation;
  - the helper shows its material above the chat and marks changes in the chat.
- **AI usage:**
  - a profile section with a bar, a level label, the reset date and an upgrade button;
  - every token count removed from the interface and messages.

**Also fixed**
- `committedJson` is only for routes whose SQL already stored the response against the idempotency key. Other routes now use `c.json`, so retries replay correctly.
- Notebook list and notebook reads are excluded from the app's short read cache, so progress polling sees changes.

## 5. Failed attempts

- **`committedJson` misuse.** Using it on routes whose SQL does not store the response left idempotency keys stuck "in progress". The lesson reading retry route had the same bug. Fixed by using `c.json`.
- **Text-only notebooks widened.** A notebook from a lesson's text alone was first stored with an empty source list, which the database reads as "whole lesson". Fixed with an explicit `whole_lesson` column.
- **Tests ran against the local database.** Running `bun test` without `DATABASE_URL` picked up `.env` and hit the local DB on port 54322. Nothing was left behind, but always set `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55722/postgres`, the throwaway stack whose workdir is the session scratchpad's `annstack`.
- **Paper styling hid ripples.** A coloured `DecoratedBox` behind the notebook pages hid tap ripples and tripped ListTile assertions. Fixed by using a `Material` surface.
- **Dialog controller disposed early.** A text dialog's controller was disposed while the dialog was still closing. Fixed with a dialog widget that owns its controller.
- **Brittle scripted edits.** Python string replacements failed where `dart format` had reflowed the code. Re-read the file before editing.
- **Live debugging on the phone.** `flutter attach` to the profile build on the phone kept losing its connection. Diagnose from server logs and the database instead.
- **Wrong test fixture.** In pgTAP, the seed guardian can see the lessons, so use `other_school_user` as the outsider in access tests.

## 6. Next steps

1. **Check the new features on the phone**, signed in as a student on the test copy:
   - the picker opened from a lesson;
   - "Select entire class";
   - the "Continue without them" dialog;
   - summaries;
   - a notebook from the lesson text only;
   - the helper context bar and its change marker;
   - Profile → AI usage, in both English and Arabic.
2. **Fix the CI migration gate.** Rework the function wrapping in `202610060001` and `202610070001` to follow ADR-0030, using a forward migration with named handlers. Both are already applied to the hosted test database, so don't edit them in place.
3. **Decide whether to make background notebook writing durable**, by moving it to a worker queue. Today it runs inside the API process: if the machine stops mid-write, the notebook times out after 10 minutes and the student retries.
4. **Possible follow-ups:**
   - notebooks made from several lessons;
   - storing summary sources in a structured field (today they are a line of text in the note);
   - a separate subject field on classes (today the class name is used);
   - a higher limit than 10 lessons for whole-class selection.
5. **Remove unused strings.** The `nbSheet*` keys in the ARB files belonged to the removed create sheet.
6. **Distribution.**
   - iPhone testers outside the owner's own devices need TestFlight, which requires the Apple Developer Program ($99 a year).
   - Android can be shared now as a sideloaded APK.
   - Real students need the provider data agreement and the privacy assessment (DPIA) first, as ADR-0037 says.
7. **Keep these uncommitted:**
   - `ios/Runner.xcodeproj/project.pbxproj` (the personal signing team);
   - `ios/Runner/RunnerPersonalTeam.entitlements`;
   - `fly.toml`;
   - `.github/workflows/fly-deploy.yml`.
8. **Deploy routine:**
   1. Run all gates (see Current status).
   2. Run `bunx supabase db push --db-url <hosted URL, port 5432>` with `--dry-run` first, then for real.
   3. Run `fly deploy --config fly.test.api.toml` and `fly.test.worker.toml`.
   4. On the phone, run `flutter build ios --profile --dart-define-from-file=config/dart-defines.device.json`, then `xcrun devicectl device install app --device 00008120-00067D5E3CC2201E build/ios/iphoneos/Runner.app`.
