# Production readiness assessment

Date: 2026-10-11. Branch `feat/mvp-school-operations-and-hosted-testing` at
`737c5c0` (50 commits ahead of `main`; 31 not yet pushed).

Scope:
- The whole repository: Flutter app, API, worker, shared packages, Supabase
  migrations, policies and tests, CI, Fly and Cloudflare configuration.
- What the Fly CLI, GitHub and the hosted test copy's public endpoints show.

Read-only queries were made against the hosted test database (aggregate
counts only). Nothing was changed for this report: Phase 1 is assessment
only.

Earlier evidence this builds on:
- `2026-10-08-security-audit.md` (ADR-0041), with fixes deployed;
- the 2026-10-11 upload and hand-in fixes (`0ba0fd0`), deployed and installed
  on the owner's phone;
- `2026-09-19-codebase-audit.md` (older; most items since closed).

Statuses used: **confirmed** (reproduced or seen in code, configuration or a
command's output), **risk** (plausible, not reproduced), **unverified**
(could not be checked from here).

---

## A. Executive summary

**Verdict: not ready to launch. Ready for a closed pilot with test accounts
after the P0 items marked "pilot" are fixed.**

### Strengths

The core school product works end to end and is unusually well defended for
its stage:

- **Authorization is enforced server-side**, twice:
  - every one of the 198 API routes declares a permission (a test fails if one
    does not);
  - each SQL dispatcher re-derives who may act from the signed-in identity;
  - all 376 database functions that run with elevated rights pin their search
    path;
  - every public table has row-level security.
- **Tests:**
  - 1,013 backend tests;
  - 37 database CI steps covering 56+ suites;
  - 765 Flutter tests;
  - device tests that drive the real screens.
- **Data protection:**
  - encrypted database connections (TLS 1.3, certificate verified);
  - daily encrypted backups that include uploaded files and are
    restore-checked on every run;
  - log redaction;
  - Sentry scrubbing.
- **Verified today on the iOS simulator against a real API, worker and
  Storage:** a teacher lesson with PDF and Word files, a student hand-in with
  files, and the teacher seeing and opening the hand-in. Online exams were
  verified the same way on 2026-10-08.

### What stops a public launch

1. **Store builds are deliberately impossible today.** SEC-001 guards block
   iOS and Android release builds and make a production app refuse to start.
   Behind the guards, an Android release would have **no internet
   permission** and is **signed with the debug key**.
2. **Store review blockers:**
   - Sign in with Apple is off while Google sign-in is on (guideline 4.8);
   - the app identity (`com.studafy.light`) differs from the decided one
     (`io.studafy.app`);
   - there is no app privacy manifest;
   - subscription screens have no terms or privacy links.
3. **Legal:**
   - no data processing agreement with the AI provider and no DPIA for
     children's data, so the privacy policy itself says the AI section
     "cannot honestly be published";
   - the AI features sold in Plus and Max cannot be offered until both exist.
4. **Production infrastructure does not exist yet:**
   - no domain (`api.studafy.com` and `app.studafy.io` do not resolve);
   - no Cloudflare protection;
   - no malware-scanning vendor, without which the production worker refuses
     to scan, so no uploads;
   - Redis without TLS;
   - services logging in as the database owner;
   - the single hosted database runs a development-mode copy.
5. **Required account rights do not complete.** Account deletion and data
   export requests are accepted, but their executors are off in production,
   so nothing is ever deleted or exported. App Store guideline 5.1.1(v) and
   GDPR both require this.
6. **Payments, push and email have never run against the real providers.**
   No sandbox, FCM, APNs or email credentials exist.

### Most serious operational risk

**31 commits exist only on this Mac.** They include online exams, AI, the
security fixes and today's upload fix. The deployed test copy runs code that
is not in GitHub and has never been through CI. A lost or damaged laptop
loses ten days of work.

---

## B. Architecture map

```
 Flutter app (iOS / Android)  ── Supabase Auth (Google, Microsoft; Apple off) ──┐
   lib/app, lib/features/*            issues JWTs                             │
   V1HttpTransport (bearer, refresh,  │                                       │
   idempotency keys, short read cache)│                                       │
        │ HTTPS                       ▼                                       │
        ▼                     ┌───────────────────────────────────────────┐   │
 Fly: studafy-api(-test) ────►│ Hono API (Bun)                            │   │
   platform: request id, CSP, │  auth (JWKS) → rate limit (Redis) →       │   │
   body/JSON limits, timeout, │  requirePermission (SQL authz) → handler  │   │
   client IP (Fly/Cloudflare) │  → private.api* dispatchers (SQL, RLS)    │   │
                              └──────────┬───────────────┬────────────────┘   │
                                         │ TLS           │ signed upload/     │
                                         ▼               ▼ delivery          │
                        Supabase Postgres (Frankfurt)   Supabase Storage     │
                        133 migrations, RLS, audit,     private bucket,      │
                        outbox, idempotency, AI ledger  quarantine → clean   │
                                         ▲               ▲                   │
 Fly: studafy-worker(-test) ─────────────┴───────────────┘                   │
   file scan + metadata strip, cleanup, outbox → BullMQ (Redis),             │
   in-app notifications, material index (AI OCR), housekeeping;              │
   OFF: push/email, deletion, export, meetings, billing, retention           │
 External: Together AI (pinned origin), Sentry (scrubbed), Axiom (EU),       │
   Cloudflare Worker alert relay → Telegram, Turnstile, GitHub Actions       │
   (CI, daily encrypted backup with restore check)                           │
```

**Trust boundaries.**
- The phone and its bearer token: the server re-derives identity and roles
  from the database, never from the token's claims.
- The API to the database: the API runs as the owner today; it should be
  `studafy_api_runtime`.
- Public upload into storage: a signed URL with a single path, then
  quarantine, structural scan and metadata strip before anything is served.
- Teacher-supplied links and documents to the AI model: material is wrapped
  as data, every hop is SSRF-guarded, and the provider origin is pinned.
- Store webhooks: verified with JWS/OIDC and deduplicated.

**Failure points.**
- One Redis carries the rate limits, the session cache and the queues, and it
  is plaintext on hosted.
- One database.
- Background notebook writing runs inside the API process (not durable).
- The AI provider: no fallback model.

---

## C. Feature inventory

| Feature | Status | Evidence | Next step |
|---|---|---|---|
| Sign-in with Google / Microsoft | Implemented, insufficiently tested | `api_session_repository.dart`; owner uses it on hosted; no automated device test | Device check per provider |
| Sign in with Apple | **Missing (switched off)** | `APPLE_SIGN_IN_ENABLED=false`; DL-033 says ship it | Apple Developer Program, Service ID, key; enable |
| Session revoke, devices, re-auth, MFA (TOTP) | Complete and verified | `verify-auth-lifecycle.ts` 26/26 as runtime role (2026-10-08); auth tests | — |
| Identity linking (second provider) | Partially implemented | `verifyProviderIdentity` not wired: server refuses all; app does not offer it | Wire or remove (P3) |
| Password login / reset | Not applicable | OAuth and magic link only | — |
| Teacher self sign-up, school workspace, classes, join links/codes | Complete and verified | Local API e2e 2026-10-11; pgTAP `teacher_self_signup` | — |
| Lessons with files and links | Complete and verified (locally); fix deployed to hosted | Simulator test 2026-10-11; hosted bucket fixed | Owner confirms on phone |
| Assignments, hand-ins with files, submissions list | Complete and verified (locally); fix deployed | Same; hosted had 0 submissions ever before the fix | Owner confirms on phone |
| Online exams: builder, attempt, marking, absence, corrections, release | Complete and verified (locally) | `exam_workflow_device_test` 2026-10-08; pgTAP `online_assessments` | Device check on hosted |
| Paper gradebook | Implemented, tested | pgTAP `paper_gradebook`; UX gap PR-21 | Fix PR-21 |
| Attendance, corrections | Implemented, tested (API/SQL only) | pgTAP `attendance_corrections` | Device check |
| Wellbeing notes | Implemented, tested; RLS gap fixed 2026-10-08 | `db021_access` | — |
| Messaging, announcements | Implemented, tested; verified locally 2026-10-08 | API tests | Push delivery (PR-12) |
| Meetings (pasted Google Meet link) | Implemented; calendar processor off | `MEETINGS_PROCESSOR_ENABLED` off | Decide whether invites are needed |
| In-app notifications | Complete (worker on) | `OPS061_NOTIFICATIONS_ENABLED=true` | — |
| Push and email notifications | **Partially implemented** | Sender built; no FCM/APNs/Resend credentials; `NOTIFICATION_CHANNELS_ENABLED` off | Credentials, then test |
| Guardian linking, parent views | Implemented, tested | pgTAP `guardian_links_students_only`, family suites | Device check as parent |
| Managed child accounts, switching | Implemented, tested | pgTAP `managed_accounts` | Device check |
| Family+ insights | Implemented, insufficiently tested | Routes 20% line coverage; cannot be bought (billing off) | Tests (PR-19) |
| Study notebooks, AI helper, quizzes, flashcards, summaries | Implemented and verified with the real model locally (2026-10-08); **legally blocked** | Production `AI_LESSON_TOOLS_ENABLED=false`; DPA/DPIA missing | PR-07 |
| AI reading of lesson files (OCR) | Implemented; off in production | `AI_MATERIAL_INDEX_ENABLED` off | Follows PR-07 |
| Subscriptions (Plus, Max, Family+) | **Implemented, never run against stores** | Billing off; no sandbox credentials; products unlisted outside synthetic | PR-11 |
| Account deletion | **Broken in effect** | Request works; executor off in production | PR-10 |
| Data export (download my data) | **Broken in effect** | Same | PR-10 |
| Reports, blocks, moderation, legal holds | Implemented, tested | SAFE-043 suites | Who operates moderation? (unverified, PR-28) |
| Support access | Implemented, tested (operator-only, MFA) | `api042_support_access` | Operator tooling unverified |
| File scanning | Implemented, structural only | No malware engine (`MALWARE_SCANNER_*` absent) | PR-06 |
| Offline cache, wipe on sign-out | Implemented, tested | Flutter tests | — |
| English/Arabic, RTL | Implemented, tested | `test/` locale tests | Device check in Arabic |
| Backups | Complete and verified | Daily workflow with files; restore check passes (run 38143723528) | Off-site retention (PR-13) |

---

## D. Prioritised issue register

Each entry: severity · category · confirmed / risk / unverified.

### P0 — launch blockers

**PR-01 · Release builds blocked; production app refuses to start · Critical · infrastructure · confirmed (deliberate)**
- **Evidence:**
  - `android/app/build.gradle.kts:14-19` throws "SEC-001: Android release
    builds are blocked";
  - an Xcode "SEC-001 Release Block" phase (`flutter build ios --release`
    fails with that message);
  - `lib/core/runtime_environment.dart`: `blocksApplicationStartup` and
    `allowsRemoteFileUploads` are false in production.
- **Impact:** no store build is possible, by design, until the gates below
  pass.
- **Fix:** the REL-002 cutover, which removes the guards in one reviewed
  change after PR-02 to PR-11.
- **Verify:** `flutter build appbundle --release` and `flutter build ipa`
  succeed, and a production build starts and uploads.

**PR-02 · Android release has no internet permission · Critical · functionality · confirmed**
- **Evidence:** `android/app/src/main/AndroidManifest.xml` declares only
  POST_NOTIFICATIONS and RECORD_AUDIO. INTERNET is in the `debug` and
  `profile` manifests only.
- **Impact:** a release APK or AAB cannot reach the API. The app would be
  unusable.
- **Fix:** add `<uses-permission android:name="android.permission.INTERNET"/>`
  to the main manifest.
- **Verify:** `aapt dump permissions` on a release build lists INTERNET.

**PR-03 · Android release signed with the debug key · Critical · infrastructure · confirmed**
- **Evidence:** `build.gradle.kts:52`, `signingConfig = signingConfigs.getByName("debug")`.
- **Fix:** an upload keystore (kept in CI secrets) plus Play App Signing.
- **Depends on:** PR-04 (identity).
- **Verify:** `apksigner verify --print-certs` shows the upload key.

**PR-04 · App identity not final · High · infrastructure · confirmed**
- **Evidence:**
  - the bundle and application ID is `com.studafy.light` (pbxproj line 406,
    `build.gradle.kts:35`);
  - DL-029 decided `io.studafy.app`;
  - the ID cannot change after the first store upload.
- **Fix:** decide which ID to use, then apply it to both platforms,
  Supabase redirect URLs, OAuth clients and Firebase apps.

**PR-05 · Sign in with Apple off · Critical (iOS review) · functionality · confirmed**
- **Evidence:** `APPLE_SIGN_IN_ENABLED=false` in every config; DL-033 commits
  to shipping it. Google sign-in is offered.
- **Impact:** App Store rejection under guideline 4.8.
- **Fix:** Apple Developer Program, an App ID with the capability, a Service
  ID and key in Supabase, then enable the flag.
- **Depends on:** PR-04, PR-09 (callback domain).
- **Verify:** a signed-in Apple account on a device.

**PR-06 · No malware scanner vendor · Critical · security · confirmed**
- **Evidence:**
  - `MALWARE_SCANNER_URL` and `MALWARE_SCANNER_API_KEY` are absent;
  - the production worker refuses to scan without them (`packages/config`
    superRefine);
  - the test copy uses the structural scanner only.
- **Impact:** no uploads in production. Without a vendor, files from
  children are not virus-scanned.
- **Fix:** choose a vendor (with a processing agreement) and integrate it
  behind the existing scanner interface.
- **Verify:** an EICAR test file and a clean file go through the production
  worker.

**PR-07 · AI features legally blocked · Critical · legal and product · confirmed**
- **Evidence:**
  - `docs/legal/privacy-policy.md:414-425`: "OUTSTANDING — MUST BE RESOLVED
    BEFORE PUBLICATION: no signed data processing agreement … no DPIA";
  - `fly.api.toml`: `AI_LESSON_TOOLS_ENABLED="false"`;
  - the owner decision (2026-10-02) is that Plus and Max, which sell AI
    features, are on at launch.
- **Impact:** paid plans cannot deliver what they sell. Enabling the
  features without the documents breaches Articles 28 and 35 GDPR.
- **Fix:** sign a DPA with Together AI (or switch provider), complete the
  DPIA, record an ADR superseding ADR-0026, then enable.
- **Alternative:** launch without Plus and Max.

**PR-08 · Production data path insecure or unconfigured · Critical · security · confirmed**
- **Evidence:**
  - the hosted Redis is `redis://` (plaintext; the Redis Cloud free endpoint
    refuses TLS);
  - the API and worker log in as `postgres`, which bypasses RLS (role setup
    denied in auto mode on 2026-10-08);
  - the one hosted database is "the planned production database" (handoff)
    yet serves a development-mode copy with Turnstile test keys and no HSTS.
- **Fix:**
  - a TLS Redis (`rediss://`);
  - runtime-role passwords and `DATABASE_URL` switched (steps in
    `docs/deployment/fly-io.md`);
  - a separate production Supabase project, or a decision that this one
    becomes production with test data wiped.
- **Verify:** production config validation passes (it refuses all three
  today).

**PR-09 · Domains, Cloudflare and origin lock not set up · High · infrastructure · confirmed**
- **Evidence:**
  - `api.studafy.com` and `app.studafy.io` have no DNS records;
  - the OAuth `site_url` (`supabase/config.toml`), the Apple callback, the
    delivery base URL and the Turnstile hostname all point at them;
  - the alert relay watches the test copy.
- **Fix:**
  - register DNS, proxy through Cloudflare, `fly certs add`;
  - set `ORIGIN_REQUIRE_CLOUDFLARE=true`;
  - add WAF and rate rules for auth and uploads.
- **Verify:** `https://api.studafy.com/readyz` is ready, and a direct
  `*.fly.dev` request is refused.

**PR-10 · Account deletion and data export never complete · Critical · compliance · confirmed**
- **Evidence:**
  - `ACCOUNT_DELETION_EXECUTOR_ENABLED` and `DATA_EXPORT_EXECUTOR_ENABLED`
    are off by default and not set in `fly.worker.toml`;
  - the request endpoints and executors exist and are tested
    (`account_deletion_seed`, `data_export_seed`).
- **Impact:**
  - App Store 5.1.1(v) requires in-app account deletion;
  - GDPR Articles 15, 17 and 20 require access and erasure;
  - users are told their request was received, and nothing happens.
- **Fix:** enable both in production (and on the test copy first), then run
  one full deletion and one export on synthetic accounts.
- **Verify:** the account is gone (or anonymised) after the grace period, and
  the export downloads.

**PR-11 · Payments never exercised against the stores · Critical (if selling at launch) · functionality · confirmed**
- **Evidence:**
  - no App Store Connect or Play sandbox credentials;
  - `PAY071_BILLING_ENABLED` off everywhere;
  - `store_products` unlisted outside synthetic (2026-10-02).
- **Fix:** create the products, sandbox testers and server keys, enable
  billing on the test copy, and buy, renew, refund and restore on both
  stores.
- **Verify:** entitlements follow each store event, including renewal and
  refund.

### P1 — high

**PR-12 · Push and email not delivered · High · functionality · confirmed**
- **Evidence:** no FCM or APNs credentials, no Firebase config files, no
  `RESEND_API_KEY`; `NOTIFICATION_CHANNELS_ENABLED` is off.
- **Impact:** messages, grades and announcements reach users only when they
  open the app.
- **Fix:** see the push setup the owner was given on 2026-10-11, then
  `scripts/send-test-notification.ts`.

**PR-13 · Work not pushed; CI has not run on 10 days of changes · High · process · confirmed**
- **Evidence:**
  - 31 local commits not on `origin`;
  - `main` lags by 50;
  - the deployed test copy runs unpushed code.
- **Fix:** push the branch; open a PR to `main`; make CI green.
- **Verify:** `git rev-list origin/<branch>..HEAD` is 0, and CI passes.

**PR-14 · CI Flutter job fails on GitHub's runner · Medium · testing · confirmed**
- **Evidence:** PR #32 runs 38139390818 and 38138543046.
  - "Verify synthetic debug build" was cancelled at the 30-minute limit, then
    failed with no log.
  - The same build succeeds locally in about 3 minutes.
- **Fix:** cache Gradle and Flutter in CI; raise `timeout-minutes` for that
  job; split the APK build into its own job.

**PR-15 · Production request timeout too short for AI · High · functionality · confirmed**
- **Evidence:** `fly.api.toml` has no `API_REQUEST_TIMEOUT_MS`, so the default
  is 10 s (8.5 s for the model). Quizzes take 6–9 s, notebooks 8–14 s
  (handoff). The test copy sets 20 s.
- **Fix:** set `API_REQUEST_TIMEOUT_MS = "20000"` in `fly.api.toml`.
- **Verify:** fly-config test, then a quiz on staging.

**PR-16 · Secrets and stray infrastructure · High · security · confirmed**
- **Evidence:**
  - the suspended `studafy-api` app holds unused AWS keys, a `FLY_API_TOKEN`,
    a Telegram token and other secrets;
  - the stray `studafy` app (cdg) has public IPs;
  - the untracked `fly-deploy.yml` uses an unpinned `@master` action with no
    permissions block;
  - `.env.hosted` on the laptop holds the hosted owner password and
    service-role key.
- **Fix:**
  - delete the IAM key; revoke the token; unset the unused secrets;
  - `fly apps destroy studafy`; delete `fly-deploy.yml`;
  - rotate the database password and service key before production.

**PR-17 · Backups: retention and recovery depth · High · reliability · confirmed and unverified**
- **Confirmed:** daily encrypted backups with files, restore-checked; GitHub
  keeps them 30 days.
- **Unverified:** the Supabase plan (daily backups and PITR are Pro and
  above).
- **Gaps:**
  - no off-site copy;
  - one private key, held on the laptop and in Apple Passwords;
  - no full disaster-recovery rehearsal into a new project.
- **Fix:** S3 copy (supported), Pro plan with PITR, a USB key copy, and one
  timed restore drill (`docs/deployment/backups.md`).

**PR-18 · Store submission prerequisites · High · compliance · confirmed**
- **Evidence:**
  - no `PrivacyInfo.xcprivacy` for the app target;
  - subscription screens read `STUDAFY_TERMS_URL` and `STUDAFY_PRIVACY_URL`,
    set in no build config, so the links are missing (guideline 3.1.2
    requires them);
  - privacy nutrition labels and the Data safety form are not drafted.
- **Fix:**
  - add the manifest;
  - host the policy and terms on the domain;
  - set the defines in release configs;
  - fill in both store forms.

**PR-19 · Capacity not re-measured since major features · High · performance · risk**
- **Evidence:** `docs/operations/capacity.md` measured on 2026-09-29 (10 vCPU,
  about 500 requests a second). Online exams, notebooks, material selection
  and AI were added after. The hosted compute size is unknown.
- **Fix:**
  - rerun `scripts/scale` on a throwaway copy with the new routes;
  - size the production database;
  - check `DATABASE_POOL_MAX` against the plan's connection limit.

### P2 — important

**PR-20 · Unexplained lesson-save rejection on the phone · Medium · functionality · unverified**
- **Evidence:** a hosted `POST /v1/resources` returned 400 before 2026-10-11
  12:00 UTC. The cause is unknown, and the same flow passes locally.
- **Fix:** the access log now records `problem_code` and `invalid_fields`
  (`34e4d6f`). Capture the next occurrence.

**PR-21 · UX inconsistencies from the handoff · Medium · UX · confirmed (handoff)**
- The paper grade sheet still asks for a reason on a comment-only change; online marking does not.
- A save confirmation covers the bottom Save button for a few seconds on phones.

**PR-22 · Test coverage gaps · Medium · testing · confirmed**
- **Backend lines:** 89.9% overall.
  - Family+ insights routes 19.6%;
  - notification processor 50.8%;
  - material index 62.1%;
  - file scan processor 65.6%;
  - billing routes 74.3%.
- **App lines:** 51.7% overall; school operations 39%; notifications 45%.
- **Missing:** no automated accessibility checks
  (`meetsGuideline`/semantics) and no device tests in CI. The only two
  device tests (exams, files) run locally by hand.
- **Fix:**
  - tests for the weak modules;
  - an accessibility guideline test on each main screen;
  - one device-test job (simulator) in CI.

**PR-23 · Background notebook generation not durable · Medium · reliability · confirmed (handoff)**
- Generation runs inside the API process. If a machine stops, the notebook
  times out after 10 minutes. Move it to the worker queue.

**PR-24 · Remaining lower-severity security items (ADR-0041 audit) · Low–Medium · security · confirmed**
- DNS rebinding window in the link fetcher.
- One free AI replay per charged request.
- A database write for each rejected token.
- No minimum password length in Auth config.
- Log shipper image `:latest`.
- Turnstile test keys and no bot protection on the test copy.

**PR-25 · Monitoring incomplete · Medium · observability · unverified**
- **In place:** Sentry, the Axiom log shipper, and an uptime alert to
  Telegram.
- **Unverified:** Sentry and Axiom retention and scrubbing settings.
- **Missing:**
  - no dashboards or SLOs;
  - no alert on worker backlog (`file_scan_backlog`, `outbox_backlog` are
    logged but not alerted);
  - no AI spend alert at the provider.

**PR-26 · Stale documentation · Low · maintainability · confirmed**
- The README says core screens use the local preview and the API exposes
  only health routes; both are false.
- `credentials-map.md` says AI keys are "retired".
- Several ADR statuses are out of date.
- A new developer would be misled.

### P3 — post-launch

**PR-27 · Identity linking unwired · Low · functionality · confirmed**
- The server refuses every link request; the app does not offer it.

**PR-28 · Moderation operations · Low · unverified**
- SAFE-043 moderation, legal holds and support access are operator-only
  (MFA).
- There is no school administrator by decision, and no operator console was
  found in this repository.
- Who reviews reports at launch, and with what tool, is undecided.

**PR-29 · Dependency drift · Low · maintainability · confirmed**
- 55 Dart packages have newer versions.
- Gradle warns that `firebase_core` and `sentry_flutter` use the Kotlin
  Gradle plugin in a way that will break in a future Flutter release.
- No known vulnerabilities (OSV, `bun audit`).

---

## E. Missing production requirements

- **Accounts:**
  - Apple Developer Program;
  - Play Console organization account;
  - App Store Connect API key;
  - Play service account.
- **Credentials:**
  - Apple sign-in key;
  - FCM service account and APNs key;
  - email provider key and verified domain;
  - store server keys;
  - malware scanner key;
  - production Supabase keys, rotated.
- **Infrastructure:**
  - a production Supabase project (or a decision);
  - TLS Redis;
  - domains and DNS;
  - Cloudflare zone, WAF and rate rules;
  - Fly production apps with runtime-role logins;
  - log shipper pinned.
- **Legal:**
  - DPA with the AI provider and with the scanner vendor;
  - DPIA for minors;
  - hosted privacy policy and terms;
  - store privacy forms;
  - named security, privacy and safeguarding owners.
- **Process:**
  - REL-002 cutover;
  - release checklist;
  - rollback runbook for app versions (store builds cannot be rolled back,
    only replaced);
  - incident contact;
  - moderation owner.

---

## F. Test results (actually run)

| What | When | Result |
|---|---|---|
| Backend `bun test apps packages scripts ops` (throwaway DB) | 2026-10-11 | **1,013 pass, 1 skip, 0 fail** |
| Backend coverage (`apps packages`) | 2026-10-11 | 980 pass; 89.6% functions, 89.9% lines |
| pgTAP, every CI step in order on a freshly reset stack | 2026-10-11 | **37/37 steps pass**, including 3 new upload assertions |
| Flutter `flutter test` | 2026-10-11 | **765 pass**; coverage 51.7% of lines |
| `flutter analyze`, typecheck, lint, format, bounds, migration gate | 2026-10-11 | Clean |
| `supabase db lint --level error` | 2026-10-08 | Clean (warnings only, pre-existing) |
| Device test: lesson + Word/PDF, hand-in + files, teacher views (iPhone 18 Pro simulator, local API/worker/Storage) | 2026-10-11 | **Pass** (after fixes; failed before, reproducing the owner's bug) |
| Device test: online exam end to end | 2026-10-08 | Pass |
| Local API e2e script (sign-up, class, join, uploads incl. Word, lesson, assignment, hand-in, download) | 2026-10-11 | Pass except one script assumption |
| `verify-auth-lifecycle.ts` as `studafy_api_runtime` | 2026-10-08 | 26/26 |
| AI with real model (Together, Qwen3.5-9B) | 2026-10-08 | Quiz, flashcards, notebook, helper OK |
| Builds | 2026-10-11 | iOS profile ✓ (44 MB); Android profile per-ABI ✓ (arm64 42.9 MB); Android debug ✓; **iOS and Android release blocked by SEC-001** |
| Secret scan (gitleaks, 160 commits) | 2026-10-11 | No leaks |
| `bun audit`, OSV (235 Bun + 186 Dart packages) | 2026-10-11 | No known vulnerabilities |
| Backup workflow with files + restore check | 2026-10-11 | Pass (7 files, 136 tables) |
| Hosted: `/readyz`, migrations up to date, bucket and quota values | 2026-10-11 | Ready; up to date; correct |

**Not run:**
- load or burst tests: not safe against the hosted copy; the last
  measurement was 2026-09-29;
- hands-on testing by a person on real phones (the owner's use today was
  only observed as activity in backups);
- OAuth providers end to end in automation;
- payments, push and email (no credentials);
- accessibility audits with VoiceOver or TalkBack;
- Android device runs;
- tablet layouts.

---

## G. Scorecard

| Area | Rating | Why |
|---|---|---|
| Functionality | Needs work | Core teaching flows work and are verified; deletion and export never complete; push, payments and Apple sign-in absent; AI blocked |
| Security | Good design, open infrastructure gaps | Strong authorization, RLS, upload pipeline and logging; production Redis TLS, DB role, Cloudflare and malware scanning missing (PR-06, 08, 09, 16) |
| Data integrity | Good | Idempotency, transactional SQL dispatchers, immutable keys, audit trail, versioned updates; tested |
| Testing | Good backend, moderate app | About 90% backend lines, 56+ DB suites; app 52%, no accessibility tests, device tests not in CI, CI currently red |
| Performance | Unknown at current scope | Measured well on 2026-09-29; not re-measured since major features; hosted size unknown |
| Reliability | Needs work | Backups solid; single Redis; notebooks not durable; worker processors off |
| UX and accessibility | Fair | Clear states and refusals, English/Arabic; two known UX issues; no accessibility audit |
| Infrastructure and deployment | **Not ready** | No production environment, domain, signing or release path (deliberately blocked) |
| Monitoring | Partial | Errors, logs and uptime wired; no dashboards or backlog alerts |
| Documentation and maintainability | Good, partly stale | Thorough ADRs, runbooks and handoff; README and some docs outdated; clean code, no TODOs |

None of these ratings hides the P0 items: **any one P0 is enough to stop a
public launch.**

---

## H. Remediation roadmap

| # | Item | Effort | Depends on | Done when |
|---|---|---|---|---|
| **P0 (pilot)** | PR-13 push branch, PR to `main`, CI green (PR-14) | 0.5 day | — | Branch on GitHub; CI green |
| | PR-10 enable deletion and export executors on the test copy; one full run each | 0.5–1 day | — | Synthetic account deleted, export downloaded |
| | PR-08 runtime roles and TLS Redis on the test copy | 0.5 day (+ provider signup) | Owner runs role SQL; Redis provider | Startup shows no `database_privileged_role` or `redis_plaintext_remote` |
| | PR-15 production timeout | 10 min | — | Config test |
| **P0 (store launch)** | PR-02 INTERNET permission; PR-03 release signing | 0.5 day | PR-04 | Release AAB has INTERNET and the upload key |
| | PR-04 identity decision and rename | 1 day | Owner decision | IDs consistent everywhere |
| | PR-05 Sign in with Apple | 1–2 days | Apple Developer Program, PR-09 | Works on a device |
| | PR-06 malware scanner | 2–4 days | Vendor and DPA | EICAR refused in production worker |
| | PR-07 DPA, DPIA, ADR | External; 1 day code | Legal | Policy section publishable; flag on |
| | PR-09 domains and Cloudflare | 1 day | Domain ownership | Origin lock on; WAF rules live |
| | PR-11 payments | 3–5 days | Store accounts | Buy, renew, refund, restore verified on both stores |
| | PR-18 store prerequisites | 1–2 days | PR-09 | Manifest, links and forms done |
| | PR-01 REL-002 cutover | 0.5 day | All above | Release builds and a production start succeed |
| **P1** | PR-12 push and email | 1–2 days | Firebase, Apple keys | Test notification on both platforms |
| | PR-16 secrets cleanup and rotation | 0.5 day | Owner access | No unused secrets; rotated keys |
| | PR-17 backups depth | 0.5 day + plan | AWS or Pro plan | Off-site copy; PITR; drill timed |
| | PR-19 capacity re-run | 1 day | — | Report with new routes; DB sized |
| **P2** | PR-20 to PR-26 | 3–5 days total | — | Each item's check passes |
| **P3** | PR-27 to PR-29 | as needed | — | — |

---

## I. Go-live checklist

- [ ] All work pushed; `main` contains it; CI green on `main`
- [ ] Production Supabase project decided and separated from testing; test data never in production
- [ ] API and worker log in as runtime roles; Redis `rediss://`; database TLS with CA verified
- [ ] Domains live behind Cloudflare; `ORIGIN_REQUIRE_CLOUDFLARE=true`; WAF and rate rules for auth and uploads
- [ ] Real Turnstile keys; HSTS on (production mode)
- [ ] Malware scanner integrated; EICAR test refused in production
- [ ] Account deletion and data export complete end to end in production
- [ ] DPA and DPIA signed, and AI enabled; or Plus/Max not sold
- [ ] Store products created; purchase, renewal, refund and restore tested on both stores
- [ ] Sign in with Apple works; identity final; release signing with upload key; INTERNET permission
- [ ] Privacy manifest, store privacy forms, hosted policy and terms, subscription links
- [ ] Push and email delivered on real devices
- [ ] Backups daily with files, off-site copy, PITR, restore drill timed
- [ ] Sentry, Axiom and uptime alerts on production; backlog and AI-spend alerts; on-call contact named
- [ ] Capacity re-measured; database sized; pool limits checked
- [ ] Unused secrets removed; credentials rotated; stray Fly app destroyed
- [ ] A person has gone through teacher, student and parent flows on iPhone and Android, in English and Arabic
- [ ] Moderation owner and process named
- [ ] SEC-001 guards removed in one reviewed REL-002 change
