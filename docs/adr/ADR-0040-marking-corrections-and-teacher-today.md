# ADR-0040: Marking online work, corrections after publication, and the teacher's Today lists

- Status: Accepted for development and the Fly test copy
- Date: 2026-10-07; amended 2026-10-08 (absence, feedback-only edits)
- Decision owner: repository owner
- Relates to: ADR-0030 (no rename-and-wrap), ADR-0033 (gradebook
  corrections), ADR-0036 (online assessments)

## Context

The owner reported three problems: teachers could not review students' answers
to online exams or save and publish their grades; "Sections needing content"
on the teacher's Today page did not follow lesson creation; and "Work you have
set" was always empty. Following each path end to end found these causes.

- **The Gradebook tab sent online exams to the wrong screen.** It opened the
  old per-student score list, which showed no answers. Its Save reviewed one
  grade at a time: a published row was refused (409) and stopped the rest, and
  rows it skipped were still reported as "saved".
- **Feedback never reached the grade.** `assessment_sync_grade` copied the
  attempt's score and left the grade's feedback empty.
- **Corrections were silently ignored.** Re-marking an attempt after
  publication changed the answers, but the published grade was left alone.
- **Marks were checked while being written.** A bad mark late in a request
  left the earlier ones saved.
- **Sections could never clear.** A section counted as done only when closed,
  creating a lesson never linked it to the section, and the only screen that
  did either had been unreachable since the class tool row was removed.
- **Today never refreshed.** It loaded once, it is a tab that stays alive, it
  counted assignments only (never exams), and it silently skipped classes it
  could not read.

## Decision

### Marking and publication

- **Routing.** Work answered in the app is marked from each student's answers
  (`AssessmentMarkingPage`). Paper work, including an assignment's mark, is
  marked on the class grade sheet. `ClassGradebookPage` now only picks the
  piece of work.
- **Statuses.** The marking list shows the whole class, not only those who
  handed in:
  - **Submitted:** not graded, or partly graded;
  - **Graded:** marked, a draft only the class's teachers see;
  - **Published.**

  Students with nothing handed in are shown as **Not submitted**, **Absent**
  (a private draft), **Absent · published**, or **Not graded · published**
  after a correction. The server sends each attempt's grade state and mark,
  and the count of answers still waiting for a person. The roster comes from
  the class gradebook.
- **Saving.** Saving keeps marks and feedback as a draft. Publishing is the
  existing all-or-nothing gradebook publish, after a confirmation that says
  how many grades will be released and how many stay back. Publishing again
  has nothing to release, so nobody is notified twice.
- **Corrections (amended 2026-10-08).** Once a grade is published, only a
  change to its **mark or score** is a correction:
  - it needs a reason of 3–500 characters (`correctionReason`);
  - without one, the server refuses (`REASON_REQUIRED`) and changes nothing;
  - with one, it goes through `gradebook_apply_corrections`, which keeps the
    history and notifies families.

  Other changes need no reason:
  - **The grade's feedback alone** is applied at once and recorded as a
    non-material `corrected` event with no reason. The text it replaced is
    kept, and nobody is notified.
  - **Answer comments** never touch the grade.
  - **An unchanged save** sends nothing.

  The app does not guess. It saves, and asks for a reason only when the
  server refuses without one, so client and server cannot disagree about
  what is a correction. Backing out of the prompt saves nothing and keeps
  everything typed.

  The paper grade sheet is unchanged: there, any change to a published
  mark, including its comment, still needs a reason.
- **Absence (added 2026-10-08).**
  - **Who can be marked absent.** Only a student with nothing handed in, by
    the class's teachers, through the gradebook's draft save, with optional
    notes. The server refuses a score on online work and refuses absence for
    anyone who handed in.
  - **Never a zero.** An absence is a mark of its own (`absent`), not a
    score, and stays private until the grades are published. Published, the
    student and their parents see "Missed the exam" and the notes.
  - **Correcting it.** Each change is recorded in the grade's history. An
    unpublished absence can be removed. A published one is corrected with a
    reason, to not graded (excused) or back to absent with new notes.
  - **Handing in after an absence.** An unpublished absence is replaced by
    the attempt's result, and the replacement is recorded with the reason
    "Handed in after being marked absent". A published absence stands, since
    the family has seen it. The marking screen says so, and saving it
    replaces the absence with the attempt's mark as a correction with a
    reason.
- **Feedback.** The overall feedback of the attempt that counts is copied to
  the grade, so it is published with it.
- **Validation and unsaved work.** Every mark is checked before any is
  written. The marking screens and the paper sheet ask before leaving with
  unsaved marks, and a failed save keeps everything typed.

### Sections needing content

- `listLessonSessions` returns `contentState`:
  - `published`: a lesson filed for the section is published to students;
  - `draft`: only drafts are filed (told to the class's staff only);
  - `none`: no lesson is filed.
- A section needs content once it has been taught and has no published
  lesson. A draft never counts.
- From Today, the teacher opens the new-lesson form for that class with the
  section attached, which files the lesson for it. A draft opens the class's
  lessons, where it is published.
- The class options menu again offers Students, Timetable and Sections.
  Without the timetable, a class with no schedule could never take a register.

### Work you have to set

- **Assignments:** drafts, and published assignments whose hand-ins are still
  open.
- **Online exams:** drafts, scheduled exams (opening later), and open exams.
- **Paper exams:** those whose exam day is still to come. A paper exam stays a
  draft until its marks are published, so its state says nothing about
  whether it has been set.
- **Left out:** closed or withdrawn work, and an assignment's mark item.
  Nothing is invented for a class with no such work.
- **Order:** drafts first, then soonest date. Each item opens the screen where
  it is published, edited or marked.
- **Refreshing:** Today reads again when it comes back into view, after
  anything it opened, and after the shell's create button. A class that could
  not be read is reported, not hidden.

## Consequences

- Pull-to-refresh on the student's results and the teacher's submissions
  now asks the server again. It used to reuse a copy from the last 20
  seconds, so a result published just before a refresh could stay hidden.
- Migrations `202610070006_absence_and_feedback_edits.sql` (absence and
  feedback edits) and `202610070005_unwind_function_wraps.sql` (the check
  fixes below) replace functions; neither wraps one.
- **The two failing checks (2026-10-08).**
  - **`check:migrations`** flagged rename-and-wrap layers in `202610060001`
    and `202610070001`, which are already applied to the hosted database and
    so are not edited. `202610070005` unwinds them:
    - `authz_authorize` is flattened, with no differences across 314,976
      recorded decisions;
    - the other four inner functions get names for what they do.

    The gate now accepts such a wrap only once a later migration has renamed
    or dropped it; see the ADR-0030 addendum.
  - **`check:bounds`** read the word "from" inside comments and strings as
    an import (in `materialSelection.ts` and `selectionRoutes.ts`). Its
    import scan now works on tokens, and finds the same 747 real imports in
    185 files as before.
- Migration `202610070004_marking_corrections_and_section_content.sql`
  replaces functions and adds one post-processing step to the query
  dispatcher. Nothing is renamed or wrapped.
