# ADR-0039: Exact material selection for AI, and AI usage without numbers

- Status: Accepted for development and the Fly test copy. The ADR-0037
  conditions for real students (provider DPA, minors' DPIA,
  `AI_LESSON_TOOLS_ENABLED`) apply unchanged.
- Date: 2026-10-07
- Decision owner: repository owner
- Relates to: ADR-0029, ADR-0037, ADR-0038

## Context

Each AI feature chose material in its own way:

- The helper used a class-then-lessons picker that silently capped the
  choice at five and hid what was chosen in other classes.
- Quizzes, flashcards and lesson notes always took the whole lesson.
- Notebooks had their own sheet.

The server widened selections. If any whole lesson was chosen, every file
of every chosen lesson was read (`sourceIds: []`). An empty list of files
meant "all of them". Lessons the student could not see were dropped rather
than refused.

Allowances were shown as raw token counts, such as "36,800 of 40,000 AI
tokens left", which means nothing to a student.

## Decision

### 1. One selection, resolved exactly on the server

- Every AI study tool sends references. A reference is one of:
  - `lesson` (the whole lesson: its text and every file and link);
  - `text` (only the lesson's own text);
  - `file` / `link` (one source, with its `lessonId`);
  - `note` (the student's own note, for the helper only).
- The server resolves each request against what the student can see now
  (`apps/api/src/study/selection.ts`):
  - a lesson they cannot see refuses the request (404);
  - a source not on its lesson is refused (400);
  - more than ten lessons is refused;
  - an empty choice of files never means "all".
- A chosen file or link that cannot be read is refused with
  `MATERIAL_UNAVAILABLE`, naming each one (`errors[].path = sources/<id>`).
  The app shows them and offers "Try again later" or "Continue without
  them". Only the second sends `skipUnavailable: true`, and then the
  result says what was left out.
- Results report their `scope`, meaning exactly which lessons, text and
  files were used:
  - quizzes and flashcards show a "Made from" line;
  - summaries end with a server-written "Made from" line;
  - notebooks list it on their contents page;
  - helper answers report it in the response.

### 2. New routes, and stored results keyed on the exact selection

- `POST /v1/study-sets` (Max) and
  `POST /v1/classrooms/{id}/notebook/summary` (Plus, lessons of that class
  only) take a selection.
- A result is kept in `private.material_outputs` against a fingerprint of
  the lesson versions, which lessons' text is included, and which files
  were read. The same selection opens again for free.
  `api056_material_outputs` re-checks plan and lesson visibility on every
  read.
- Notebooks record `whole_lesson` and `include_text`. A notebook made from
  a lesson's text alone stays text-only, and files added to the lesson
  later do not count as an update.
- The older per-lesson routes stay for older app builds.

### 3. One picker in the app

- `lib/app/material_picker.dart` lists Class, then Lesson, then the
  lesson's text and each attachment, each as a visible checkbox.
  - Selected lessons are highlighted.
  - Search and class filters cover long lists.
  - A persistent summary sits beside a specific action button, for
    example "Biology · 8A · Lesson: Cells · 2 attachments" next to
    "Create quiz from selection".
  - A review sheet lets the student remove items before continuing.
- What is chosen up front depends on where the picker is opened:
  - opened from a lesson, that lesson is preselected and expanded;
  - opened from a general screen, nothing is chosen and the action is
    disabled.
- A whole class is chosen only through "Select entire class" and a
  confirmation that states its size.
- Files still being read are shown but not chosen automatically. Files
  that can never be read cannot be chosen.
- The helper keeps its material in a bar above the conversation. Changes
  made mid-chat are marked in the chat ("From here: …").

### 4. AI usage shown as a bar

- Token accounting and limits are unchanged (ADR-0037).
- The profile gains an "AI usage" section showing:
  - the plan;
  - a bar labelled "Plenty available", "Running low" (three-quarters used)
    or "Limit reached";
  - the reset date;
  - upgrade and compare buttons.
- The plans page and the helper use the same labels.
- Plans are described by level of use (light, regular, heavy).
- No screen, message or plan description shows a token count.

## Consequences

- A whole-lesson choice that includes a permanently unreadable file needs
  "Continue without them" each time. To avoid that, the picker never
  chooses such files on its own.
- Summary sources are a line written into the notebook entry's text, not a
  structured field.
- Results are shared between students only when the selection is
  identical. Classmates who choose differently each pay for their own.
