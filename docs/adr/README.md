# Architecture Decision Records

ADR index for Studafy. Each record follows: Status, Context, Decision,
Consequences. Records are immutable once accepted; supersede with a new ADR
that references the old one.

| ADR | Title | Status | Decision-log entry |
|---|---|---|---|
| [ADR-0001](ADR-0001-modular-monolith-target.md) | Modular monolith target architecture | Accepted (provisional on Phase 1 proofs) | DL-005 |
| [ADR-0002](ADR-0002-school-tenant-boundary.md) | School as tenant boundary; global multi-role users | Accepted | DL-006 |
| [ADR-0003](ADR-0003-supported-platforms.md) | Supported platforms: Android and iOS only | Accepted | DL-003 |
| [ADR-0004](ADR-0004-environment-matrix.md) | Environment matrix and separation | Accepted (records current facts) | — |
| [ADR-0005](ADR-0005-region-and-data-residency.md) | Production region and data residency | Deferred (blocks pilot/Phase 6) | DL-009 |
| [ADR-0006](ADR-0006-time-and-time-zones.md) | UTC storage, per-school IANA rendering | Accepted | DL-007 |
| [ADR-0007](ADR-0007-rto-rpo-candidates.md) | RTO/RPO provisional candidates | Deferred (blocks Phase 6) | DL-010 |
| [ADR-0008](ADR-0008-data-classification-and-retention.md) | Data classification and retention | Deferred (blocks pilot/legal) | DL-011, DL-014 |
| [ADR-0009](ADR-0009-billing-and-entitlements.md) | Billing product and purchaser/beneficiary model | **Decided** 2026-09-14 — four products, store IAP only, purchaser/beneficiary separated | DL-012, DL-036, DL-037 |
| [ADR-0010](ADR-0010-strangler-refactor-and-migrations.md) | Strangler refactor; forward-only migrations | Accepted | DL-008 |
| [ADR-0011](ADR-0011-monorepo-workspaces-and-toolchain.md) | Monorepo workspaces and pinned toolchain | Accepted | DL-016/017/018 |
| [ADR-0012](ADR-0012-flutter-feature-boundaries.md) | Flutter feature boundaries and the first typed vertical slice | Accepted | DL-019/020/021/022 |
| [ADR-0013](ADR-0013-db020-tenant-lifecycle-foundation.md) | DB-020 tenant and lifecycle foundation | Accepted for local/disposable use | DL-027 |
| [ADR-0014](ADR-0014-db021-least-privilege-database-access.md) | DB-021 least-privilege database access | Accepted for local/disposable use | DL-028 |
| [ADR-0015](ADR-0015-application-identity-and-store-accounts.md) | Application identity and store accounts | Accepted (identity); signing and privacy manifests open | DL-029 |
| [ADR-0016](ADR-0016-auth030-session-lifecycle.md) | AUTH-030 session lifecycle, token verification and Apple 4.8 posture | Accepted for local/disposable use | DL-032/033/034 |
| [ADR-0017](ADR-0017-auth031-server-authorization.md) | AUTH-031 action/resource authorization and server-derived tenant context | Accepted for local/disposable use | DL-038 |
| [ADR-0018](ADR-0018-api040-platform-controls.md) | API-040 shared validation, problem, durable idempotency and egress controls | Accepted for local/disposable use | DL-039 |
| [ADR-0019](ADR-0019-api041-authoritative-academic-slices.md) | API-041 authoritative academic slices, atomic commands, signed cursors and parity-gated Edge removal | Accepted for local/disposable use | DL-040 |
| [ADR-0020](ADR-0020-api042-school-operations.md) | API-042 school operations, invitations, family, communications, meetings, notifications, account rights and support access | Accepted for local/disposable use | DL-041 |
| [ADR-0021](ADR-0021-safe043-safety-and-safeguarding.md) | SAFE-043 reporting, moderation, blocks, legal holds and two-person moderator access | Accepted for local/disposable use | DL-042 |
| [ADR-0022](ADR-0022-file050-secure-upload-pipeline.md) | FILE-050 server-owned upload paths, purpose-bound intents, quotas, quarantine and outbox cleanup | Accepted for local/disposable use | DL-043 |
| [ADR-0023](ADR-0023-file051-scan-publication-delivery.md) | FILE-051 fail-closed scanning, deterministic metadata stripping, single-object publication, school-scoped dedupe, retention units and single-use re-authorizing delivery | Accepted for local/disposable use | DL-044 |
| [ADR-0024](ADR-0024-ops060-rate-limits-and-caches.md) | OPS-060 Redis security posture, rate-limit registry/middleware and revocation-safe version-keyed caches | Accepted for local/disposable use | DL-045 |
| [ADR-0025](ADR-0025-ops061-bullmq-outbox-platform.md) | OPS-061 BullMQ queue platform and transactional outbox drain | Accepted for local/disposable use | DL-046 |
| [ADR-0026](ADR-0026-ai072-remove-ai-capability.md) | AI-072 removes the AI capability: no signed DPA or extended DPIA exists | Accepted for local/disposable use; superseded in part by ADR-0029 | DL-047 |
| [ADR-0027](ADR-0027-messaging-safeguards-and-mobile-safety-controls.md) | Messaging contact policy, content-free notifications, enforced messaging switch, and mobile report/block controls | Accepted for local/disposable use | DL-049 |
| [ADR-0028](ADR-0028-localization-rtl-and-locale-persistence.md) | Arabic as a switchable language: gen-l10n copy, device-scoped persistence, device-first resolution, RTL, untranslated user content, Western digits | Accepted for local/disposable use | DL-055 |
| [ADR-0029](ADR-0029-study-plans-and-ai-lesson-tools.md) | Free Lessons and per-class notebook; Studafy Plus / Max resolved server-side; reserve-settle AI ledger with hard monthly caps; shared study sets; grounded AI gated | Accepted for local/disposable use; superseded in part by ADR-0034 and ADR-0037 | - |
| [ADR-0030](ADR-0030-flat-sql-dispatchers.md) | Flatten rename-and-wrap SQL chains into named handlers behind one dispatcher, proved by differential checks; the migration gate bans new chains | Accepted for local/disposable use | - |
| [ADR-0031](ADR-0031-managed-child-accounts-and-account-switching.md) | Parents create real student accounts for children with no email or phone, entered only through the parent by one-time sign-ins; several accounts per device with Instagram-style switching | Accepted for local/disposable use | - |
| [ADR-0032](ADR-0032-subscription-lifecycle-and-backups.md) | Store-only subscriptions with upgrade-at-limit, renewal status, per-token store events, pause-first cancel, store receipts plus verified-only notices; daily encrypted backups restored on every run | Accepted for local/disposable use | - |
| [ADR-0033](ADR-0033-paper-gradebook-corrections-and-deadlines.md) | Paper marks as `delivery=paper` assessments with draft/publish/correct in bulk, previous values kept in `grade_result_events`; attendance lock rule with lead-teacher override (no school admin in this release) and append-only history; extensions, reopen and a graded lock on hand-ins; lessons edited in place with retained files | Accepted for local/disposable use | - |
| [ADR-0034](ADR-0034-paid-plans-live-from-launch.md) | Studafy Plus, Max and Family+ live from launch: the four subscriptions listed in staging and production; lesson AI ships switched on, with the provider DPA and minors' DPIA as launch blockers | Accepted; production AI switch conditional on DPA and DPIA | - |
| [ADR-0035](ADR-0035-fly-sentry-axiom-and-alerts.md) | Fly.io in Frankfurt for API and worker; logs sampled at the source and shipped to Axiom; Sentry for API, worker and app errors with personal data off; email and Telegram alerts via a Cloudflare Worker relay with an outside uptime check | Accepted | - |
| [ADR-0036](ADR-0036-online-assessments-and-attachments.md) | Online assessments with a question builder, server-enforced answer release, retakes and extensions; titled links and multiple files on lessons, work and questions; shared and per-student paper-grade attachments | Accepted | - |
| [ADR-0037](ADR-0037-grounded-study-ai-and-token-allowances.md) | Lesson files and links (PDF, Word, PowerPoint, images, web pages) read once in the background with OCR for scans; answers grounded in permitted passages with citations and injection-safe material blocks; one token allowance per student (Free 40k a week, Plus 3M and Max 6M a month) with reserve-settle metering and request ids; background reading costed per school | Accepted for development and the test copy; real students need the DPA and DPIA | - |
| [ADR-0038](ADR-0038-study-notebooks.md) | A student's study notebook made from a lesson or chosen files, written in the background in a fixed cited structure, with the student's notes, highlights, bookmarks and sections kept through updates; quizzes and flashcards from it per version; quiz/flashcard fixes | Accepted for development and the test copy | - |
| [ADR-0039](ADR-0039-exact-material-selection-and-ai-usage.md) | Every AI study tool uses exactly the chosen lessons, lesson text and files, resolved and permission-checked per request; unreadable choices are named and only skipped on request; results keyed on the exact selection; one picker; AI usage shown as a bar and labels, never token counts | Accepted for development and the test copy | - |
| [ADR-0040](ADR-0040-marking-corrections-and-teacher-today.md) | Online work marked from the answers, the whole class listed (submitted, graded, published, not submitted, absent); marks are drafts until the all-or-nothing publish; only a change to a published mark or score is a correction with a reason, feedback alone is recorded without one; absence for non-submitters, never a zero; the attempt's feedback is published with the grade; a section needs content until a lesson filed for it is published (drafts never count); Today's work lists drafts, scheduled and open work and reloads when shown again | Accepted for development and the test copy | - |

Decision statuses are tracked in `docs/governance/decision-log.md`. Deferred
ADRs record the working assumption and the explicitly blocked later work, which
satisfies the ARC-001 acceptance rule that blocking open questions are either
decided or explicitly stop a later phase.
