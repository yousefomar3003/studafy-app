# Data classification and retention

ARC-001 deliverable. The classification is still a **draft** pending
qualified legal review (ADR-0008). The retention periods are **fixed
proposed defaults** decided by the owner on 2026-10-14 (DL-057) for counsel
to confirm; privacy policy §10 states them, and the worker's retention
schedule (`RETENTION_SCHEDULE_ENABLED`, migration `202610140001`) enforces
the ones Studafy's own database holds.

"Class closure" below means the class was archived, or its last teacher's
account was deleted (which now archives it). "School instruction" means a
row in `private.school_retention_instructions`: with a period, that period
replaces the 12 months; without one, the records are kept until the school
asks for deletion.

## Classification and retention

| Data (table/flow) | Class | Sensitivity rationale | Retention (DL-057) | Notes |
|---|---|---|---|---|
| `students` (identity, display/legal names, `studafy_id`) | P0 children's PII | Minors' identity data | Name replaced on account deletion; enrolments deleted 12 months after class closure, or per school instruction | `studafy_id` is a public locator — enumeration target. A roster row with no account has no timed purge yet |
| `guardian_links` (relationships, verification evidence) | P0/P1 | Family relationship data; evidence may be special-category | While the account exists; revoked when either account is deleted | Verification authority deferred (DL-014) |
| `grade_results`, `grade_result_events`, `submissions`, `submission_attempts`, `assessments`, `assessment_questions`, `assessment_attempts`/`answers`, `assignments` | P1 education records | Academic performance and student work | Deleted 12 months after class closure, or per school instruction | Legal holds on anyone in the class, file holds and running file jobs defer the purge |
| `attendance_records`, `attendance_record_revisions` | P1; reasons may be P0 | Attendance state + absence reasons (potentially health-adjacent) | Deleted 12 months after class closure, or per school instruction | |
| `wellbeing_events` | **P0 special-category candidate** | Strength/concern/incident notes on minors; possible child-safety data | School's safeguarding policy; not purged with the class | Do not auto-expose to all teachers/guardians. Counsel to confirm a default where Studafy is controller |
| `messages`, `conversations` (incl. voice notes) | P1 communications | Personal communications; moderation/legal-hold duties | Deleted once the participants share no class and the last message is 12 months old (school instruction applies) | A conversation a safety report points at, or with a participant under legal hold, is kept |
| `announcements` | P1 communications | Class communications | Class announcements: deleted 12 months after class closure | School-wide announcements have no timed purge yet |
| `file_objects` (bytes via FILE-051) | P1 | Uploaded work, photos, voice notes | While attached to something; due for deletion as soon as the class records (or the account's personal files) that held it are gone | The FILE-051 sweep still checks holds, dedupe groups and live references |
| `notebook_entries`, `study_notebooks`, AI outputs | P1 | Student's own notes | Until the student deletes them or their account; kept when their class is purged | The class row stays as their anchor |
| `resources` (lessons) | P2 | Teaching material | Kept in the school's library; only the closed class's publications are removed | |
| `profiles`, `memberships` | P1 | Adult/child identity, roles | While the account exists; inactive accounts are deleted after 2 years without activity (warning 30 days before) | Deletion uses 14-day grace + audit. Activity = sign-in or token refresh |
| `consent_records` | P1 | Consent history | Life of the account, then 6 years | No longer deleted with the account |
| `account_deletion_requests` and `account_deleted` audit events | P2 accountability | Proof a deletion happened | Life of the account, then 6 years | |
| `audit_events`, `membership_events`, `auth_security_events` | P2 security audit | Accountability records; avoid copying P0 content into audit | 2 years (consent and deletion events: life of the account + 6 years) | Append-only for every role; only the owner's timed purge may delete, never update |
| `store_transactions`, `store_transaction_history`, `entitlements`, `store_events`, `billing_purchase_approvals`, `subscription_entitlements` | P2 financial metadata | Purchase data; purchaser may differ from beneficiary | 6 years after the end of the tax year (calendar year) they relate to | PAY-071 owns the ledger model |
| `notifications`, `meeting_deliveries` | P2 metadata | Operational pointers, no bodies | Deleted with the account; class meetings with the class | Other notifications have no timed purge yet |
| `ai_grading_drafts`, `question_suggestions`, `practice_sessions` | P1/P2 derived | Retired by AI-072 (ADR-0026) | **Deleted** (DL-057) | No provider ever received them; see `docs/evidence/phase-7/README.md` |
| Supabase Auth sign-in IP addresses | P1 | Network identifiers | Up to 7 days in Supabase's security logs; with an active session until it ends | Held by Supabase, not our tables |
| Technical logs (Axiom) | P2 | May embed request IDs, errors, account hashes | 30 days | The Axiom dataset's retention must be set to 30 days (owner action) |
| Error reports (Sentry) | P2 | Stack traces, device model | Up to 90 days | Sentry project setting |
| Backups | P1 (copies) | Full encrypted copies | 30 days | Already enforced |

## Retention principles

1. Every table above has a period (DL-057). They are proposed defaults; a
   change after counsel's review is a new decision-log entry and, where the
   policy text changes, a new policy version.
2. Deletion of an account is workflow-based (grace period, audit, export) —
   including inactive accounts, which go through the same request.
3. Append-only relations stay append-only: no role may update them, and only
   the table owner's timed purge (`studafy.retention_purge`, set by the
   `private.retention_*` functions) may delete from them.
4. Evidence attached to guardian verification may need shorter retention than
   the link itself.
5. Physical file deletion follows reference counts and legal holds, not
   immediate deletes.

## Open legal questions (recorded, blocking — DL-011/DL-014)

Saudi PDPL lawful bases per purpose; children's-data and guardian-consent
rules; education-record retention obligations; whether the 12-month
class-closure default is acceptable where Studafy is the controller;
export/correction workflow; breach notification procedure; cross-border
transfer assessment for F13–F15 (AI, Google, store verification); student
age ranges; guardian verification authority; school provisioning
responsibilities.
