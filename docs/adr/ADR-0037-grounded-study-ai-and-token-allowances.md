# ADR-0037: Grounded study AI and token allowances

- Status: Accepted for development and the Fly test copy. Shipping to real
  students still needs what ADR-0029 and ADR-0034 require: the provider DPA
  and the minors' DPIA, with `AI_LESSON_TOOLS_ENABLED` on.
- Date: 2026-10-07
- Decision owner: repository owner
- Supersedes in part: ADR-0029 (the "10 questions a day" free limit and
  request counting)
- Relates to: ADR-0026 (SEC-001), ADR-0029, ADR-0034, ADR-0036

## Context

The study helper and the other AI tools (lesson notes, quizzes,
flashcards) saw only a lesson's typed text. Teachers attach PDFs, slides,
Word files, photos of worksheets and links, so the AI answered without the
material that mattered. The free tier was limited by a count of questions,
which says nothing about what a question costs once material comes with
it.

## Decision

### 1. Lesson files and links are read once, in the background

- Uploads for lessons and assignment material now accept `.docx` and
  `.pptx` besides PDF, JPEG and PNG. The scan reads their ZIP structure
  (`packages/domain/src/files/ooxml.ts`): it refuses ZIP64, encryption,
  unsafe or duplicate names, bombs (size and ratio caps), polyglots
  (anything before or after the archive), macros (`vbaProject.bin`,
  macro-enabled content types), ActiveX, embedded OLE objects and
  relationships that fetch something remote when opened (attached
  templates, frames, OLE links). Hyperlinks are kept. Old `.doc`/`.ppt`
  are not accepted.
- When a `lesson_resource` file becomes clean, or a link is added to a
  lesson, a row is queued in `private.ai_material_docs`. The worker
  (`AI_MATERIAL_INDEX_ENABLED`) reads it:
  - PDF: the text layer page by page (pdf.js 6, which never evaluates code
    from a file). A page with pictures and no text is a scan: it is drawn
    at most 1,600 px on its longest side and read by the model.
  - Word: headings, paragraphs, tables as `a | b` rows, and pages where
    Word recorded page breaks.
  - PowerPoint: slides in the deck's order, titles, tables and speaker
    notes.
  - JPEG/PNG: transcribed, and a diagram described in words.
  - Links: https on port 443 only, every resolved address must be public
    (no loopback, private, link-local, CGNAT, metadata or IPv6 ULA such as
    Fly's 6PN), checked again on each of at most three redirects, 10 s
    and 3 MB caps, no cookies. Web pages, plain text and PDFs are read;
    video sites, sign-in pages and other types are marked with the reason.
- Text is split into passages that never cross a page, slide or heading
  (`private.ai_material_chunks`), indexed for Arabic and English stemming
  plus plain words.
- Each source has a state the app shows: processing, ready (or partly
  read), unsupported or failed, with a reason code. A teacher may ask for a
  failed or unsupported one to be read again. Failures from the model or
  the network are retried three times with backoff, then marked failed.
- A deleted file is removed from the index; a file removed from a lesson,
  an unpublished or withdrawn lesson, or one for parents only is never
  retrieved, because retrieval re-checks the lesson on every request.
- When a source finishes reading, lesson notes and quizzes/flashcards made
  from that lesson version are dropped so they are made again from all of
  it, and while any source is still being read those tools answer
  `MATERIAL_PROCESSING`.

Retrieval uses Postgres full-text search. The provider account offers only
an English embedding model (`BAAI/bge-base-en-v1.5`), which cannot search
Arabic; full-text search needs no extra data sent anywhere and costs
nothing.

### 2. Answers come from the material, cited

- The app sends which lessons, files, links or notes a question is about
  (the student picks them, or opens the helper from a lesson), the app's
  language and a request id. The server reads the material itself through
  `private.api054_ai_material`, which uses the same visibility rule as the
  lesson (`private.study_lesson`): enrolled, published, audience includes
  students. Exam papers, answer keys, grades, paper scans, submissions and
  other students' notes are never indexed or never reachable.
- Passages are chosen per question: a page or slide the student names
  ("page 3", "الصفحة ٣", "slide 2") first, then the best-ranked passages
  for the question and the previous question (for follow-ups); a summary or
  "quiz me" spreads passages evenly across the whole material. Budgets per
  plan: 6,000 characters on Free, 16,000 on Plus, 24,000 on Max; 40,000 for
  notes, quizzes and flashcards, which are made once and shared.
- Material is sent as labelled data blocks (`<<<MATERIAL S1 Leaf.pdf,
  p. 3>>>`) the model is told never to obey; markers inside material are
  neutralised. The model cites labels, the server turns them into numbered
  citations (file, page or slide) and drops labels it invented. Anything
  from general knowledge goes after "Beyond your materials". Sources that
  could not be read are named to the model and returned to the app, so it
  never claims to have read them.
- Answers are pitched at the class's grade and given in the app's language.

### 3. One token allowance for every AI tool

| Plan | Allowance | Resets | Dollar cap underneath |
| ---- | --------- | ------ | --------------------- |
| Free | 40,000 tokens | every Monday 00:00 UTC | - |
| Plus | 3,000,000 tokens | the 1st, 00:00 UTC | $0.80 / month |
| Max  | 6,000,000 tokens | the 1st, 00:00 UTC | $1.60 / month |

Set in `private.ai_plan_limits`; changing one is a migration.

**Cost assumptions** (Qwen/Qwen3.5-9B on Together, $0.17 in / $0.25 out per
million tokens, 2026-10-06):

- Worst case is every token an output token: Free about $0.04 a month per
  student (40k × 4.3 weeks × $0.25/M), Plus $0.75, Max $1.50 - each under
  the owner's caps, which stay as a backstop.
- A typical question about a lesson measured 600-3,500 tokens live (the
  material, the chat so far and the answer); the app's guide shows a short
  question as about 1,000 tokens, a question on a lesson's files as
  3,000-5,000, notes/quiz/flashcards as 8,000-15,000 and a photo as about
  17,000, all labelled estimates. That makes Free about 10 questions on
  lessons a week, Plus about 700 a month and Max about 1,400.
- No plan is advertised as unlimited.

**Accounting.** Tokens are the provider's own input and output counts.
`private.ai_model_rates` weights a model's tokens against the reference
model (Qwen3.5-9B counts 1 per token); a model not listed counts double, so
a model swap never undercharges.

**Who and when.** An allowance belongs to the student whose plan it is
(the beneficiary), as plans already did; Family+ grants no AI. Usage counts
in the window of the student's current plan: Monday to Monday on Free, the
calendar month on Plus and Max. Upgrading mid-period gives the bigger
allowance minus what was used this period; downgrading keeps what was used
(no fresh allowance is granted by cancelling and resubscribing). Renewal
does not grant tokens: the window resets on its date. A failed payment
keeps the plan through the store's grace period (`grace_period`
entitlements still count) and then falls to Free.

**Metering** (`private.api047_ai_usage`):

1. Reserve the worst case before calling the provider - the input bounded
   at two characters a token, instructions, photos at 16,000 tokens each,
   and the output limit - under a per-student advisory lock, so concurrent
   requests cannot overspend. Refused as `allowance_exhausted` (or
   `monthly_cap` underneath) before anything is spent.
2. Settle to the provider's reported tokens; with none reported, the hold
   is charged.
3. Release on failure. A hold never settled stops counting after 15
   minutes.
4. A request id makes retries safe: the same request still running is
   refused (`AI_REQUEST_IN_PROGRESS`); one already answered is answered
   again once, free.

The ledger records user, feature, plan, model, tokens, cost and time -
never prompts or answers. Background reading is costed separately in
`private.ai_processing_usage`, per school, and limited by
`private.ai_material_limits`: 60 pages read by the model per file, 3,000
per school per month, 500 pages of text per PDF, 600,000 characters per
source, 3 MB per link. It never touches a student's allowance; the live
check read a scanned page for about 2,100 input tokens ($0.0004).

### 4. The app

- Plans and the helper show tokens left of the total and the reset date,
  warn under 20 %, and explain tokens with labelled estimates.
- When the tokens are used, the question and the chat stay, the reset date
  is shown, and the upgrade goes through the existing verified store flow.
- Answers show their sources; unreadable sources are named with the reason.
- Students ask about a lesson from the lesson itself, or pick a lesson or
  one of its files or links, each with its reading state.
- Teachers see each lesson file's reading state and can ask for it to be
  read again.

## Consequences

- `AI_DAILY_LIMIT` and "10 questions a day" are gone from the server,
  contracts and app.
- The worker needs `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL` and
  `AI_LESSON_TOOLS_ENABLED` to read scanned pages and pictures; without
  them only files with real text are read, and scans say "needs model".
- Known limits: pictures inside Word and PowerPoint files are not read;
  only scanned PDF pages, not mixed text-and-picture pages, go to the
  model; DOCX page numbers exist only where Word recorded them; a link
  whose DNS answer changes between the check and the fetch (rebinding) is
  not caught by the address check; answers are not streamed; full-text
  search does not match a question in one language to material in another.
