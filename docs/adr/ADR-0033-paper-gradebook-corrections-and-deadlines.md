# ADR-0033: Paper gradebook, audited corrections, attendance lock rule and deadlines

- Status: Accepted for local/disposable use
- Date: 2026-09-30
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Relates to: ADR-0017 (server authorization), ADR-0023 (file delivery),
  ADR-0024 (rate limits and caches), ADR-0025 (outbox), ADR-0030 (flat SQL
  dispatchers)

## Context

Many schools set exams and homework on paper. A teacher had to record those
marks through the online grading path: one request per student, with no way
to record an absence, no bulk publication, and corrections that overwrote the
score without keeping the old one. Other gaps:

- Attendance could be rewritten at any time, the previous mark was lost, and
  a register froze once the timetable changed or a student left.
- Work could be replaced after its mark was published. Teachers could not
  give one student more time or reopen work, and deadlines were shown in the
  device's time zone.
- Revising a published lesson hid it again, a lesson's file could not be
  replaced, and lesson files were never returned to students or parents, so
  they could not be downloaded.

## Decision

### A paper gradebook item is an assessment with `delivery = 'paper'`

There is no new item table and no subjects table: a class is already one
subject in one term at one school. Categories are free text, with built-in
keys (`paper_exam`, `homework`, `quiz`, `participation`). The optional weight
is `assessments.category_weight`; no weighted average is computed yet.

### Marks: scored, absent, not graded; missing is never zero

`grade_results.mark` is `scored | absent | not_graded`. Absent and not-graded
rows carry no score. A student with no mark is a draft and is never
published. A row where `mark` is null but a score is set predates marks and
reads as `scored`, so nothing was backfilled.

### Drafts, one publication, audited corrections

| Step | What happens |
|---|---|
| `saveGradeDrafts` | Up to 100 rows. The whole sheet is valid or nothing is written, and each refused row is named in the problem's `errors`. A marked row is `reviewed` ("ready"); a cleared row is a `draft`. |
| `publishGrades` | Publishes every ready row in one statement. It requires `expectedGradebookVersion`, so the teacher publishes exactly the sheet they saw. |
| `correctGrades` | Published rows only, and a reason is required. It writes previous and next values into the existing append-only `grade_result_events`. The older single-grade `correctGradeResult` now goes through the same path. |

Families hear about releases and about changes to the mark itself. A comment
edit is recorded (`material = false`) but not announced.

### Attendance lock rule and history

- **The rule.** On the lesson's school-local day, marks change freely. After
  that, changing a mark needs a reason. Seven days after the lesson, the
  register locks.
- **Overriding a lock.** Only the class's lead teacher may override, and
  always with a reason.
- **No per-school setting.** This release has no school administrator, so
  there is nobody who could change the rule. It lives in
  `private.attendance_edit_rule`.
- **History.** `attendance_record_revisions` is append-only.
- **`correctAttendance`.** It is addressed by lesson, so it works after a
  timetable change and for students who have since left. Those students are
  listed on the lesson's register, flagged.

### No school administrator

This release ships without a school administrator role, and the owner has
ruled that one has no access at all. Every coursework action is decided by
`private.coursework_teacher` (lead or co-teacher of the class, holding a
teacher membership) or `private.coursework_staff` (any of the class's staff,
holding a teacher membership). Neither admits a school administrator, so a
`school_admin` membership left over from older data opens nothing here.
Older handlers still carry `is_school_admin` checks. The only way
to create such a membership is the platform operator's `provisionSchool`
command, which no screen offers, so in this release nobody holds the role.

### Deadlines

- **The deadline** is the later of `closes_at` (or `due_at` when there is no
  closing time) and any live `assignment_extensions` row. A hand-in after
  `due_at` but within that deadline is accepted and marked `late`.
- **The graded lock.** Once a mark is published, the work cannot be replaced
  unless an extension is granted after publication.
- **School time.** Times the teacher picks are sent as school wall-clock
  values (`*Local`) and converted with `schools.timezone`. Responses carry
  `timeZone`, `dueLocal` and `deadlineLocal`.
- **Replacing work.** A replacement may keep files from the attempt it
  replaces without uploading them again. Drafts stay on the device.

### Lessons and material

- **`editResource`** keeps the lesson's state. It writes a new version and a
  new publication and withdraws (supersedes) the old publication. The old
  version and file are kept, and staff can still open them; students and
  families get the current file only.
- **`updateWorkMaterials`** soft-detaches files through
  `file_bindings.detached_at`. A detached file is hidden from the class and
  downloadable by staff.
- **Resources** return their current file as `attachments`, which is what
  makes lesson files downloadable.
- **Downloads** still go through FILE-051: single-use grants of five minutes,
  streamed from private storage.

### Staying fast under load

- Every command is set-based: `jsonb_to_recordset`, `insert … select` and
  `update … from`, with no per-row loops and no temporary tables.
- Commands lock one assessment row, plus the grade rows they touch, in id
  order.
- A release or correction writes one outbox row naming its marks, and the
  worker fans it out after commit.
- A class sheet is one keyset page. `scripts/verify-coursework-query-plans.ts`
  (`test:plans:coursework`) seeds 300 classes and 63,000 marks, asserts index
  use and times the handlers. In local measurement a sheet read took about
  5 ms, a whole-class save about 9 ms, publication about 7 ms and a
  correction about 17 ms.
- Authorization is `private.authz_coursework`, one new owner in
  `authz_authorize`, per ADR-0030. Decisions are never cached.

## Consequences

- Four new migrations (`202609300001`–`202609300004`) and four transactional
  pgTAP suites. Routes are appended at the end of the catalogue.
- New problem codes: `GRADE_ENTRIES_INVALID` (422), `REASON_REQUIRED` (400),
  `ATTENDANCE_LOCKED` (409) and `SUBMISSION_LOCKED` (409).
- `grade_result_events` and `attendance_record_revisions` keep history as
  long as the record exists (`ON DELETE RESTRICT`), as the grade history
  already did.
- Material on set work can be changed after it is set, from the teacher's
  class screens; a detached file is kept, and only the class's staff can
  still open it.
