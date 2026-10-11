# Launch work plan

Started 2026-10-11. This is the working list for getting Studafy from the
current test copy to a store launch. It follows the production readiness
assessment (`docs/evidence/launch-readiness/2026-10-11-production-readiness.md`);
the `PR-xx` codes point at its issue register.

## How to use this file

- Work top to bottom: each stage assumes the one before it.
- Mark an item `[x]` only when its **Done when** check has actually been run,
  and add the date and the commit or evidence next to it.
- **Who:** *Claude* items can be done from the repository and the test
  copy. *You* items need an account, a payment, a legal signature or a
  decision only you can make.
- New problems go into the right stage with a new line; keep the order by
  priority.

## Where things stand (2026-10-11)

- **Apple Developer account:** applied for, waiting on email verification.
  Everything iOS-store-specific is in stage 5 and waits for it.
- **Google Play Console:** open. Android goes first (stage 3).
- **Test copy:** `studafy-api-test` and `studafy-worker-test` on Fly, against
  Supabase project `cyrngoqnhqflzovlybbr`. That project holds your test
  accounts: keep its data, never reset it.
- **Backups:** daily, encrypted, including uploaded files, restore-checked.
- **Release builds:** blocked on purpose (SEC-001) until the gates in this
  plan pass.

---

## Stage 1: Protect the work (now)

- [x] **1.1 Push the branch to GitHub** (PR-13) — done 2026-10-11, `21afe7d`; 0 commits left unpushed · *Claude* · 10 min
  - 31 commits since 2026-10-03 exist only on this Mac, and the test copy
    runs them.
  - **Done when:** `git rev-list --count origin/feat/mvp-school-operations-and-hosted-testing..HEAD`
    prints 0.
- [x] **1.2 Make CI reliable** (PR-14) — done 2026-10-11 (Android build in its own job; missing test-support dependency fixed in `c334412`); runs 38151306142 and 38152183833 fully green · *Claude* · 1–2 h
  - The Flutter job's Android build times out or fails on GitHub's runner.
    Cache Gradle and Flutter, give the APK build its own job and time limit.
  - **Done when:** two CI runs in a row are fully green.
- [x] **1.3 Open a pull request from the branch to `main`** — done 2026-10-11: PR #20 merged (`c3c1278`), CI on `main` fully green (run 38153948827) · *Claude*, merge by
  *You* · 30 min
  - **Done when:** `main` contains everything and CI is green on `main`.

## Stage 2: A safe, complete test copy (pilot-ready)

- [ ] **2.1 Account deletion and data export actually run** (PR-10) ·
  *Claude* · 0.5–1 day
  - Turn on `ACCOUNT_DELETION_EXECUTOR_ENABLED` and
    `DATA_EXPORT_EXECUTOR_ENABLED` on the test worker.
  - Run one deletion and one export with new synthetic accounts, never
    yours.
  - **Done when:** the synthetic account is deleted after the grace period,
    and its export downloads.
- [ ] **2.2 Production request timeout** (PR-15) · *Claude* · 10 min
  - Add `API_REQUEST_TIMEOUT_MS = "20000"` to `fly.api.toml`. Quizzes and
    notebooks take longer than the 10 s default.
  - **Done when:** the Fly config test passes with the new value.
- [ ] **2.3 Restricted database logins** (PR-08) · *You* run the SQL, then
  *Claude* · 30 min
  - In the Supabase SQL editor, give `studafy_api_runtime` and
    `studafy_worker_runtime` passwords (the exact SQL is in
    `docs/deployment/fly-io.md`, "Database roles"). Then Claude switches
    both Fly `DATABASE_URL` secrets and redeploys.
  - **Done when:** the startup logs no longer show `database_privileged_role`.
- [ ] **2.4 Encrypted Redis** (PR-08) · *You* create it, then *Claude* ·
  30 min
  - Create a Redis with TLS: Upstash, region `eu-central-1` (free tier has
    TLS), or a paid Redis Cloud plan. Give Claude the file path holding its
    `rediss://` URL, never the URL itself in chat.
  - **Done when:** the startup logs no longer show `redis_plaintext_remote`.
- [ ] **2.5 Clean up old Fly apps and secrets** (PR-16) · *You* · 30 min
  - Delete the AWS IAM key in the AWS console.
  - Revoke the Fly token stored in the suspended `studafy-api` app.
  - Then say "go" and Claude unsets the unused secrets there, destroys the
    stray `studafy` app and deletes `.github/workflows/fly-deploy.yml`.
  - **Done when:** `fly apps list` shows no `studafy`, and the suspended app
    holds only the secrets it uses.
- [ ] **2.6 Two screen fixes** (PR-21) · *Claude* · 0.5 day
  - The paper grade sheet should not ask for a reason when only the comment
    changes (online marking already doesn't).
  - The save confirmation should not cover the Save button on phones.
  - **Done when:** widget tests pass and both are checked on the simulator.
- [ ] **2.7 Notebook writing in the background worker** (PR-23) · *Claude* ·
  1 day
  - It runs inside the API today and is lost if the machine stops.
  - **Done when:** a notebook still finishes after the API restarts mid-way.
- [ ] **2.8 Find the remaining lesson-save rejection** (PR-20) · *Claude* ·
  when it recurs
  - The server now logs which field was refused (`problem_code`,
    `invalid_fields`).
  - **Done when:** the cause is found and fixed, or a week of use shows no
    recurrence.
- [ ] **2.9 Hands-on check on your phone** · *You* · 30 min
  - As teacher, student and parent, in English and Arabic:
    - lesson with a Word file and a PDF;
    - hand-in with a photo;
    - opening the student's file;
    - an online exam end to end.
  - **Done when:** you report each flow working, or the time and message of
    anything that fails.

## Stage 3: Android first (Google Play, internal testing)

Your Play Console account is open, so Android can reach real testers before
iOS.

- [ ] **3.1 Decide the app ID** (PR-04) · *You* · decision
  - Today: `com.studafy.light`. Decided on 2026-09-11 (DL-029):
    `io.studafy.app`. **It can never change after the first Play upload.**
  - **Done when:** you pick one and Claude applies it everywhere (Android,
    iOS, Supabase redirects, Google sign-in client).
- [ ] **3.2 Internet permission in the release manifest** (PR-02) · *Claude* ·
  10 min
  - Without it a release build cannot reach the server.
  - **Done when:** `aapt dump permissions` on a release bundle lists
    INTERNET.
- [ ] **3.3 Release signing** (PR-03) · *You* create the key with Claude's
  steps, *Claude* wires it · 1 h
  - Create an upload keystore, keep it and its password outside the repo
    (and backed up), and turn on Play App Signing.
  - **Done when:** the release bundle is signed with the upload key, not the
    debug key.
- [ ] **3.4 Google sign-in for the release build** · *You* in Google Cloud,
  *Claude* checks · 30 min
  - Add the release (Play App Signing) SHA-1 to the Android OAuth client.
  - **Done when:** sign-in works in the internal-testing build.
- [ ] **3.5 Lift the Android release block for internal testing only** (PR-01)
  · *Claude*, approved by *You* · 0.5 day
  - A reviewed change that allows an Android release bundle while
    production mode stays off. Internal testers use the test copy
    (`APP_ENV=development`).
  - **Done when:** `flutter build appbundle --release` succeeds, and iOS
    stays blocked.
- [ ] **3.6 Play Console listing** · *You* · 1–2 h
  - Create the app.
  - Target audience and content: Studafy serves children, so Google's
    **Families policy** applies (no ads SDKs, a clear privacy policy,
    teacher-appropriate content).
  - Content rating, Data safety form (Claude drafts the answers from the
    code), privacy policy URL (needs 4.2, or a temporary hosted page).
  - **Done when:** the console shows no missing items for internal testing.
- [ ] **3.7 First internal-testing release** · *Claude* builds, *You*
  upload · 30 min
  - **Done when:** you and one tester install from Play and complete 2.9's
    flows.
- [ ] **3.8 Android push notifications** (PR-12) · *You* create Firebase,
  *Claude* wires and tests · 2 h
  - Firebase project, Android app with the chosen ID, the service-account
    key for the worker (as a file path, not in chat), and
    `google-services.json`.
  - **Done when:** `scripts/send-test-notification.ts` prints `sent` and the
    phone shows it.
- [ ] **3.9 Google Play billing in sandbox** (PR-11) · *You* create the
  products and service account, *Claude* wires and tests · 2–3 days
  - Products: `studafy_plus_monthly`, `studafy_max_monthly`,
    `studafy_family_plus_monthly`, `studafy_family_plus_8_monthly`.
  - Add license testers, the Pub/Sub topic for notifications and a service
    account for the server.
  - **Done when:** buy, renew, cancel, refund and restore all update the
    entitlement correctly on the test copy.

## Stage 4: Production environment

- [ ] **4.1 Decide the production database** · *You* · decision
  - Either a new Supabase project for production (recommended: test data
    never mixes with real children's data), or turn
    `cyrngoqnhqflzovlybbr` into production after a wipe.
  - Also choose the plan: Pro gives daily backups and point-in-time
    recovery.
  - **Done when:** decided, and recorded in an ADR.
- [ ] **4.2 Domains and Cloudflare** (PR-09) · *You* own DNS, *Claude*
  configures · 1 day
  - `api.studafy.com` (API) and `app.studafy.io` (sign-in callback, legal
    pages), or one domain for both (decide).
  - Proxy through Cloudflare, `fly certs add`, WAF and rate rules, then
    `ORIGIN_REQUIRE_CLOUDFLARE=true`.
  - **Done when:** `https://api.studafy.com/readyz` is ready, and a direct
    `*.fly.dev` request is refused.
- [ ] **4.3 Host the privacy policy and terms** (PR-18) · *Claude* · 0.5 day
  - On the domain. Set `STUDAFY_TERMS_URL` and `STUDAFY_PRIVACY_URL` in the
    release build settings.
  - **Done when:** both links open from the subscription screens.
- [ ] **4.4 Malware scanner** (PR-06) · *You* choose the vendor and sign its
  terms, *Claude* integrates · 2–4 days
  - **Done when:** an EICAR test file is refused and a clean PDF passes in
    the production worker.
- [ ] **4.5 Production apps on Fly** · *Claude* · 1 day
  - `studafy-api` and `studafy-worker` in production mode:
    - runtime roles and TLS Redis (2.3, 2.4);
    - real Turnstile keys;
    - deletion, export and notification executors on;
    - log shipper image pinned.
  - **Done when:** both start in production mode (the config check refuses
    any gap).
- [ ] **4.6 Backups for production** (PR-17) · *You* (plan or AWS),
  *Claude* · 0.5 day
  - The daily backup pointed at production; an off-site S3 copy or
    point-in-time recovery; a second offline copy of the backup key (USB).
  - One timed restore drill into a new project.
  - **Done when:** the drill's time is recorded in `docs/deployment/backups.md`.
- [ ] **4.7 Monitoring and alerts** (PR-25) · *Claude* · 1 day
  - Uptime alert on the production URL; alerts on worker backlog
    (`file_scan_backlog`, `outbox_backlog`); AI spend limit at the
    provider.
  - Check Sentry and Axiom retention and scrubbing settings.
  - **Done when:** a test alert reaches Telegram for each.
- [ ] **4.8 Capacity re-check** (PR-19) · *Claude* · 1 day
  - Re-run `scripts/scale` on a throwaway copy with the routes added since
    2026-09-29 (exams, notebooks, materials, AI).
  - **Done when:** `docs/operations/capacity.md` is updated, and the
    production database size and pool settings are chosen from it.
- [ ] **4.9 Rotate credentials before real users** (PR-16) · *Claude* with
  *You* · 1 h
  - Database password, service-role key and signing keys. `.env.hosted`
    keeps only what testing needs.
  - **Done when:** the old values no longer work.

## Stage 5: iOS (when the Apple account is approved)

- [ ] **5.1 Apple Developer Program active** · *You*
- [ ] **5.2 App ID and capabilities** · *You*, with Claude's steps
  - Register the ID from 3.1; Sign in with Apple; Push Notifications.
- [ ] **5.3 Sign in with Apple** (PR-05) · *Claude* · 1–2 days
  - Service ID and key into Supabase; enable `APPLE_SIGN_IN_ENABLED`.
    Required because Google sign-in is offered (App Store guideline 4.8).
  - **Done when:** an Apple account signs in on a device.
- [ ] **5.4 iOS push notifications** (PR-12) · *You* create the key and
  the Firebase iOS app, *Claude* wires and tests · 2 h
  - Uses the same Firebase project as Android (3.8).
  - Steps for *You*:
    1. Apple Developer → Keys: create an **APNs** key and download its `.p8`
       (it downloads once). Note the Key ID and your Team ID.
    2. Firebase → Project settings → Cloud Messaging → Apple app
       configuration: upload the `.p8` with the Key ID and Team ID.
    3. Firebase → add an iOS app with the ID from 3.1, then download
       `GoogleService-Info.plist`. Give Claude the file path, not the file
       in chat.
  - *Claude* turns on the Push Notifications capability for the real team
    (`aps-environment` is already in `Runner.entitlements`; release uses
    `production`), adds the plist and builds with `PUSH_ENABLED=true`.
  - The server side needs nothing new: the worker's Firebase key from 3.8
    sends to iPhones too.
  - **Done when:** `scripts/send-test-notification.ts` prints `sent`, and
    the iPhone shows it, with the app both open and closed.
- [ ] **5.5 App privacy manifest and App Store privacy labels** (PR-18) ·
  *Claude* drafts, *You* submit
- [ ] **5.6 App Store subscriptions in sandbox** (PR-11) · *You* create the
  products, *Claude* wires and tests
- [ ] **5.7 TestFlight build** · *Claude* builds, *You* upload
  - **Done when:** you and one tester install from TestFlight and complete
    2.9's flows.

## Stage 6: Legal and AI

- [ ] **6.1 Data processing agreement with the AI provider** (PR-07) · *You*
  - Together AI, or another provider with an EU or acceptable transfer
    basis.
- [ ] **6.2 DPIA covering children's data and AI** (PR-07) · *You*, Claude
  can draft
- [ ] **6.3 ADR superseding ADR-0026, then turn AI on in production** ·
  *Claude* · 1 day
  - **Done when:** the privacy policy's "OUTSTANDING" box can be removed
    truthfully.
  - **If not ready by launch:** launch without Plus/Max, or without their AI
    parts.
- [ ] **6.4 Named owners** · *You*
  - Security, privacy, safeguarding contact; who reviews reports
    (moderation, PR-28); on-call for incidents.

## Stage 7: Launch

- [ ] **7.1 Tests and coverage gaps closed** (PR-22) · *Claude* · 2–3 days
  - Family+ insights routes, notification processor, material reading,
    file scan.
  - An accessibility check on each main screen.
  - The simulator device tests running in CI.
- [ ] **7.2 Documentation brought up to date** (PR-26) · *Claude* · 0.5 day
  - README, `docs/security/credentials-map.md`, ADR statuses.
- [ ] **7.3 Release cutover (REL-002)** (PR-01) · *Claude*, approved by *You*
  - Remove the SEC-001 guards in one reviewed change, only after every item
    above.
- [ ] **7.4 Go-live checklist** · *Claude* and *You*
  - Every box in section I of the readiness assessment ticked, with
    evidence.

## Later (after launch)

- Identity linking: a second sign-in provider on one account (PR-27).
- Link fetcher DNS-rebinding guard; free AI replay; denial-event write
  volume (PR-24).
- Dependency updates and the Kotlin Gradle plugin warnings (PR-29).
- App size trims: debug symbols split, unused plugins removed.

## Log

| Date | Item | Result |
|---|---|---|
| 2026-10-11 | Plan created | From the readiness assessment |
| 2026-10-11 | 1.1 | Branch pushed (32 commits); `origin` matches local |
| 2026-10-11 | 1.2 | Android build moved to its own job (Gradle cached, memory capped, arm64 only): 11–12 min, was timing out at 30. Typecheck failed on a clean install: `@studafy/test-support` was undeclared in `domain` and `infrastructure`; reproduced and fixed in a fresh clone. Two consecutive green CI runs |
| 2026-10-11 | 1.3 | PR #20 retitled and described for its 50+ commits; all 7 CI jobs green; merged by owner's instruction as `c3c1278`; `main` CI green |
