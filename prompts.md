# Studafy task prompts

Copy-paste prompts for each remaining task, in execution order. One prompt per
task. Paste into a fresh capable coding-agent session in the repository root.

## How to use this

1. Work top to bottom. The order is the critical path from `instructions.md` §3.
2. Paste **one** prompt per session. These are large tasks; a fresh session per
   part keeps context clean.
3. Every prompt is self-contained — it names the sections to read, so you do not
   need to explain the project first.
4. Do not skip ahead to §B (native release). Those edits remove the guards that
   currently prevent shipping a non-functional app.

### Standing rules baked into every prompt

Each prompt below already carries the rules that matter. For reference, they are:

- Local and disposable databases only. Never migrate or deploy to the remote
  Supabase project (this repo is linked to one).
- Never edit an applied migration. Corrections are forward migrations.
- Never remove a SEC-001 containment guard outside §B.
- Never commit secrets. Keys go in ignored config or CI secrets.
- Record decisions in `docs/governance/decision-log.md` and an ADR.
- Produce evidence under `docs/evidence/<phase>/`.

---

# §A. Engineering phases

The remaining parts map to the roadmap tables in `instructions.md` §20 and the
design sections in §4–§19. API-042 and SAFE-043 were added by the 2026-09-13
launch audit; do not skip them.

## A1 — AUTH-030: Supabase Auth lifecycle

```
Implement Phase 3 Part 3A (AUTH-030) from instructions.md.

Read first: §6 (Authentication and authorisation design) and the Part 3A table
in §20. Follow both — §20 says what to build, §6 says how.

Scope: complete production session lifecycle. Provider sign-in, refresh,
expiry, revocation, all-device sign-out, account linking, MFA for admins,
recent-auth challenge for privileged actions, and account-deletion
impact/request/cancel.

Key requirements from the design:
- Validate JWKS iss/aud/alg/exp. Never trust role metadata from the client.
- Store tokens in Keychain/Keystore via a secure-storage adapter.
- Anti-enumeration on every auth error.
- Decide the truthful Apple guideline 4.8 posture: implement and physically
  test Sign in with Apple, or document and obtain acceptance of the current
  education/enterprise-account exception. Do not use the exception if public
  Google/Microsoft signup creates the primary account.
- Prefer an owned HTTPS Universal Link/App Link callback. If the custom URI
  scheme remains as fallback, prove state/nonce/PKCE enforcement and test
  callback hijacking.

Constraints: local/disposable Supabase only, never the linked remote project.
Forward migrations only. Do not touch SEC-001 guards.

Tests required: provider sandbox, expired/rotated/revoked JWT, deep-link
hijack, device and account switching, recent-auth bypass attempts.

Finish with: evidence in docs/evidence/phase-3/, an ADR, a decision-log entry,
and a report of what passes and what is still open.
```

## A2 — AUTH-031: Server authorization service

```
Implement Phase 3 Part 3B (AUTH-031) from instructions.md.

Read first: §6 (design) and the Part 3B table in §20. AUTH-030 must be done.

Scope: action/resource authorization catalogue and tenant middleware in
apps/api. Every handler declares a required permission and has a test proving
it is enforced.

Key requirements:
- Tenant context is derived server-side from memberships. Never from a client
  header, body field or JWT claim the client can set.
- Authorization decisions must agree with the DB-021 RLS policies. Prove API
  and RLS cross-tenant parity with tests, not by inspection.
- Version the context cache so a membership change or revocation invalidates
  it promptly.

Constraints: local only. Do not weaken any DB-021 policy or grant to make the
API easier — the database is the last line of defence.

Finish with: the permission catalogue documented, parity tests passing, and the
Phase 3 gate checklist in §20 assessed honestly.
```

## A3 — API-040: API platform controls

```
Implement Phase 4 Part 4A (API-040) from instructions.md.

Read first: §7 (API design and security) and the Part 4A table in §20.

Scope: shared Hono middleware in apps/api — request validation, typed error
envelope, idempotency keys, security headers, request size limits, timeouts,
and SSRF/mass-assignment defences.

The skeleton at apps/api/src/bootstrap/app.ts already has request IDs,
/healthz, /readyz and /version. Extend it; do not rewrite it.

Key requirements:
- Validate every input with the existing zod pin. Allowlist fields; never bind
  request bodies straight to database rows.
- Idempotency must be durable, not in-memory.
- Errors must not leak internal detail, stack traces or SQL.

Tests required: the negative/contract suite — malformed input, oversized
bodies, replayed idempotency keys, header injection, SSRF attempts.

Finish with: evidence in docs/evidence/phase-4/ and a decision-log entry.
```

## A4 — API-041: Core server-backed vertical slices

```
Implement Phase 4 Part 4B (API-041) from instructions.md.

Read first: §7 (design) and the Part 4B table in §20. API-040 and AUTH-031
must be done.

Scope: migrate the core flows to authoritative /v1 endpoints — classes,
content, assignments, attendance, grades. Transactions, outbox and idempotency
proven.

Key requirements:
- Every mutation runs in a transaction with actor and tenant context set.
- Side effects go through the outbox, never a direct call inside the request.
- Publish the contracts into packages/contracts and regenerate the Dart client
  (scripts/generate-dart-client.ts). Generated-type drift must stay clean.
- Remove a Deno Edge Function from traffic only after the replacement is at
  parity and tested.

Acceptance: no core production mutation is local-only.

Finish with: contract docs, evidence, and a decision-log entry.
```

## A4b — API-042: Remaining product workflows and school operations

```
Implement Phase 4 Part 4C (API-042) from instructions.md.

Read first: §6–§7 and the Part 4C table in §20. API-040, API-041 and AUTH-031
must be done.

Scope: make the rest of the launch product authoritative: school
provisioning/closure, invitations and membership lifecycle, classroom staffing
and enrollment transitions, family linking, communications, meetings,
notifications, profile/account rights, time-bounded support access and the
non-production reviewer tenant.

Replace the legacy Edge Functions only after equivalent Hono commands pass
authorization, transaction, idempotency and retry tests. In particular, fix
meeting recipient N+1/duplicate-event behavior and the JWT-iat account-deletion
check. Never deploy the prototype functions as the production backend.

Acceptance: a fresh approved school and every role can complete onboarding,
normal cross-device work and offboarding without local-only state.

Finish with: complete route/feature matrix, E2E evidence, runbooks, ADR and
decision-log entry.
```

## A4c — SAFE-043: Communications safety and safeguarding

```
Implement Phase 4 Part 4D (SAFE-043) from instructions.md.

Read first: the communications routes in §7, privacy/governance in §15, Apple
Guideline 1.2 and current Google Play UGC policy. API-042 communications must
exist and a moderation/safeguarding owner must be named.

Scope: clearly labelled in-app report-content, report-user and block/unblock
controls; content controls; tenant-safe moderation queue and tools; response
targets; safeguarding escalation; appeal; immutable evidence and legal holds;
published support contact and acceptable-use rules.

Do not use an AI classifier as the sole basis for a high-impact moderation
decision. Moderator access is least-privilege, time-bounded and audited.

Tests: blocked-contact denial, report discoverability, cross-tenant ID
substitution, abusive duplicate reports, moderator scope, restricted wellbeing
records, evidence retention/deletion and an end-to-end response drill.

Finish with: independent safety review evidence, operating runbook, training,
ADR and decision-log entry. Messaging remains disabled until this gate passes.
```

## A5 — FILE-050: Upload intent, metadata and quarantine

```
Implement Phase 5 Part 5A (FILE-050) from instructions.md.

Read first: §11 (File storage, upload security and deduplication) and the Part
5A table in §20.

Context that matters: the original SEC-001 vulnerability was a caller-selected
file path being signed by a service role. Do not reintroduce it.

Scope: server-issued signed upload intents bound to an authenticated owner,
tenant and purpose. Object metadata rows. Quarantine on arrival.

Key requirements:
- The server chooses the storage path. The client never supplies or influences
  it.
- Every object row records owner, tenant, purpose, size, declared type, and
  scan state. Default scan state is quarantined.
- Quotas enforced server-side before the intent is issued.
- Keep allowsRemoteFileUploads = false in lib/core/runtime_environment.dart
  until FILE-051 lands. This part builds the pipeline; it does not switch it on.

Tests required: path substitution denied, cross-tenant binding denied, quota
exhaustion, oversized and type-mismatched uploads.

Finish with: evidence in docs/evidence/phase-5/ and a decision-log entry.
```

## A6 — FILE-051: Scanning, transformation, publication and dedupe

```
Implement Phase 5 Part 5B (FILE-051) from instructions.md.

Read first: §11 (design) and the Part 5B table in §20. FILE-050 must be done.

Scope: malware scanning, safe transformation, publication, deduplication,
retention, and signed delivery that re-authorizes on every request.

Key requirements:
- Only a clean, scanned object may be published. Publication derives access —
  it never copies bytes.
- A signed delivery URL must re-check authorization at request time. A leaked
  URL must not be a standing grant.
- Deduplicate by content hash without letting one tenant learn another tenant
  holds the same file.
- Document the malicious-file response runbook.

Only after this part passes its gate may allowsRemoteFileUploads be flipped —
and that is a separate reviewed change with a decision-log entry.

Finish with: evidence, ADR and decision-log entry.
```

## A7 — OPS-060: Redis security, limits and selective caches

```
Implement Phase 6 Part 6A (OPS-060) from instructions.md.

Read first: §8 (Rate limiting and abuse prevention) and §9 (Redis caching
strategy), plus the Part 6A table in §20.

Scope: distributed rate limiting on every sensitive flow, and a catalogued set
of revocation-safe caches.

Key requirements:
- Rate limit auth, RPC, upload-intent, search and billing endpoints at minimum.
- Redis is private-network only, TLS, with AUTH. Never expose it publicly.
- Every cache entry is catalogued: key shape, TTL, what invalidates it. A
  membership or permission change must invalidate the derived cache.
- Never cache an authorization decision longer than its revocation budget.

Tests required: limit enforcement, failure behaviour when Redis is down (fail
closed on authorization, fail open only where documented), false-positive rate.

Note: four bun tests currently fail with ECONNREFUSED on 127.0.0.1:6379
because no local Redis is running. Start Redis via docker-compose.dev.yml
before working on this part.

Finish with: the cache catalogue documented, evidence, decision-log entry.
```

## A8 — OPS-061: BullMQ and outbox processing

```
Implement Phase 6 Part 6B (OPS-061) from instructions.md.

Read first: §10 (BullMQ and background processing) and the Part 6B table in §20.

Scope: BullMQ queues, the transactional outbox drain, DLQ, retries with
backoff, and workers in apps/worker. The smoke processor already there is the
pattern to extend.

Key requirements:
- Logical idempotency must survive crash and failover. A job that runs twice
  must not double-apply.
- The outbox is the only path from a transaction to a side effect.
- Queues must not be evicted — configure Redis persistence and memory policy
  accordingly.
- DLQ needs an operator runbook, not just a queue.

Tests required: crash mid-job, failover, duplicate delivery, poison message,
backlog drain.

Finish with: evidence, runbook, decision-log entry.
```

## A9 — MOB-070: Offline-capable mobile migration

```
Implement Phase 7 Part 7A (MOB-070) from instructions.md. This is the largest
remaining part — expect to split it across several sessions by feature slice.

Read first: the Part 7A table in §20, plus §1.3 for the current state.

Scope: migrate every remaining Flutter screen from direct SQLite to typed /v1
repositories, with a user-scoped offline cache, a mutation outbox, and conflict
rules.

The problem: there are 94 direct StudafyDatabase call sites — 32 across the
student presentation modules and 62 under lib/legacy/teacher/. Until these are
gone the app is a local single-device prototype.

Suggested order: pick ONE feature slice, migrate it end to end, prove it, then
repeat. Do not attempt all 94 at once.

Structural baseline: `lib/student_features.dart` is now a 15-line compatibility
barrel backed by 15 independently compiled, sub-650-line modules. Preserve that
architecture guard while replacing the 60 map-shaped declarations and direct
SQLite calls. The remaining teacher/parent umbrella `part` libraries must also
become independently compiled feature slices; presentation must receive typed
entities, not transport/SQLite maps.

Key requirements:
- Cache is scoped per user and school, re-keyed on session switch, wiped on
  sign-out.
- No offline grant, publish, admin or entitlement decision. Those are server
  authoritative, always.
- Eliminate hard-coded identities and the fake QR linking path.
- Replace hard-coded parent/student account emails with authenticated profile
  data.
- Complete English/Arabic localization and RTL. Prove VoiceOver/TalkBack,
  dynamic text, contrast, focus order and touch targets on supported devices.
- Implement claimed HTTPS deep links, notification navigation and safe
  background/termination recovery within platform limits.
- Respect the existing analyzer boundary rules (bun run check:bounds).

Acceptance: no production widget calls StudafyDatabase directly.

Tests required: airplane mode, reconnect, duplicate replay, conflict, partial
page, token expiry, role/school/account switch, cache extraction and wipe.
Also run bilingual/RTL, accessibility, claimed-link hijack, push
permission/tap/denial, low-memory and background-termination suites.

Tell me which slice you are starting with before you begin.
```

## A10 — PAY-071: Store billing and entitlement lifecycle

```
Implement Phase 7 Part 7B (PAY-071) from instructions.md.

Read first: §13 (Apple and Google in-app purchases), the Part 7B table in §20,
and §21.8 for the current stub's specific failures.

Context: supabase/functions/verify-store-purchase/index.ts does NOT verify with
Apple or Google. It forwards the receipt to a generic PURCHASE_VERIFIER_URL and
trusts the reply. Delete it and build properly in apps/api.

Scope:
- Apple: App Store Server API, verify the signed JWSTransaction chain against
  Apple root CAs. Handle App Store Server Notifications V2 (SUBSCRIBED,
  DID_RENEW, DID_FAIL_TO_RENEW, EXPIRED, REFUND, REVOKE, GRACE_PERIOD_EXPIRED).
- Google: Play Developer API purchases.subscriptionsv2.get, plus Real-Time
  Developer Notifications over Pub/Sub.
- An append-only store_transactions / store_events ledger as the source of
  truth. Derive entitlements from it. The DB-020 tables already exist.
- Idempotent webhook processing keyed on the store transaction ID.
- Environment and bundle checks so a sandbox receipt cannot grant production
  access.

CRITICAL: Google auto-refunds any purchase not acknowledged within 3 days.
Acknowledgement must be reliable, not best-effort.

Also fix lib/data/subscription_service.dart to handle PurchaseStatus.error,
.canceled and .pending, and to complete terminal-failure transactions so iOS
does not replay them forever.

Do not enable the paid Parent Insights product until legal sign-off exists
(see §29). Build the machinery; leave the product gated.

Tests required: full sandbox lifecycle, duplicates, out-of-order notifications,
account switch/link/delete, store outage, revoked access.
```

## A10b — AI-072: Resolve the AI capability

```
Implement Phase 7 Part 7C (AI-072) from instructions.md.

Read first: the Part 7C table in §20, the SEC-001 risk register and
kill-switch registry in docs/security/sec-001-containment.md, §15 (privacy),
and §22.6. FILE-051, AUTH-031 and API-041 must be done.

Context you must not miss: AI is the only capability with a shipped user
interface and no task behind it. Four student screens and the study_coach
feature slice exist today. propose-paper-grade is hard-disabled — it was the
original SEC-001 critical vulnerability, where a caller-selected path was
signed with service-role credentials and sent to a provider. study-coach is
NOT disabled: it forwards lesson material to whatever STUDY_COACH_URL names,
gated only by an environment variable.

This task has two lawful outcomes. Decide which, with a named owner, before
writing code:

- ENABLE, only if a signed DPA and a DPIA extended to AI processing of
  minors' data both exist. Then: a named provider adapter instead of the
  generic forward-to-a-URL; server-owned file_object_id only; per-request
  tenant and relationship authorization; redaction of student identifiers
  before egress; an egress allowlist so a changed variable cannot retarget
  the provider; quotas and cost caps; teacher review before any AI proposal
  affects a grade.

- REMOVE, if either is missing. Delete both Edge Functions, the AI screens and
  the study_coach slice, and the STUDY_COACH_* credentials. Leave no
  disabled-looking surface: a reviewer who finds a dead feature rejects under
  Apple 2.1.

Do not add an environment variable that re-enables AI. SEC-001 says so
explicitly, and study-coach is the counterexample this task exists to fix.

Constraints: local/disposable Supabase only. Forward migrations only. Removing
the allowsAiGrading guard, if you get there, is a reviewed change with an ADR
and a decision-log entry — never a side effect.

Tests required: path and URL substitution denied, cross-tenant material
denied, egress-allowlist bypass denied, redaction proven, quota exhaustion,
provider outage. On the removal path, a test asserting no AI route, screen or
credential remains.

Finish with: an ADR recording the direction and its evidence, the DPA/DPIA
references or their explicit absence, evidence in docs/evidence/phase-7/, and
a decision-log entry.
```

## A11 — INFRA-080: Runtime, network and Cloudflare

```
Implement Phase 8 Part 8A (INFRA-080) from instructions.md.

Read first: §14 (Cloudflare architecture), §12 (Encryption and secrets
management), and the Part 8A table in §20.

Blocked by: the data residency decision (ADR-0005 is Deferred). Confirm the
approved region before provisioning anything. If it is still open, stop and
tell me.

Scope: reviewed infrastructure-as-code for the container runtime, protected
origin, managed Redis, IAM and secret storage, with isolated environments.

Key requirements:
- The origin must not be reachable except through Cloudflare. Prove it with a
  direct-bypass test that fails safely.
- No secret in any image, log or environment dump.
- Environments are isolated — staging cannot reach production data.

Tests required: direct origin bypass, private cache behaviour, secret rotation.

Finish with: IaC in the repo, evidence, ADR and decision-log entry.
```

## A12 — INFRA-081: CI/CD and signed release

```
Implement Phase 8 Part 8B (INFRA-081) from instructions.md.

Read first: §18 (CI/CD and environments) and the Part 8B table in §20.

Scope: extend .github/workflows/ci.yml into a full pipeline — migration gates,
artifact signing, SBOM and provenance, and staged release. No unverified or
manual production release path may exist.

Key requirements:
- Pin and freeze every dependency. Builds must be reproducible.
- Sign artifacts; publish SBOM and provenance.
- The migration gate must refuse to apply to production without the recorded
  approvals.
- Wire the Flutter build number to CI so it strictly increases on every upload.

Do NOT remove the SEC-001 native guards here. Release builds stay blocked until
§B. Build the pipeline around them.

Finish with: evidence and a decision-log entry.
```

## A13 — OPS-090: Telemetry, SLOs and incident readiness

```
Implement Phase 9 Part 9A (OPS-090) from instructions.md.

Read first: §16 (Observability and incident response) and the Part 9A table
in §20.

Scope: logs, metrics, traces, SLOs, alerts, on-call rotation, runbooks, and a
demonstrated restore.

Key requirements:
- Telemetry must be PII-redacted. This app handles minors' data — no student
  name, email, submission content or wellbeing note may reach a log or an
  error tracker.
- SLOs need an owner and an error budget, not just a dashboard.
- Run a game day: page an owner, follow the runbook, record what happened.
- Demonstrate an actual restore and record the achieved time and data gap.

Finish with: runbooks in docs/, restore evidence, decision-log entry.
```

## A14 — SEC-091: Security, privacy and compliance readiness

```
Implement Phase 9 Part 9B (SEC-091) from instructions.md.

Read first: §15 (Privacy, compliance and data governance) and the Part 9B
table in §20.

Scope: threat model, penetration test, and the privacy and compliance
workflows that must be operational before real student data exists.

Key requirements:
- A DPIA for minors' data. This is the highest-risk area of the product.
- Data subject access, correction and deletion workflows that actually work
  end to end.
- Processor agreements for every vendor in the data-flow inventory.
- The retention schedule per data class, implemented and not just written.
- Close every critical and high finding. No unowned risk.

Note: several inputs here are legal decisions, not engineering (see §29). Where
counsel has not decided, implement the mechanism and leave the policy value
configurable — do not invent a legal conclusion.

Finish with: threat model, pentest report and remediation evidence, ADR,
decision-log entry.
```

## A15 — LAUNCH-100: Data migration and pilot

```
Implement Phase 10 Part 10A (LAUNCH-100) from instructions.md.

Read first: §26 (Migration and launch strategy) and the Part 10A table in §20.

Scope: rehearse the data migration at least twice in staging with
production-shaped synthetic data, then run a controlled single-school pilot.

Key requirements:
- Idempotent batch import with migration_batch_id, source key, canonical target
  ID, state and error code.
- Transform in the dependency order given in §26.
- Reject or route to human review every cross-school relation, duplicate
  identity, impossible timestamp or state, missing owner, unsupported file.
- Reconcile by tenant and entity: row counts, relationship counts, financial
  uniqueness, object counts and hashes, sampled semantic records.
- Two-person approval for any financial, entitlement or cross-tenant correction.
- Measure lock time, runtime and storage. Record them.

The pilot needs explicit stop and rollback criteria agreed before it starts.

Finish with: rehearsal evidence, reconciliation report, pilot report.
```

## A16 — SCALE-101: Progressive production scale

```
Implement Phase 10 Part 10B (SCALE-101) from instructions.md.

Read first: §19 (Performance and scalability) and the Part 10B table in §20.

Scope: load, soak, disaster-recovery and cost tests, then expand by cohort
against measured thresholds.

Key requirements:
- Each wave has an observation window and explicit stop/rollback criteria.
- Increase traffic only if availability, latency, errors, authorization denies,
  sync conflicts, queue age, scan lag, entitlement mismatch, database and Redis
  capacity, mobile crashes, support volume and cost all stay within bounds.
- Do not add replicas, partitioning, sharding or multi-region unless a measured
  threshold justifies it and an ADR records the trigger.

Finish with: load and DR evidence, cost model, decision-log entry.
```

---

# §B. Native release cutover (REL-002)

**Do not start §B until every Phase 3–10 gate has passed.** These prompts
remove the containment guards. Until the app is server-backed, those guards are
the only thing preventing a store upload of a non-functional product.

Identity is already decided: `io.studafy.app` (ADR-0015, DL-029).

## B1 — Android application identity and signing

```
Do §21.1 from instructions.md: Android application identity and release
signing.

Preconditions: confirm with me that all Phase 3-10 gates have passed and the
Google Play account exists with Play App Signing enrolled. If not, stop.

Changes to android/app/build.gradle.kts:
- line 18: namespace -> io.studafy.app
- line 29: applicationId -> io.studafy.app
- line 46: replace debug signingConfig with a release config reading from an
  untracked android/key.properties
- lines 9-15: delete the SEC-001 GradleException guard
- enable minify and resource shrinking; set targetSdk explicitly (API 36 is
  the 2026 baseline in §21.1; verify the live Play requirement first)

Also android/app/src/main/AndroidManifest.xml line 3:
android:label="studafy" -> "Studafy"

android/key.properties and *.jks are already covered by .gitignore — verify,
do not re-add. Do NOT generate the keystore yourself and do NOT ask me for
passwords: tell me the keytool command to run and what to put in
key.properties.

Record the guard removal as a forward change referencing REL-002 with a
decision-log entry, per docs/security/sec-001-containment.md.
```

## B2 — iOS application identity and signing

```
Do §21.2 from instructions.md: iOS application identity, signing and privacy
manifest.

Preconditions: same as B1, plus the Apple Developer account with the
io.studafy.app App ID registered. If not, stop.

Changes to ios/Runner.xcodeproj/project.pbxproj:
- lines 402, 583, 605: PRODUCT_BUNDLE_IDENTIFIER -> io.studafy.app
- lines 418, 435, 450: RunnerTests -> io.studafy.app.RunnerTests
- lines 155 and 239-252: delete the SEC-001 Release Block script phase
- set DEVELOPMENT_TEAM and Release code signing

Changes to ios/Runner/Info.plist:
- CFBundleName: studafy -> Studafy
- add ITSAppUsesNonExemptEncryption = false (we use TLS only)
- add NSCameraUsageDescription if image_picker ever uses the camera — a missing
  usage string is an immediate crash and a guaranteed rejection

Create ios/Runner/PrivacyInfo.xcprivacy using the template in §21.2 and add it
to Copy Bundle Resources. Then audit every plugin (sqflite, share_plus,
image_picker, file_picker, url_launcher, in_app_purchase, supabase_flutter) for
its own manifest and required-reason APIs.

Record the guard removal with a decision-log entry.
```

## B3 — App icons and launch assets

```
Do §21.3 from instructions.md: replace the default Flutter launcher icon and
launch screen.

android/app/src/main/res/mipmap-hdpi/ic_launcher.png is 544 bytes — the stock
Flutter logo. Shipping it risks rejection under Apple 4.3 and looks unfinished
on Play.

Add flutter_launcher_icons to dev_dependencies and wire it to a 1024x1024
source I will provide. Apple requires the 1024 icon to have NO alpha channel
and no transparency, or upload validation fails.

Also replace ios/Runner/Base.lproj/LaunchScreen.storyboard and
android/app/src/main/res/drawable/launch_background.xml.

Tell me what source asset you need from me and at what dimensions.
```

## B4 — Version identity in CI

```
Do §21.4 from instructions.md: wire the Flutter version and build number to CI.

pubspec.yaml currently has version: 1.0.0+1. The build number must strictly
increase on every upload to either store, including rejected ones.

Make CI own the build number. Do not leave it hand-edited.
```

## B5 — Privacy policy and terms

```
Do §21.6 from instructions.md: replace the hardcoded policy text with hosted
documents.

lib/features/session/presentation/login_page.dart:253 (showPolicy) currently
renders a single hardcoded paragraph in a bottom sheet for both Terms and
Privacy Policy. Both stores require a public URL.

Replace with url_launcher calls to the real hosted documents. I will provide
the domain and URLs.

Requirements:
- Publicly reachable, no login wall.
- English and Arabic, since the app ships both locales.
- Keep _termsPolicyVersion in
  lib/features/session/data/supabase_session_repository.dart:13 in lockstep
  with the published document version.

The same privacy URL goes into both store consoles.
```

## B6 — In-app account deletion

```
Do §21.7 from instructions.md: verify and complete in-app account deletion.

Apple 5.1.1(v) requires in-app deletion when an app offers account creation —
not an email link or a web form. Google Play requires an in-app path AND a
public web deletion URL.

supabase/functions/request-account-deletion exists and
lib/data/supabase_repository.dart:88 calls it. Audit the UI:
- Is deletion plainly reachable in the account screen for EVERY role — teacher,
  parent, student?
- Does it explain what is deleted versus retained?
- Does it complete without contacting support?

School-owned student records legitimately cannot be deleted by a student. That
must be explained in-app and the guardian/school path documented, or a reviewer
will read it as a missing deletion flow.

Report what exists and what is missing before changing anything.
```

## B7 — Supabase Data API final lockdown

```
Do §21.9 from instructions.md: final Data API posture review.

supabase/config.toml is already locked (schemas = ["public"], max_rows = 1000).
Keep it.

Now that Phase 4 has moved flows to the Hono API, audit every remaining direct
authenticated read grant from DB-021 and revoke the ones the API has replaced,
so the API becomes the only mutation path. Per DL-028.

Forward migrations only. Run the full pgTAP suite and the grants snapshot after
each revocation — the suite must stay green.
```

---

# §C. Store submission

## C1 — Store listings and console setup

```
Help me complete §25 from instructions.md: store console setup.

I need, for both Apple App Store Connect and Google Play Console:
- App name, short and full description in English AND Arabic
- Screenshot specs and what to capture
- Category, content and age rating questionnaire answers — note the app has
  teacher-parent messaging, which affects the rating
- Support and marketing URLs, privacy policy URL
- The IAP product studafy_parent_insights_monthly configured in both consoles
  to match the constant at lib/data/subscription_service.dart:12

Also draft the App Review notes. Read §23.1 first — our authorization model is
fail-closed, so a reviewer with no school membership sees an empty app and will
reject it as non-functional. The notes must include working credentials for a
seeded school with teacher, parent and student accounts, how to switch roles,
and an explanation that accounts are school-provisioned.
```

## C2 — Pre-submission rejection audit

```
Audit this repository against the rejection registers in instructions.md §23
(Apple) and §24 (Google) before I submit.

For every row in both registers, verify against the actual code and config
whether we now comply. Report a table: risk, status (pass/fail/unverifiable),
and the evidence you checked.

Be adversarial. Assume a reviewer is trying to reject us. Pay particular
attention to:
- Whether the app is genuinely functional with a fresh reviewer account
- Sign in with Apple actually working on iOS, not just present in the enum
- Restore Purchases being a visible UI control
- Subscription terms disclosed before purchase
- In-app account deletion for every role
- Privacy manifest accuracy against what the app really collects
- Data Safety answers matching observed behaviour
- Android target API meets the live submission floor (API 36 at the
  2026-09-13 audit)
- Claimed HTTPS OAuth links work and cannot be hijacked by another app
- Messaging has clearly labelled report-content, report-user and block-user
  controls backed by an owned moderation/safeguarding process

Note: store policies change. Flag anything where your knowledge may be stale
and I should verify against live store documentation.
```

## C3 — Staged rollout

```
Run the Phase 11 release sequence from instructions.md §20.

Steps 4-8: TestFlight and Play internal testing, closed testing with the pilot
school, then submission and staged rollout (Play 1% -> 5% -> 20% -> 50% ->
100%, iOS phased release).

For each stage tell me the go/no-go criteria to check before widening, and what
would trigger a halt. Remember installed binaries cannot be recalled — the only
real mobile rollback is a server-side kill switch plus a corrective build.

Expect at least one rejection round. If we are rejected, bring me the exact
guideline cited and a remediation plan before changing anything.
```

---

# §D. Non-engineering tasks

These are not prompts — no agent can do them. They are listed because they gate
everything above and have the longest lead times. See `instructions.md` §30 and
`docs/release/rel-002-store-accounts.md`.

| # | Task | Blocks |
|---|---|---|
| D1 | Register Apple Developer **organisation** account (D-U-N-S first) | All iOS submission; Sign in with Apple credentials needed by A1 |
| D2 | Register Google Play **organisation** account; enrol Play App Signing | All Android submission |
| D3 | Engage legal counsel: minors' data, consent, residency, paid insights | A14 (SEC-091), A10 product gating, A11 region |
| D4 | Name the independent security owner | Closes DB-021 and the Phase 2 gate |
| D5 | Stand up the domain; publish privacy policy and terms (en + ar) | B5, both console listings |

A useful prompt for D4, since the work is already done:

```
Prepare the DB-021 security review package for an independent reviewer.

Read docs/evidence/phase-2b/README.md, docs/database/db021-policy-matrix.md,
docs/database/db021-grants-inventory.md and ADR-0014.

Produce a single reviewer-facing document that states what to verify, how to
reproduce each claim locally, and what would constitute a failed review. The
reviewer should not have to read the migrations to know what they are
approving.
```
