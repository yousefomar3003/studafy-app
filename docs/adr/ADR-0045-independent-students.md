# ADR-0045: Students without a class: AI for every student, a personal notebook, and photos that are never stored

- Status: Accepted. Takes effect with privacy policy 1.7 and terms of use
  1.5 (consent version `2026-10-22`), which the owner publishes, without
  legal review (DL-072).
- Date: 2026-10-21
- Decision owner: repository owner
- Relates to: ADR-0022 (FILE-050), ADR-0023 (FILE-051), ADR-0029, ADR-0037,
  ADR-0038, ADR-0043 (supersedes its decision D3); DL-037, DL-055, DL-060,
  DL-071, DL-072; draft DPIA §12.1

## Context

A student could sign up, but could do nothing until a teacher's class link
arrived:

- **The app.** A new student saw a full-screen "Join your first class" with
  no way past it.
- **The AI gate.** `private.ai_access` answered `no_class` for any student
  with no active class (ADR-0043 D3), so the helper and every other AI tool
  were refused.
- **Uploads.** Files are tenant-keyed down to the storage path
  (`quarantine/v1/<school>/...`) and the owner's membership is a foreign key
  (FILE-050, FILE-051). A student with no school has nowhere to upload a
  photo.
- **The notebook.** Every `public.notebook_entries` row needed a school, a
  class and a student record.

The owner decided that joining a class adds to Studafy and is never the
price of using it (DL-072).

## Decision

### 1. AI for every student account

`private.ai_access(user)` (migration `202610210030_independent_students.sql`)
now answers `ok`, `consent_required` or `guardian_consent_required` for any
account whose `private.account_kind` is `student`, in a class or not.
Managed child accounts are student accounts, as before.

| Value | Who |
|---|---|
| `ok` | A student account holding a current AI consent |
| `not_student` | A parent or teacher account (`account_kind` = `adult`), or no active profile |
| `no_class` | Only an account not yet known to be a student (signed up, kind not recorded yet) |
| `consent_required` | A student account without a current AI consent |
| `guardian_consent_required` | The same, for a managed child account |

The three layers of ADR-0043 stay: the API's AI gate, the AI ledger's
`reserve`, and the SQL authorization catalogue. `ai_enrolled_student` stays
for study sets made from a class's lesson, which still need that lesson's
class. The AI consent (ADR-0043 §2) and name redaction (ADR-0043 §3) are
unchanged.

### 2. The personal notebook

A personal note is a `public.notebook_entries` row with `school_id`,
`classroom_id`, `student_id` and `photo_file_id` all `NULL`, and only an
owner. The check constraint `notebook_entries_class_or_personal` allows a
row to be either a class entry (as before) or a personal one, nothing in
between. Personal notes are served by `private.api058_query` and
`private.api058_command`:

| Route | Who | Notes |
|---|---|---|
| `GET /v1/me/notebook` | Any student | Their personal notes |
| `POST /v1/me/notebook` | Any student | A typed note. Free (DL-055) |
| `POST /v1/me/notebook/photo-notes` | Studafy Plus | A note made by AI from a photo or screenshot (section 3). Metered as `whiteboard` |
| `POST /v1/me/notebook-entries/{id}/edit` | The note's owner | Edit or rename any of their own notes, personal or in a class |
| `POST /v1/me/notebook-entries/{id}/delete` | The note's owner | Any of their own notes |
| `POST /v1/me/notebook/practice` | Studafy Max | A quiz or flashcards from the student's own notes, metered as `quiz` or `flashcards`. **Not stored**: the response goes to the app, which holds it while the student practises |

Permissions `my_notebook.read`, `my_notebook.write` and
`my_notebook.practise` are self-scoped. A personal note is visible only to
its owner: no teacher, no parent. Joining a class later changes nothing in
it. Account deletion, the data export and the AI Tutor's "my notes"
reference already read `notebook_entries` by owner, so personal notes are
deleted, exported and usable by the Tutor with no change to them.

### 3. Inline images, never stored

A student with no school has no tenant to upload into, so a photo travels
inside the request as `V1InlineImage`:

- `mediaType`: `image/jpeg`, `image/png` or `image/webp`;
- `data`: base64, at most 5,400,000 characters (4 MB decoded).

It is accepted on `POST /v1/study-assistant/ask` (`images`, at most 3 photos
per question counting uploaded ones, Studafy Plus) and on
`POST /v1/me/notebook/photo-notes`. The API (`readInlineImage`,
`apps/api/src/study/inlineImage.ts`):

1. checks the magic bytes match the declared type;
2. checks the size header against the pixel cap before decoding;
3. decodes the image and draws it again as a JPEG of at most 1,600 px on
   its longest side (`prepareImage`).

Only that redrawn copy is sent to the provider, once. Metadata and anything
else the file carried never leave the server. Nothing is written to
storage or the database.

**Why not upload them.** Files are tenant-keyed down to the storage path
and the owner's membership is a foreign key. Storing school-less files
would mean reworking FILE-050 and FILE-051 (intents, quarantine keys,
scanning, publication, delivery grants, retention), for photos that are
read once.

**Why not a personal "school".** Giving each student a private school to
upload into was rejected: the app shows only the first active school's
classes, so a personal school could hide a teacher's class the student
joins later.

Photos from students in a class still go through the upload pipeline, and
helper photos are still kept 30 days (DL-060).

### 4. Request body size

Bun's `maxRequestBodySize` now covers the largest route override
(`largestBodyBytes`, `apps/api/src/index.ts`). Before, it silently capped
the ask route's 512 KB override at the 64 KB default. The route limits are
now 17 MB for `/v1/study-assistant/ask` (three photos) and 6 MB for
`/v1/me/notebook/photo-notes` (one).

### 5. The app

- **"Skip for now"** on the join screen, shown once per account per
  device. Joining a class later uses the teacher's link or code, as before.
- A student without a class gets the full app: the AI Tutor, the personal
  notebook, plans.
- The study helper is renamed **AI Tutor** (Arabic "المعلّم الذكي").
- Restore purchases stays in Account → Subscription (DL-071) and is always
  shown for students on iOS and Android.

## Consequences

- **Supersedes ADR-0043 D3** ("students in a class only"). D4 (no AI for
  parents and teachers), D1 (names replaced) and D2 (a separate AI consent)
  stand.
- **Policies.** Privacy policy 1.7 and terms of use 1.5, English and
  Arabic, consent version `2026-10-22` (migration
  `202610210040_terms_and_privacy_2026_10_22.sql`, `termsPolicyVersion`).
  The AI notice is `ai_features` `2026-10-22` (`aiConsentVersion`): it names
  the AI Tutor and says a photo from a student in no class is read once and
  not kept. Everyone is asked again for both.
- **The legal site** builds from `docs/legal`. The owner must redeploy it
  (`bun run legal:deploy`) once the migration is applied and the app
  carrying `2026-10-22` ships.
- **Children outside a school.** A child can now use Studafy, the AI tools
  included, with no school involved, no age gate and no date of birth. This
  reopens DPIA D3 (§12.1) and makes DL-037 and counsel question 9.1 more
  pressing.
- **Studafy is the controller** for students with no class and for every
  student's personal notes (policy §1.1), pending counsel.
- **Known limitation (pre-existing).** A student in two teachers' spaces
  still sees only the first space's classes.
- **Follow-up.** The Tutor cannot yet read a school-less student's own PDF,
  DOCX or PPTX: those need storage, which this decision avoids.

## Open questions for counsel

- TODO(legal): minors using Studafy and its AI tools outside any school:
  the age of digital consent, whether a parent's consent is needed, and
  whether an age gate or age band is needed (questions-for-counsel 9.1;
  DPIA measure M8).
- TODO(legal): the replacement for policy 1.6 §5's "We do not knowingly
  permit a child to create an account outside a school context where their
  country requires parental consent for it".
