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

## ★ Your to-do (start here)

Everything below needs you: an account, a payment, a decision or a
signature. Do them roughly in this order. When one is done, tell Claude
"done with Y1" (and so on), and give **file paths** for anything secret,
never the secret itself in chat.

**Y1 · Try the new build on your iPhone (30 min) — plan 2.9**
The 2026-10-11 build is installed. Try each, in English and then Arabic, and
report what failed with the time and the message:
- Teacher: add a lesson with a **Word file and a PDF**.
- Student: hand in an assignment with a **photo** and a **Word file**.
- Teacher: open that assignment's submissions and **open the student's file**.
- Teacher: correct a published paper mark by **changing only the comment**:
  it should save without asking for a reason.
- Teacher: mark an online exam: the "Saved" message now shows **above** the
  Save button.
- Any account: Profile → **Download my data**, or **Delete account** (use a
  spare test account for deletion). It now asks you to **sign in again**
  first: that is the new safety check.

**Y2 · Database logins (10 min) — plan 2.3**
1. Terminal: `openssl rand -base64 32 | tr -d '/+='`, run **twice**, for two
   passwords. Keep them in Apple Passwords.
2. Supabase → project `cyrngoqnhqflzovlybbr` → SQL Editor → New query. Paste,
   with your two passwords in place of `PASSWORD_1` / `PASSWORD_2`:
   ```sql
   alter role studafy_api_runtime login password 'PASSWORD_1';
   alter role studafy_worker_runtime login password 'PASSWORD_2';
   ```
   Run. Expect "Success. No rows returned."
3. Put the two passwords in a file only you can read, for example
   `~/studafy-runtime-passwords.txt`, one per line, labelled api and worker.
   Tell Claude the file path. Claude switches the Fly connection strings and
   redeploys.

**Y3 · Encrypted Redis (15 min) — plan 2.4**
1. Sign up at upstash.com (free). Create a Redis database in region
   **eu-central-1 (Frankfurt)**, with TLS on (the default).
2. Copy its `rediss://…` connection URL into a file, for example
   `~/studafy-redis-url.txt`. Tell Claude the path.

**Y4 · Clean up old access (20 min) — plan 2.5**
1. AWS console → IAM → Users → the Studafy user → Security credentials:
   **delete** the access key.
2. Fly: the suspended `studafy-api` app stores a Fly API token. Fly dashboard
   → Account → Access Tokens: **revoke** the token you created for GitHub
   deploys (or all you no longer use).
3. Tell Claude "go". Claude removes the unused secrets, destroys the stray
   `studafy` Fly app and deletes `fly-deploy.yml`.

**Y5 · Decide the app ID (decision, 5 min) — plan 3.1**
Today: `com.studafy.light`. Decided in September: `io.studafy.app`. It can
**never change** after the first Google Play upload. Tell Claude which one.
(Recommendation: `io.studafy.app`, as decided, if you own `studafy.io`.)

**Y6 · Android release key (20 min, after Y5) — plan 3.3**
Claude will give you one command that creates the upload key. You choose its
password, keep the key file and password in Apple Passwords plus a USB copy.
Losing it makes app updates painful.

**Y7 · Firebase for push notifications (30 min, after Y5) — plan 3.8**
1. console.firebase.google.com → Add project "Studafy".
2. Add an Android app with the ID from Y5. Download `google-services.json`.
3. Project settings → Service accounts → Generate new private key (a JSON).
4. Save both files outside the project folder. Tell Claude the two paths.

**Y8 · Google Play listing (1–2 h) — plan 3.6**
Create the app in Play Console with the ID from Y5. Fill in content rating,
target audience (children: Google's **Families policy** applies), and
the privacy policy URL (Claude can host a page first). Claude drafts the
**Data safety** answers for you.

**Y9 · Later, when ready**
- Apple account approved → tell Claude (stage 5: Sign in with Apple, iOS
  push, TestFlight).
- Choose a malware-scanning vendor (stage 4.4).
- Domains: own `studafy.com` / `studafy.io`? (stage 4.2).
- AI provider data agreement (DPA) and DPIA (stage 6).
- Backup key: copy `~/studafy-backup.key` to a USB stick.

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
- **Claude's open items** that need nothing from you: 2.8 (wait for the next
  lesson-save rejection), 4.3 hosted policy page (needs a domain or a
  temporary host), 4.7 alerts, 4.8 capacity, 7.1 test gaps, 7.2 docs.

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

- [x] **2.1 Account deletion and data export actually run** (PR-10) — done 2026-10-11: on in `fly.test.worker.toml` and `fly.worker.toml`, test worker deployed; local end-to-end 14/14 (see log) ·
  *Claude* · 0.5–1 day
  - Turn on `ACCOUNT_DELETION_EXECUTOR_ENABLED` and
    `DATA_EXPORT_EXECUTOR_ENABLED` on the test worker.
  - Run one deletion and one export with new synthetic accounts, never
    yours.
  - **Done when:** the synthetic account is deleted after the grace period,
    and its export downloads.
- [x] **2.10 Real re-authentication before deletion, export and device sign-out** — done 2026-10-11 (`7b7b0db`); on the test copy; real-token check passed locally; *You* confirm on the phone (Y1)
  (PR-30) · *Claude* · 1–2 days
  - Found 2026-10-11. The app asks for a "re-authenticated" grant without
    the person signing in again, and the server issues it to any valid
    session, so an unlocked phone or a stolen session token is enough to
    request account deletion. The 14-day grace period and cancel soften it,
    but with push and email off the owner is not told.
  - Fix: the server issues a grant only when the session's sign-in
    (`amr` timestamp) is recent (for example 5 minutes); the app signs in
    with the provider again first. Managed child accounts need their own
    rule (the guardian confirms). Also notify the account when deletion is
    requested, once push/email exist.
  - **Done when:** a grant is refused for an old session and issued right
    after a fresh sign-in (API tests), and the app flow works on the
    simulator.
- [x] **2.2 Production request timeout** (PR-15) — done 2026-10-11: `fly.api.toml` sets 20000, pinned by the Fly config test · *Claude* · 10 min
  - Add `API_REQUEST_TIMEOUT_MS = "20000"` to `fly.api.toml`. Quizzes and
    notebooks take longer than the 10 s default.
  - **Done when:** the Fly config test passes with the new value.
- [x] **2.3 Restricted database logins** (PR-08) — done 2026-10-14 by the owner: both runtime roles have passwords, the worker role can log in, both test apps connect as them, and the `postgres` password was reset; the API's startup log (2026-10-14 13:49) has no `database_privileged_role` · *You* run the SQL, then
  *Claude* · 30 min
  - In the Supabase SQL editor, give `studafy_api_runtime` and
    `studafy_worker_runtime` passwords (the exact SQL is in
    `docs/deployment/fly-io.md`, "Database roles"). Then Claude switches
    both Fly `DATABASE_URL` secrets and redeploys.
  - **Done when:** the startup logs no longer show `database_privileged_role`.
- [x] **2.4 Encrypted Redis** (PR-08) — done 2026-10-14 by the owner: a Redis Cloud database in Frankfurt over TLS (`rediss://`) for both test apps; the US database is deleted; no `redis_plaintext_remote` in the startup log · *You* create it, then *Claude* ·
  30 min
  - Create a Redis with TLS: Upstash, region `eu-central-1` (free tier has
    TLS), or a paid Redis Cloud plan. Give Claude the file path holding its
    `rediss://` URL, never the URL itself in chat.
  - **Done when:** the startup logs no longer show `redis_plaintext_remote`.
- [x] **2.5 Clean up old Fly apps and secrets** (PR-16) — done 2026-10-14 by the owner: `studafy-api`'s token revoked and its 43 secrets removed, `studafy` destroyed (absent from `fly apps list`), the full-access org token replaced by per-app deploy tokens, the local `fly-deploy.yml` deleted; AWS dropped · *You* · 30 min
  - Delete the AWS IAM key in the AWS console.
  - Revoke the Fly token stored in the suspended `studafy-api` app.
  - Then say "go" and Claude unsets the unused secrets there, destroys the
    stray `studafy` app and deletes `.github/workflows/fly-deploy.yml`.
  - **Done when:** `fly apps list` shows no `studafy`, and the suspended app
    holds only the secrets it uses.
- [x] **2.6 Two screen fixes** (PR-21) — done 2026-10-11 (`76b0c1e`): comment-only paper corrections need no reason (migration `202610110002`, on hosted); marking confirmation shown above Save · *Claude* · 0.5 day
  - The paper grade sheet should not ask for a reason when only the comment
    changes (online marking already doesn't).
  - The save confirmation should not cover the Save button on phones.
  - **Done when:** widget tests pass and both are checked on the simulator.
- [x] **2.7 Notebook writing in the background worker** (PR-23) — done 2026-10-11 (`67fd09a`), differently: API instances resume notebooks a stopped instance left (lease, max 2 resumes; migration `202610110003`, on hosted); tested by leaving one half-started · *Claude* ·
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

- [x] **3.1 Decide the app ID** (PR-04) — decided 2026-10-14 (DL-058): **`com.studafy.light`**, already claimed in the Google Play organization account and already the Android `applicationId` and iOS bundle id. The sign-in and class-join link scheme stays `io.studafy.app`; nothing to change in code · *You* · decision
  - Today: `com.studafy.light`. Decided on 2026-09-11 (DL-029):
    `io.studafy.app`. **It can never change after the first Play upload.**
  - **Done when:** you pick one and Claude applies it everywhere (Android,
    iOS, Supabase redirects, Google sign-in client).
- [x] **3.2 Internet permission in the release manifest** (PR-02) — done 2026-10-11 (`16ba19d`) in the main manifest, pinned by a test; the release-bundle check runs at 3.5 (the SEC-001 block stops even a release manifest merge until then) · *Claude* ·
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
  - *Progress 2026-10-12:* Claude's draft of the Data safety answers is in `docs/store/google-play-data-safety.md` (PR #34), with your decisions listed at the top. Android backup was turned off. Account deletion now removes what it left behind, including a parent's managed child accounts (3.6b, PR #35, not yet on hosted).
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
  - *Progress 2026-10-12:* prepared in PR #37. Policy 1.3 and terms 1.2, English and Arabic, plus the account-deletion page, on a static Cloudflare Worker at `/privacy`, `/terms`, `/delete-account` and `/ar/...`. Deployed 2026-10-13: https://studafy-legal.studafy.workers.dev/privacy and `/terms` answer, with all six pages checked. **Done when** still needs the app built with `STUDAFY_PRIVACY_URL` and `STUDAFY_TERMS_URL` pointing there, and the links opened from the subscription screens.
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
  - *Progress 2026-10-12:* the worker's backlog alerts to Telegram are built (PR #38, `docs/deployment/queue-alerts.md`). They cover depth, age, failures and stuck workers, with no spam. Sentry releases are now tagged per deploy, and log lines carry the environment. Review: `docs/operations/observability-review-2026-10.md`. On the test copy since 2026-10-13: the worker's Telegram secrets are set, and a test alert from the deployed worker reached Telegram. Uptime and Sentry/Axiom alerts already go through the relay. **Done when** for production waits on the production apps.
  - Uptime alert on the production URL; alerts on worker backlog
    (`file_scan_backlog`, `outbox_backlog`); AI spend limit at the
    provider.
  - Check Sentry and Axiom retention and scrubbing settings.
  - **Done when:** a test alert reaches Telegram for each.
- [ ] **4.8 Capacity re-check** (PR-19) · *Claude* · 1 day
  - *Progress 2026-10-12:* re-measured with exams, notebooks and AI, through the real API (PR #39, `docs/capacity/2026-10-12.md`). About 130 requests/s comfortable on 10 vCPUs; the first bottleneck is database CPU. `docs/operations/capacity.md` is updated. The recommendation is at least 4 dedicated database vCPUs and `DATABASE_POOL_MAX=10` per process; choosing the production size is yours.
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
  - *Progress 2026-10-12:* `ios/Runner/PrivacyInfo.xcprivacy` and `docs/store/app-store-privacy-labels.md` are drafted (PR #36). The permission prompts name every use. Submission waits on the Apple account.
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
  - *Progress 2026-10-12:* PR #40 adds tests for Family+, notifications, material reading and file scan (backend lines 89.9% → 91.0%). PR #41 adds accessibility checks on every main screen in English, Arabic and at 2× text, with the fixes they found (Flutter tests 774 → 794). PR #42 runs device tests on an iOS simulator and an Android emulator in CI, all green. Merge pending.
  - Family+ insights routes, notification processor, material reading,
    file scan.
  - An accessibility check on each main screen.
  - The simulator device tests running in CI.
- [ ] **7.2 Documentation brought up to date** (PR-26) · *Claude* · 0.5 day
  - *Progress 2026-10-12:* README, credentials map, ADR statuses (index and records), environment matrix and `handoff.md` are refreshed in the 7.2 PR.
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
| 2026-10-11 | 2.1 | Hosted had 0 pending deletion/export requests (read-only check), so enabling touched no account. Local end-to-end with both executors (synthetic user): export requested, built, downloaded with the profile; deletion requested, held for the grace period, executed once due (due time moved forward on the local DB only), profile de-identified, old session refused, sign-in refused: 14/14. Test worker deployed; startup shows both executors on, no errors |
| 2026-10-11 | finding | Re-authentication grants are issued without a fresh sign-in (PR-30): added as 2.10 |
| 2026-10-11 | 2.2 | `fly.api.toml` `API_REQUEST_TIMEOUT_MS=20000`, pinned by the Fly config test |
| 2026-10-11 | 2.6 | Paper comment-only corrections without a reason (pgTAP +3, widget test); marking notice inline, no snackbar (widget test) |
| 2026-10-11 | 2.10 | Grant only when `amr` sign-in is within 600 s; 403 `RECENT_SIGN_IN_REQUIRED`; app signs in again with the same provider and same account, else restores the session. Real local tokens: fresh 200, refreshed after 65 s with a 60 s window 403, signed in again 200 |
| 2026-10-11 | 2.7 | Resume of stalled notebooks (pgTAP +7; integration test half-started → ready, charged once) |
| 2026-10-11 | 3.2 | INTERNET and label "Studafy" in the main Android manifest; test reads it |
| 2026-10-11 | deploy | Backup (restore check passed, 7 files) → migrations `202610110002`, `202610110003` on hosted → API and worker deployed (ready, no errors) → new iPhone build installed |
| 2026-10-11 | 1.3 | PR #20 retitled and described for its 50+ commits; all 7 CI jobs green; merged by owner's instruction as `c3c1278`; `main` CI green |
