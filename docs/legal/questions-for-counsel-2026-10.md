# Questions for counsel (October 2026)

For: the lawyers reviewing Studafy before launch. From: Yousef (owner),
drafted by Claude on 2026-10-16 from the code, the draft DPIA and the
decision log.

**This repository is public.** Keep your answers and any annotated copies
outside it; send them to hello@studafy.com.

**Update 2026-10-17 (DL-068):** the owner published privacy policy 1.5
and terms of use 1.3 without waiting for these answers. Where an item below
is marked **policy**, 1.5 already carries draft wording (AI photos, the
processors, helper photos, inactive accounts, the export, safety reports),
with a TODO(legal) comment beside it. Please review that wording; changes
ship with a new consent version.

**Update 2026-10-21 (DL-072):** the owner published privacy policy 1.7 and
terms of use 1.5 (consent version `2026-10-22`), again without waiting.
Students no longer need a class: a student can sign up and use Studafy, the
AI study tools included, without any school. This changes item 1.5 and adds
section 9.

**Update 2026-10-25 (DL-073):** the owner decided that teachers may ask AI
for suggested marks (Studafy AI Marking, a paid teacher plan), and privacy
policy 1.8 and terms of use 1.6 describe it, again without waiting. The AI
only suggests; the teacher decides; students can opt out. This adds
section 10 and widens item 1.1.

Each item says what the app does now, with the file or decision behind it,
and the question. Items marked **policy** need a change to privacy policy
1.4 (`docs/legal/privacy-policy.md`, live in English and Arabic); please
give the wording you approve, and it ships with a new consent version.

---

## 1. AI study tools (off for real students until 1.1 and the DPIA are signed)

1.1 **The AI provider's DPA.** Together AI processes what students send. We
have no DPA, no retention or no-training terms, and no transfer basis
(DPIA draft §11, `docs/legal/dpia-draft.md`). What must the DPA say, and is
an EU-hosted provider required?
Since DL-073 Together AI also receives students' assessed work, including
photos of handwritten pages, when a teacher asks for suggested marks (10.2).

1.2 **Consent for AI (policy §4).** Students now give a separate, versioned
AI consent before first use, recorded with who, when and the exact notice
text (ADR-0043, notice version `2026-10-15`). For a managed child account
the parent consents. Please review the notice text, English and Arabic: key
`aiConsentNoticeBody` in `lib/l10n/app_en.arb` and `app_ar.arb` (its hash is
pinned in `lib/core/ai_consent.dart`). Any change needs a new version.

1.3 **Who consents for 13–17-year-olds.** A student who signs in themselves
consents for themselves. Studafy holds no date of birth. Is that acceptable,
and below which age must a parent consent (GDPR Art. 8; Ireland sets 16)?
Should a linked parent (not the account's manager) be able to see or
withdraw it?

1.4 **Names and photos (policy §2, §6).** Names of people the student can
see are replaced before any text reaches the model (ADR-0043). Photos
(helper photos, whiteboard photos, scanned pages) are sent as they are and
cannot be redacted. The policy says names are never sent. **Policy:** say
photos are sent unchanged? Is that a substantive change needing fresh
consent?

1.5 **Who may use AI (policy §5, §6).** Only students enrolled in a class.
Parents, teachers and accounts without a class are refused (ADR-0043). This
now matches §6 ("for students"). Confirm.
*Superseded 2026-10-21 (DL-072, ADR-0045):* every student account may use
the AI tools, in a class or not, after the AI consent; parents and teachers
are still refused. See 9.1.

## 2. Processors and transfers (policy §7.2)

2.1 **Policy:** the processor list needs:
- **Telegram:** operations alerts, including one per safety report, carrying
  only the report id, kind, priority and a hash of the school id (PR #71).
- **Cloudflare:** the alert relay Worker, and R2 (EU jurisdiction) for the
  encrypted daily backups, which replaces GitHub as backup storage once set
  up (PR #69).
- **Remove** the outside malware-scanning service: scanning is self-hosted
  (ClamAV on our own servers).
- The optional AWS copy of backups is now EU regions only.

2.2 **Backups.** Backups are encrypted before they leave our systems (age,
X25519). Until R2 is set up they are also kept for 7 days as GitHub Actions
artifacts. The repository is public, so those encrypted files can be
downloaded by any GitHub user. Is that acceptable for the interim?

## 3. Retention (policy §10, DL-057, DL-060)

3.1 **Helper photos: 30 days after upload** (DL-060). **Policy:** add a
§10 row. Confirm the period.

3.2 **Periods still missing.** Please give one for each:
- safeguarding (wellbeing) notes;
- school-wide announcements;
- other notifications;
- roster rows for students with no account;
- safety reports, their evidence and events;
- invitations nobody accepted (they hold an email address);
- the AI usage ledger (kept until the account is deleted today);
- data-export request rows after the file expires;
- files whose malware scan ended in an error (they wait for an operator).

3.3 **Inactive accounts.** After 23 months without a sign-in the account
holder is warned by email (always, whatever their email settings) and in
the app, and the account is deleted at 24 months (PR #73). People with no
school are warned by email only. If that email can't be delivered (a hard
bounce, a refused address, or no address at all), we keep the account and
flag it to the operator once a day; we don't delete it without a warning.
The operator then checks the address, tries to reach the person another way,
or decides with you what to do
(`docs/security/inactive-account-warnings-runbook.md`). Is keeping these
accounts, possibly past 24 months, the right call?

## 4. Data subject rights (policy §11)

4.1 **The export lists files rather than including them.** The export is one
JSON document; it lists each file's name, type, size and date and says how
to get the files (PR #72). **Policy:** say so in §11?

4.2 **What the export leaves out.** Is each of these acceptable under the
right of access?
- exam questions, marks and feedback before the teacher releases them (the
  student's own answers are always included);
- wellbeing notes (the school's safeguarding records);
- messages from conversations the person has left (we export what the app
  shows them).

## 5. Safety reports (policy §3.7, terms §3)

5.1 Every new report now alerts the reviewers, and an operator reviews it
through an audited tool (PR #71). Reviewers must be named people (launch plan
B9). What response times should we commit to, and must the reporter be told
the outcome?

## 6. The DPIA

6.1 Please review the draft (`docs/legal/dpia-draft.md`, PR #57), in
particular §5 (whether schools are controllers and Studafy a processor, or
Studafy a controller), §12 (where the code and the policy disagreed; items
D1–D4, D6, D7, D12 and D13 are now fixed in code, listed above), and §14
(whether prior consultation with the Data Protection Commission is needed
if AI stays high-risk).

6.2 Do we need a DPO, and an EU representative?

## 7. Stores

7.1 We declare under-13 users in both stores' age settings and do not use the
App Store Kids category (DL-056). Google's Families policy applies. Anything
to add to the store privacy answers (`docs/store/google-play-data-safety.md`,
`docs/store/app-store-privacy-labels.md`)?

7.2 Store reviewers sign in with three accounts in a fictional review school
(`docs/store/reviewer-access.md`). They see no real data. Confirm nothing
more is needed.

## 8. Purchases by students (DL-071, terms 1.4 §9, policy 1.6 §3.9)

8.1 Since 21 October 2026 a student subscribes to Studafy Plus or Max
themselves, in the app, and Studafy has no approval step of its own. Payment
comes from the Google Play or App Store account on the phone; the terms say
that for a child this account and its payment method should belong to, or be
controlled by, a parent or guardian, who is responsible for purchases made
with it, and that Google Family Link and Apple's Ask to Buy let a parent
approve each purchase. This was published without your review. Is relying on
the stores' family controls enough under Irish and EU consumer law (contracts
with minors) and the stores' rules for apps used by children, and is the
wording on the parent's responsibility right?

## 9. Students without a school (DL-072, policy 1.7 §5 and §6, terms 1.5 §5 and §8)

9.1 **Minors using Studafy, and its AI tools, outside any school.** Since
21 October 2026 a student can sign up with Google, Microsoft or Apple and
use Studafy without joining a class: a personal notebook only they can see,
and the AI study tools (the AI Tutor, notes from photos, quizzes and
flashcards), after an AI consent they give themselves. No school is
involved, Studafy holds no date of birth, and there is no age gate. Only a
child account a parent creates and manages gets a parent's consent. Policy
1.6 §5 said "We do not knowingly permit a child to create an account
outside a school context where their country requires parental consent for
it"; 1.7 replaces it with "We do not knowingly permit a child to use
Studafy without a parent's consent where their country requires it", and
points younger children to a parent-managed account. Please advise:
- the age of digital consent that applies to these students (GDPR Art. 8;
  Ireland sets 16; Jordan's PDPL), and whether a student under it may
  accept the terms and the AI consent alone;
- whether a parent's consent is needed, for the account, for the AI
  consent, or both, and how it should be obtained for a student who signed
  in themselves;
- whether an age gate, or an age band (DPIA measure M8), is needed before a
  student without a school can use Studafy or its AI tools;
- whether the replacement wording in §5 is acceptable, and whether Studafy
  is the controller for these students and for every student's personal
  notes (policy §1.1).

## 10. AI-suggested marks (DL-073, ADR-0046, policy 1.8 §6.1, terms 1.6 §4, §5, §8, §9)

Since 25 October 2026 a teacher with Studafy AI Marking can ask AI to
suggest marks for written answers in online exams and for hand-ins of
graded assignments (typed text, PDF, Word, PowerPoint, and photos or scans
of handwritten pages). The teacher writes a reference (model answer, key
points, accepted methods, partial-credit rules) and a strictness. The
question, the reference and the student's work go to Together AI, with the
names Studafy knows replaced and emails, long numbers and links removed;
photos and scans go as they are. The model suggests a score, what was met
and missed, and feedback. Suggestions are visible only to the class's
teachers and never become a mark until the teacher saves one through the
normal marking flow. The draft DPIA covers it in §12.2.

10.1 **Opt-out rather than consent, for minors.** The owner decided that
the student's consent is not asked: it is the teacher's tool for marking,
and a student (or the parent, for a child account the parent manages) can
opt out in Account, after which their work is never sent and is marked by
hand. Policy §4 relies on the school's legitimate interests or public task
where the school is controller, and otherwise on the teacher's and
Studafy's legitimate interests. Please advise:
- whether an opt-out is a sound basis for sending children's assessed work,
  including photos of their handwriting, to an AI provider, or whether
  consent (and a parent's, below the age of digital consent) is needed;
- whether students and linked parents must be told when a teacher first
  uses it (DPIA measure M22), beyond the policy;
- where a school is controller, whether the school must instruct it
  before a teacher on a personal paid plan may use it, and who is the
  controller of that processing;
- whether a suggested mark that the teacher reviews and saves, even
  unchanged, can be a decision "based solely on automated processing"
  (Art. 22; policy §14).

10.2 **The DPA, and starting before it.** The owner: "approve it and later
on with other versions we can add the DPA". The feature is on in the test
copy and off in production until launch, but the decision accepts starting
before Together AI's DPA is in place, as DL-062 did for the study tools.
What must the DPA add for this use (students' assessed work and images of
handwriting among the inputs; no training; retention), and can AI Marking
go live in production before it is accepted?

10.3 **Retention.** Suggestions are kept 180 days after they last changed,
then deleted; they are drafts for the teacher, not school records, and are
not in the student's export (the student's marks are). The teacher's usage
ledger (tokens, cost, model, date) is kept 13 months for the monthly cap and
billing questions. A student's opt-out is kept while the account exists.
Are these periods right, and should suggestions be in the student's export
under the right of access?

10.4 **Selling to teachers.** Studafy AI Marking is a monthly store
subscription a teacher buys for themselves (terms §9), possibly for use in
a school's classes. Anything to add to the terms for a teacher acting for a
school, or for VAT and invoices the stores do not provide?
