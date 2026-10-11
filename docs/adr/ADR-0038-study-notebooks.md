# ADR-0038: Study notebooks made from lesson material

- Status: Accepted for development and the Fly test copy. The ADR-0037
  conditions for real students (provider DPA, minors' DPIA,
  `AI_LESSON_TOOLS_ENABLED`) apply unchanged.
- Date: 2026-10-07
- Decision owner: repository owner
- Relates to: ADR-0029, ADR-0037

## Context

The class notebook held free-form entries. "Lesson notes" put the AI's
Markdown reply into one entry, and the app showed it raw, with `##` and
`**` visible. Nothing tied an entry to the lesson or files it came from.
An entry did not know when its lesson changed. Students could not
annotate it.

Separately, quizzes and flashcards failed on every open. The generated
Dart client cast `null` to a list for the unused half of a study set
(`cards` on a quiz, `questions` on flashcards) and threw. The app showed
this as "That did not work".

## Decision

### 1. A notebook is its own record, made from chosen material

- `public.study_notebooks` belongs to one student. It links that student,
  the class, the lesson and the source ids (empty means the whole lesson).
  It holds the AI content (JSON), a list of what could not be read, the
  cover settings and the student's personal part. Sets made from it are
  in `public.study_notebook_sets`.
- Every read and write goes through `private.api055_study_notebooks`. It
  re-checks ownership and lesson visibility through `study_lesson`. RLS is
  on and there are no policies. Teachers cannot open a student's notebook.
- Creating a notebook needs Plus or Max. It is refused while a chosen file
  is still being read, and at most three notebooks per student can be
  generating at once.

### 2. Written in the background, in one fixed structure

- `POST …/study-notebooks` answers at once with status `creating`. The API
  then gathers the material (ADR-0037 coverage retrieval, 40k characters),
  asks the model for JSON in a fixed shape, and saves it. The shape is:
  - overview and objectives;
  - key terms;
  - sections;
  - worked examples;
  - facts, rules and formulas;
  - common mistakes;
  - a revision summary.
- `parseNotebook` treats the reply as untrusted:
  - it validates, clips and de-duplicates each part;
  - it resolves source labels only against the passages actually sent;
  - it keeps the model's `extra` flag;
  - it leaves out empty parts rather than inventing content.
- Generation is metered with the `notes` feature, keyed on
  `notebook:<id>:<generation>`. A retried request is charged once, and a
  failed call releases its hold. The generation counter means a late reply
  to an earlier request is ignored. A notebook still `creating` after ten
  minutes reads as failed (`timed_out`).

### 3. Updates keep what the student made

- A fingerprint is computed over the lesson version and its sources'
  read times. When it changes, the notebook shows "Update available".
- Updating rewrites only the AI part. Notes, highlights, bookmarks, own
  sections and renamed headings are separate columns and are never
  touched. If an update fails, the last good content stays.
- Personal saves carry `expectedVersion`. When the version is stale, the
  save is refused with `VERSION_CONFLICT`. The app then merges its copy
  over the newer one: notes and sections by id, bookmarks combined, and
  its own highlights win.

### 4. Practice from the notebook

- On Max, a quiz or flashcards can be made from the whole notebook or
  from chosen sections.
- A set is kept once per (notebook, kind, sections, content version).
  Reopening it is free.
- After an update, older sets are listed as outdated.

### 5. Quizzes and flashcards

- The Dart client generator now reads nullable lists as nullable. This is
  the root-cause fix.
- Study sets get their own output budget of 1,400 tokens, the same as
  their hold.
- A reply cut off at the limit keeps its complete items. A set with fewer
  than 3 questions or 4 cards fails, which releases the hold.
- Quizzes are answered, then checked, and show the score and
  explanations. Flashcards flip and track "knew it" against "still
  learning". Both have loading, empty and error states with Try again.

## Consequences

- Background generation runs inside the API process. A machine stopped
  mid-generation leaves the notebook to time out after ten minutes, and
  the student retries. A durable queue in the worker is the follow-up if
  this shows up in practice.
- Old class-notebook entries remain. They are now rendered as headings,
  lists and bold text.
