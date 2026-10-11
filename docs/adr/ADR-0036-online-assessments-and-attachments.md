# ADR-0036: Online assessments, answer release, and attachments on coursework

- Status: Accepted
- Date: 2026-10-06
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Supersedes: the "exams are sat on paper only" rule in
  `lib/features/academic/presentation/create_exam_page.dart`
- Relates to: ADR-0030 (named SQL handlers, one authorization owner),
  FILE-050/051 (upload and delivery pipeline), 202609300001 (paper gradebook)

## Context

A teacher could attach up to five PDFs or images to an assignment or an
assessment, and a lesson's files were published as separate class material,
unconnected to the lesson. Links lived as bare URLs inside text. Assessments
carried only written questions (`prompt`, `preferred_answer`), no student
could take one in the app, and nothing governed when answers became visible.
Paper grades had no attachments.

The owner asked (2026-10-06) for: titled links and files on lessons,
assignments and questions; a question builder (single choice, multiple
choice, true/false, short answer, essay); automatic and manual marking;
answers released only under teacher-controlled conditions; and shared and
per-student attachments on paper grades - for teachers, students and
parents. Decisions taken with the owner: the teacher sets the number of
attempts (default 1, best or latest counts, extra attempts per student); an
open/close window with no countdown; answers by default only after the
window has closed for everyone.

## Decision

### Attachments are bindings; links are rows

Files keep the FILE-050/051 pipeline: private storage, scanning, single-use
download grants, and per-binding authorization in
`private.file051_authorize_download`. `file_bindings` gains three targets -
`resource_version_id` (already present, now used for lesson attachments),
`assessment_question_id` and `grade_result_id` - and a `role` column:
`material` (what is set) or `results` (shared paper-grade attachments, which
follow the publication of each student's grade rather than of the
assessment). A detached binding is kept, never deleted, as today.

Links get a table of their own, `public.content_links`, with the same
targets and the same detach rule. The server accepts only `https` URLs with
a host and no credentials, at most 2,048 characters, with a title of 1-120
characters. Links are returned only inside the read that is already allowed
to see their target; there is no separate link endpoint to authorize.

### Questions

`assessment_questions` gains `kind` (`single_choice`, `multiple_choice`,
`true_false`, `short_answer`, `essay`), `options` (ordered `{id, text}`),
`answer_key` (option ids, a boolean, or accepted short answers),
`marking_guidance`, and `required`. `preferred_answer` stays the model
answer. Choice and true/false questions, and short answers with accepted
answers, are marked automatically when submitted; essays and short answers
without a key are marked by the teacher. A question's score is all or
nothing for single choice, true/false and short answer; a multiple-choice
question scores only when the selection is exactly the key.

### Attempts and release

Assessments gain `opens_at`, `closes_at`, `max_attempts` (1-20),
`attempt_policy` (`best` or `latest`) and `answer_release` (`after_close`,
`after_grading`, `manual`) with `answers_released_at`. Per-student
`assessment_access_grants` extend the close time and add attempts.

Answers - the key, the model answer, the marking guidance, and per-question
marks - are visible to a student or parent only when
`private.assessment_answers_released(assessment)` is true:

- `after_close`: the window has closed for every student, including every
  extension;
- `after_grading`: that, and every submitted attempt is marked and the
  class's grades are published;
- `manual`: the teacher released them.

Because release requires the window to be closed for everyone, no student
can hold an open attempt while answers are visible. Submission confirmation,
the published grade, the teacher's feedback and the released answers are
four separate things; each read returns only what is authorised and
released. Every gate is in SQL; the API and app cannot see more than the
query returns.

The student's grade is still a `grade_results` row: each submission and
each manual mark recomputes the student's draft score from the counting
attempt, and the teacher publishes grades through the existing gradebook
publish.

### Who may do what

Teacher actions (`assessment.design`, `assessment.release`,
`assessment.access`, `assessment_attempt.read`, `assessment_attempt.mark`,
`gradebook.attachments`) belong to `private.authz_coursework`: the class's
own lead and co-teachers. There is no school administrator in this release.
`assessment.results` - a student's own results, or a linked parent's child's
- has its own owner and is read-only.

## Consequences

- One attachment component in the app serves every surface; a reader never
  sees a link or file whose target it cannot read.
- Office documents are not accepted: the scanner verifies PDF and images
  only. Teachers export to PDF.
- No countdown timer; an attempt is a single submission.
