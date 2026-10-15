# ADR-0043: AI study tools for students in a class, a separate AI consent, and names kept out of AI requests

- Status: Accepted for development and the Fly test copy. AI stays off for
  real students until the AI DPA and the DPIA are signed (DL-056, launch
  plan M4); this makes the code match privacy policy 1.4 before then.
- Date: 2026-10-15
- Decision owner: repository owner
- Relates to: ADR-0029, ADR-0031 (managed child accounts), ADR-0037,
  ADR-0039; draft DPIA §12 D1-D4 and measures M6-M8 (PR #57); DL-037,
  DL-056

## Context

The draft DPIA (PR #57, `docs/legal/dpia-draft.md` §12) found four places
where the code did not do what privacy policy 1.4 says:

- **D4.** Policy §6 lists the study helper for "every student". Any
  signed-in account could call it, parents and teachers included.
  `study_assistant.ask` was self-scoped with no role check, and
  `study_set.generate` allowed anyone who could see a lesson, which
  includes a teacher and a linked parent.
- **D3.** Policy §5 says children use Studafy only through a school. An
  account with no class could still use the helper.
- **D1.** Policy §2 and §6 say names are never sent to the AI provider.
  Studafy never adds one, but redaction removed only emails, links and
  long numbers. A name typed into a question, or in a teacher's file, was
  sent.
- **D2.** Policy §4 gives consent as the lawful basis for the AI tools. The
  only consent recorded was the bundled `terms_and_privacy` one. There was
  no AI-specific consent, no parent's consent for a child account, and no
  record of a withdrawal.

## Decision

### 1. Students in a class only (D3, D4)

`private.ai_access(user)` decides, on every AI call:

| Value | Who |
|---|---|
| `ok` | A student account with at least one active enrollment in an active class at an active school, holding a current AI consent. Managed child accounts count as student accounts. |
| `not_student` | A parent or teacher account (`private.account_kind` = `adult`), or no active profile |
| `no_class` | Any other account with no active class |
| `consent_required` | A student in a class without a current AI consent |
| `guardian_consent_required` | The same, for a managed child account |

Three layers enforce it:

1. **The API's AI gate** (`requireAiAccess`, `apps/api/src/study/aiAccess.ts`).
   It is mounted after the permission on every route that sends anything to
   the provider, before the route reads material, holds tokens or takes an
   idempotency key. That is the helper, whiteboard notes, study sets (from a
   lesson, a selection or a notebook), lesson notes, summaries, and creating
   or updating a study notebook. It answers `403 AI_STUDENTS_ONLY`,
   `403 AI_CONSENT_REQUIRED` or `403 AI_GUARDIAN_CONSENT_REQUIRED`.
2. **The AI ledger.** `private.api047_ai_usage('reserve')` refuses to hold a
   token unless access is `ok`. Every model call holds tokens first, the
   background notebook writer and its recovery included, so no route can
   reach the provider without this check.
3. **The SQL authorization catalogue.** `private.authz_notebook` now allows
   `study_set.generate` (lesson study sets and lesson notes) only to a
   student in a class. The catalogue descriptions of `study_assistant.ask`,
   `study_set.generate` and `material_set.generate` say the same.

Reading what a student already made (their notebooks, notes and study sets)
is not gated: nothing is sent to the provider, and the data is theirs.

The plan summary (`GET /v1/me/study-plan`) now returns `aiAccess`. For
`not_student` and `no_class`, `available` is empty, so the app hides every
AI entry point. Parents and teachers never had the helper in their shells.
A student with no class sees the "join a class" screen, not the tools.

### 2. A separate, versioned AI consent (D2)

- **The notice.** The consent is a `consent_records` row with purpose
  `ai_features`. It is recorded only against the published notice:
  `consent_policies` version `2026-10-15`, whose `content_hash` is the
  SHA-256 of the exact in-app text (`aiConsentNoticeBody`, English and
  Arabic). The app constant is `aiConsentVersion` in
  `lib/core/ai_consent.dart`. `test/l10n/ai_consent_version_test.dart`
  fails if the text changes without a new version, like the terms test.
  A consent is current when it is for the newest published `ai_features`
  notice and not withdrawn. Publishing a new version asks everyone again.
- **What the record holds.** New columns on `consent_records`: `given_by`
  and `given_as` (`self` or `guardian`), and `withdrawn_by`. With
  `accepted_at`, `withdrawn_at`, `locale` and `policy_id`, the record says
  who agreed, as whom, to which words, in which language, when, and who
  withdrew it. Each consent and each withdrawal is also written to
  `auth_security_events` as `consent_recorded`. That keeps the history after
  a later consent overwrites the row.
- **Who gives it.** A student gives their own. For a managed child account
  (ADR-0031), the parent who manages it gives it from their own account,
  through `POST /v1/me/managed-children/{childId}/study-tools-consent`.
  The child cannot give it, even though the parent is often the one holding
  the device in the child's session, because the session is the child's.
  Anyone who could give the consent may withdraw it, and a managed child
  may withdraw their own.
- **Recording.** Only `private.api057_ai_consent` records it, through
  `GET`/`POST /v1/me/study-tools-consent`. `record_policy_consent` no
  longer accepts `ai_features`, which closes a route by which a child could
  consent through PostgREST. (Paths and permissions avoid the word "ai":
  the AI-072 route check forbids it.)
- **In the app.** Every AI request goes to the server, which refuses it
  before anything reaches the provider. The data layer asks
  `AiConsentGate`. The gate shows the notice over whatever screen is open,
  records the consent if the student agrees, and sends the request once
  more. So the notice comes before the first use, whichever tool it is,
  without each tool knowing about it. A managed child is told that a parent
  turns the tools on. The switch in Account (students) and on each child
  card on the parent's home (managed children) shows the notice to turn the
  tools on, and asks before turning them off.
- **Export and deletion.** The AI consent is a consent record. The data
  export's `consents` section includes it, and the deletion screen counts
  it. Account deletion keeps it, like every consent record: for the life of
  the account and 6 years after (DL-057). The retention purge then deletes
  it with the others. Nothing new had to be added to either.

### 3. Names out of everything sent (D1)

Before any model call, each route wraps the provider client in
`withNameRedaction` with the student's known names
(`private.ai_known_names`):

- their own names: profile and roster;
- their classmates, roster and account names, in every active class they
  are in (a superset of the classes the material comes from);
- the teachers of those classes, both staff and the class's teacher;
- their parents: linked, pending or verified, and the parent who manages a
  child account.

The names are replaced with `[student]`, `[classmate]`, `[teacher]` or
`[parent]`. This covers the question, every chat turn, the material's text,
titles, headings and file names, unreadable-source names, and the lesson
text and title of study sets, lesson notes and notebooks.
`packages/domain/src/study/nameRedaction.ts`:

- matches whole words after folding case, Latin accents, Arabic short
  vowels and tatweel, alef forms, alef maqsura and taa marbuta;
- replaces a full name wherever its words appear together, and one word of
  a name alone only if it has at least 3 letters, is not a particle (`bin`,
  `abu`, `عبد`, `الله` ...) and is not a common word that is also a name;
- treats such a common word (`Will`, `Grace`, `نور`, `أمل` ...) as the
  name only in Latin script, capitalised, in the middle of a sentence;
- keeps a one-letter Arabic prefix: `ومحمد` becomes `و[classmate]`.

If the names cannot be read, the request fails rather than going out
unredacted.

**Photos cannot be redacted.** A photo attached to a question, a whiteboard
photo, and scanned pages of a teacher's file (read once in the background,
ADR-0037) go to the provider as images. The notice tells students not to
photograph names or faces. Text later taken from a scanned page is redacted
when it is used, like any other material.

## Consequences

- Policy §2, §4, §5 and §6 now match the code for the AI tools, except
  that photos carry whatever is in them. Counsel should decide whether §6
  needs to say so (below).
- Every student is asked once, at their first AI use after this ships. A
  parent of a managed child has to turn the tools on from their own account
  before the child can use them.
- Integration fixtures and the capacity seed record an AI consent for their
  students. Without it the ledger refuses them.
- Names in a teacher's material are replaced for the student who asks.
  Shared study sets made from that material carry placeholders, not names.
  This is intended.
- Redaction is best effort. A nickname, a misspelling or a name Studafy does
  not hold still goes through. A real name equal to a listed common word is
  replaced only where it is capitalised mid-sentence.

## Open questions for counsel

- TODO(legal): who gives the AI consent for a student aged 13-17 who signs
  in themselves (today the student does), and the age below which a parent
  must (GDPR Art. 8, DL-037, DPIA Q-F, measure M8). Studafy holds no age, so
  today only managed child accounts get a parent's consent.
- TODO(legal): confirm the notice text (`aiConsentNoticeBody`, EN and AR)
  before AI is switched on for real students. Any change means a new
  consent version.
- TODO(legal): whether policy §6 should say that photos are sent as they
  are, and whether that is a substantive change needing a new
  terms-and-privacy consent version.
- TODO(legal): whether a linked (not managing) parent should also be able
  to see or withdraw a self-signed-in student's AI consent.
