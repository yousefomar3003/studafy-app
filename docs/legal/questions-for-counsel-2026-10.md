# Questions for counsel (October 2026)

For: the lawyers reviewing Studafy before launch. From: Yousef (owner),
drafted by Claude on 2026-10-16 from the code, the draft DPIA and the
decision log.

**This repository is public.** Keep your answers and any annotated copies
outside it; send them to hello@studafy.com.

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
