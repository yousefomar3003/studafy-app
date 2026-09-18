# Data classification and retention draft

ARC-001 deliverable: **draft** classification and retention candidates pending
qualified legal review (ADR-0008). Not a legal conclusion. No real personal
data exists in any environment as of 2026-09-10.

## Classification draft

| Data (table/flow) | Class | Sensitivity rationale | Retention candidate | Notes |
|---|---|---|---|---|
| `students` (identity, display/legal names, `studafy_id`) | P0 children's PII | Minors' identity data | Per school record policy; pseudonymise or delete subject to education-record obligations | `studafy_id` is a public locator — enumeration target |
| `guardian_links` (relationships, verification evidence) | P0/P1 | Family relationship data; evidence may be special-category | Link history long; evidence shorter than link; expiry/explicit revocation | Verification authority deferred (DL-014) |
| `grade_results`, `submissions`, `assessments`, `assessment_questions` | P1 education records | Academic performance and student work | Academic retention (term/years per school policy); legal-hold support | Publication state machine; corrections must append events |
| `attendance_records` | P1; reasons may be P0 | Attendance state + absence reasons (potentially health-adjacent) | Term-aligned retention; reasons strictest | |
| `wellbeing_events` | **P0 special-category candidate** | Strength/concern/incident notes on minors; possible child-safety data | Strictest proposed access + retention; export to safeguarding records where legally required | Do not auto-expose to all teachers/guardians |
| `messages`, `conversations`, `announcements` | P1 communications | Personal communications; moderation/legal-hold duties | Retention/moderation/reporting policy per counsel | Safeguarding access only via explicit audited policy |
| `profiles`, `memberships`, `consent_records` | P1 | Adult/child identity, roles, consent history | Consent history retained per accountability duty; profiles subject to deletion workflow | Deletion uses 14-day grace + audit |
| `notifications`, `meeting_deliveries` | P2 metadata | Operational pointers, no bodies | Short operational retention; strip provider error PII | |
| `audit_events`, `membership_events` (future) | P2 security audit | Accountability records; avoid copying P0 content into audit | Long retention per security policy; append-only | |
| `subscription_entitlements`, store receipts | P2 financial metadata | Purchase data; purchaser may differ from beneficiary | Financial/transaction retention per store and tax obligations | PAY-071 owns the ledger model |
| `ai_grading_drafts`, `question_suggestions`, `practice_sessions` | P1/P2 derived | Retired by AI-072 (ADR-0026): no role may read or write; legacy rows only | Shortest practical; delete legacy rows once the retention owner confirms no hold | No AI processing occurs; any legacy provider copies follow the provider-deletion step in the evidence log |
| Edge Function logs / future telemetry | P2 | May embed request IDs, errors, normalized account hashes | Redacted, bounded retention; no secrets/PII by construction | OPS-090 |

## Retention principles (candidates)

1. Retention is set per data class by school policy + legal review, not by
   engineering convenience; every table above needs an explicit decision
   before real data (ADR-0008 blocks the pilot).
2. Deletion is workflow-based (grace period, audit, export) — no silent hard
   delete of education records.
3. `audit_events`/membership history use append-only protection; corrections
   to grades/events append rather than overwrite.
4. Evidence attached to guardian verification may need shorter retention than
   the link itself.
5. Physical file deletion (future `file_objects`) follows reference counts and
   legal holds, not immediate deletes.

## Open legal questions (recorded, blocking — DL-011/DL-014)

Saudi PDPL lawful bases per purpose; children's-data and guardian-consent
rules; education-record retention obligations; export/correction workflow;
breach notification procedure; cross-border transfer assessment for F13–F15
(AI, Google, store verification); student age ranges; guardian verification
authority; school provisioning responsibilities.
