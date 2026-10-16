# Go-live checklist

Status as of **2026-10-17**, `main` at `5021720`. Launch plan D2, work plan
7.4: every box in section I of the
[production readiness assessment](2026-10-11-production-readiness.md), and
every issue in its register (PR-01 to PR-30), with evidence.

How this was checked:
- Each claim was checked against the repository on `main`, not only the
  planning docs: Fly configs, `packages/config`, the Gradle and Xcode
  projects, the app's runtime policy, the Supabase config and the legal
  site.
- Also read: CI runs on `main` (`gh run list`), the merged PRs (#1–#98), the
  decision log through DL-067 and `handoff.md`.
- Public endpoints were checked read-only on 2026-10-17 (`dig`, `curl`).
- The hosted database and Fly were **not** queried: no DB, no `fly`, no
  secrets. A hosted-side claim taken from `handoff.md` or the work plan
  says so.

Statuses:
- **Done:** the item's check has been run; date and evidence given.
- **Partly:** some of it is done; what is left is named.
- **Waiting on owner:** only an owner input is left (an account, a key, a
  decision, a hands-on check).
- **Not started.**

Work that other open branches are doing today is marked *in progress* and
is not described further here:
- privacy policy 1.5 (`docs/legal`);
- the release cutover (D1 / REL-002);
- the production cutover scripts;
- the screenshots.

---

## Summary: what blocks each release

Counts:
- **Section I (19 items):** 2 Done, 12 Partly, 5 Waiting on owner, 0 Not
  started.
- **Issues (30):** 10 Done, 11 Partly, 7 Waiting on owner, 2 Not started.
  Both not-started issues are post-launch by plan: PR-27 and PR-29.

### (a) Google Play internal testing

The build runs against the test copy (`APP_ENV=development`, ADR-0042), so
no production work is needed. Left:

1. **Upload keystore** and Play App Signing (C1, 3.3). Gradle is wired
   (#61) and refuses to fall back to the debug key, so no uploadable bundle
   can be built until the key exists.
2. **Play Console app and internal-testing setup** (B12, 3.6):
   - create the app;
   - content rating;
   - target audience, where the Families policy applies;
   - the Data safety form, from `docs/store/google-play-data-safety.md`;
   - the privacy policy URL. `https://legal.studafy.com/privacy` answers 200.
3. **Release SHA-1 on the Android OAuth client** (C2, 3.4), or Google
   sign-in fails in the Play build.
4. **Upload and install with one tester** (C4, 3.7). Claude builds the
   bundle after C1.
5. **Recommended before testers:** the owner's hands-on check (B5, 2.9).
   It also closes 2.8, PR-20 and PR-30's phone confirmation.

Not needed for internal testing:
- push (C3; the app builds without `google-services.json`);
- billing (off on the test copy);
- the App Links SHA-256 in `ops/legal-site/src/app-links.ts`, still
  `PENDING_PLAY_APP_SIGNING_SHA256`. Join links then open through the
  `io.studafy.app` scheme instead of verified App Links. Fill it after C1.

### (b) Google Play production

Everything in (a), plus the following.

**Production environment.** Production is the shared Frankfurt project
(DL-064).
- **Production apps** (4.5, C11): `studafy-api`, `studafy-worker` and
  `studafy-scanner`, deployed in production mode.
  - `api.studafy.com` has **no DNS record** (2026-10-17).
  - At cutover, stop the two test apps and remove the test accounts and
    synthetic schools.
  - The production cutover scripts are *in progress*.
- **Domain and Cloudflare for the API** (C8, 4.2):
  - the DNS record, the proxy and certificates;
  - WAF and rate rules;
  - then `ORIGIN_REQUIRE_CLOUDFLARE="true"`. It is `"false"` in
    `fly.api.toml`.
- **Real Turnstile keys** for `api.studafy.com` (C9).
- **Production Redis:** a paid Redis Cloud plan with AOF and `noeviction`
  (owner).
- **Production sign-in providers:** Google and Microsoft in the production
  Supabase Auth (C7).
- **Key rotation** before real users (C12, 4.9).

**Store payments, push and email.**
- **Play billing in sandbox** (C6, 3.9). Plus and Max are on sale in the
  store copy (DL-062, `docs/store/listing-copy.md`), but
  `PAY071_BILLING_ENABLED` is `"false"` on the test copy and unset in
  production.
- **Push and email** (C3, C5):
  - Firebase files and the service-account key;
  - a verified Resend domain and key.

**Release.**
- **REL-002 cutover** (D1, 7.3), *in progress*. It must also let a
  production build offer uploads: `allowsRemoteFileUploads` is still false
  for production in `lib/core/runtime_environment.dart`.

**Backups and monitoring.**
- **Backups pointed at production**, a timed restore drill, and an offline
  copy of the backup key (C10, 4.6).
- **Monitoring on production** (4.7):
  - the uptime URL, still the test copy in `ops/alert-relay/wrangler.toml`;
  - an AI spend alert at Together (none exists);
  - Axiom 30-day retention (B7).

**Hands-on check.** The flows on an Android phone, in English and Arabic
(2.9, through the internal-testing build).

**Accepted by the owner, so not blocking:**
- AI on before the Together AI DPA and the DPIA (DL-062). C17 still
  recommends both.
- No PITR on the free plan (DL-064).
- One report reviewer (DL-063, DL-066).

### (c) App Store

Everything in (b) that is not Android-specific, plus the following.

**Apple account and app setup.**
- **Apple Developer Program** active (B11, 5.1). Everything below waits on
  it.
- **App ID `com.studafy.light`** with Sign in with Apple and Push (5.2).
- **Sign in with Apple** (C13, 5.3), required by guideline 4.8 because
  Google sign-in is offered.
  - Today it is `enabled = false` in `supabase/config.toml`.
  - `APPLE_SIGN_IN_ENABLED` is `false` in the development defines.

**iOS release block.** iOS release is still refused, even for TestFlight:
- the Xcode "SEC-001 Release Block" phase is in
  `ios/Runner.xcodeproj/project.pbxproj`;
- ADR-0042 narrowed the block for Android only;
- TestFlight therefore needs D1 (*in progress*) or a similar narrowing for
  iOS.

**Push, products and TestFlight.**
- **APNs key and `GoogleService-Info.plist`** (C14, 5.4). The plist must be
  added to the Runner target.
- **App Store products in sandbox** (C15, 5.6).
- **TestFlight build and one tester** (C16, 5.7).

**Store forms and links.**
- **App Store Connect** (B12):
  - the privacy labels from `docs/store/app-store-privacy-labels.md`;
  - the Education category and an honest age rating;
  - the reviewer accounts (`docs/store/reviewer-access.md`), re-provisioned
    on production.
- **Universal Links:** `APPLE_TEAM_ID` in `ops/legal-site/src/app-links.ts`
  is still `PENDING_APPLE_TEAM_ID`.

**Hands-on check.** The flows on the iPhone with a release build, in
English and Arabic (2.9).

---

## Section I: go-live checklist

| # | Item | Status | Evidence / what is left |
|---|---|---|---|
| I-1 | All work pushed; `main` contains it; CI green on `main` | **Done** 2026-10-16 | No open PRs. CI on `main` head `5021720`: run 38955081697 success. Earlier: PR #20 (`c3c1278`, run 38153948827). Device tests on `main` have passed on both platforms (Android 38610730627, iOS 38604971154; latest 38947039385). Run 38953224997 at `224dd02` was still running (Android passed). One red run on `3c41629` (38942062733) failed while starting the disposable Supabase stack, an infrastructure flake; the next runs are green |
| I-2 | Production Supabase project decided and separated from testing; test data never in production | **Partly** | Decided 2026-10-16 (DL-064, work plan 4.1): production **is** the test project `cyrngoqnhqflzovlybbr`, on the free plan. This departs from "separated" by the owner's decision. Left, at cutover: stop `studafy-api-test` and `studafy-worker-test`, then review and remove the owner's test accounts and synthetic schools, including "Cedar Grove Review School" unless it is kept for store review. The production cutover scripts are *in progress*. 4.1's Done when asks for an ADR; it is recorded as DL-064 instead |
| I-3 | API and worker log in as runtime roles; Redis `rediss://`; database TLS with CA verified | **Partly** | **Test copy, done 2026-10-14** (work plan 2.3, 2.4; owner-run, from the handoff): both apps connect as `studafy_api_runtime` and `studafy_worker_runtime`, Redis Cloud is on TLS in Frankfurt, and the startup log has no `database_privileged_role` or `redis_plaintext_remote`. The CA was verified on the test copy on 2026-10-08 (`DATABASE_CA_CERT`, handoff). **Code:** `packages/config/src/index.ts` (`enforceApiFailClosed`, `enforceWorkerFailClosed`) refuses a plaintext DB, the `postgres` login and a non-`rediss://` or passwordless Redis in production. It does **not** require `DATABASE_CA_CERT`: `docs/deployment/fly-io.md` lists it only as "recommended". **Left:** the production apps (4.5); a paid production Redis (owner); set `DATABASE_CA_CERT` on both production apps |
| I-4 | Domains live behind Cloudflare; `ORIGIN_REQUIRE_CLOUDFLARE=true`; WAF and rate rules for auth and uploads | **Partly** | Decided 2026-10-16 (DL-067, #94). On 2026-10-17, `legal.studafy.com` and `app.studafy.com` resolve to Cloudflare ((Cloudflare proxy address), (Cloudflare proxy address)): `/privacy`, `/terms` and `/delete-account` answer 200, and so does `/.well-known/assetlinks.json`. **`api.studafy.com` has no DNS record** (`curl` fails). `fly.api.toml` has `ORIGIN_REQUIRE_CLOUDFLARE = "false"`, its comment says why, and `CLIENT_IP_SOURCE = "cloudflare"`. There are no WAF or rate rules in the repo. Left: C8 and 4.2 |
| I-5 | Real Turnstile keys; HSTS on (production mode) | **Waiting on owner** (C9) | `fly.api.toml` has `TURNSTILE_ENABLED="true"` and `TURNSTILE_HOSTNAMES="api.studafy.com"`. The config refuses Turnstile without a site key, a secret and a valid hostname. HSTS (`max-age=31536000; includeSubDomains`) is sent whenever `ENVIRONMENT=production` (`apps/api/src/platform/middleware.ts`), so it comes with the production app. The test copy still uses test keys (`TURNSTILE_HOSTNAMES="example.com"`, `fly.test.api.toml`). Left: the owner creates the production Turnstile widget and keys; then the API is deployed (4.5) |
| I-6 | Malware scanner integrated; EICAR test refused in production | **Partly** | Self-hosted ClamAV, so no vendor DPA is needed (#50, #51, 2026-10-14). The test worker uses it. On the test copy, EICAR is refused by the structural check, and ClamAV's own EICAR detection passes its startup self-test (#50 body). Production: `fly.scanner.toml` (#56), and `fly.worker.toml` has `MALWARE_SCANNER_URL="http://studafy-scanner.internal:8080/scan"`. **Left:** deploy `studafy-scanner` and the production worker, then the EICAR and clean-PDF check there (4.4). The production app hides uploads until REL-002 (see the code notes) |
| I-7 | Account deletion and data export complete end to end in production | **Partly** | `ACCOUNT_DELETION_EXECUTOR_ENABLED="true"` and `DATA_EXPORT_EXECUTOR_ENABLED="true"` in `fly.worker.toml` and the test worker. Local end to end 14/14 on 2026-10-11 (work plan 2.1 log). Since then: export v2 (#72), deletion of what accounts left behind (#35), and recent sign-in required (PR-30, `7b7b0db`). **Left:** one synthetic deletion and one export on the production apps after cutover |
| I-8 | DPA and DPIA signed, and AI enabled; or Plus/Max not sold | **Waiting on owner** (C17) | Not met as written. DL-062 (2026-10-16) turns AI on from launch **ahead of** the DPA and DPIA, as an accepted risk: `AI_LESSON_TOOLS_ENABLED="true"` in `fly.api.toml` and `fly.worker.toml`, and Plus and Max are in the store copy. The DPIA is a draft only (`docs/legal/dpia-draft.md`, #57); the questions for counsel are in `docs/legal/questions-for-counsel-2026-10.md`. Safeguards in code: AI only for students in a class, a separate AI consent, names replaced (ADR-0043, #76). `docs/legal/privacy-policy.md` still carries the `TODO(legal)` "OUTSTANDING" comment at line 464; privacy 1.5 is *in progress*. Left: accept Together AI's DPA, and have the DPIA reviewed and signed |
| I-9 | Store products created; purchase, renewal, refund and restore tested on both stores | **Waiting on owner** (C6, C15) | Code: store billing (PAY-071), Play voided purchases and pinned Pub/Sub names (#70). `PAY071_BILLING_ENABLED="false"` on the test copy; it is unset (off) in production, with a comment. No products, testers or server keys exist yet; guides `docs/guides/owner/05-play-billing.md` and `08-app-store-products.md` (#59) |
| I-10 | Sign in with Apple works; identity final; release signing with upload key; INTERNET permission | **Partly** | **Identity: done 2026-10-14** (DL-058): `com.studafy.light` is `applicationId` (`android/app/build.gradle.kts:153`) and the bundle id (pbxproj). **INTERNET: done 2026-10-11** (`16ba19d`): it is in `android/app/src/main/AndroidManifest.xml`, and `aapt dump permissions` listed it on a release bundle before #61 merged (work plan 3.5). **Signing: wired** (#61): `signingConfigs.upload` comes from `STUDAFY_ANDROID_KEY_PROPERTIES`, with no debug fallback, and needs the owner's key (C1). **Apple: waiting** (B11, C13): `[auth.external.apple] enabled = false` in `supabase/config.toml` |
| I-11 | Privacy manifest, store privacy forms, hosted policy and terms, subscription links | **Partly** | **Manifest done** 2026-10-12: `ios/Runner/PrivacyInfo.xcprivacy` is in the Runner target (#36). **Forms drafted, not submitted:** `docs/store/google-play-data-safety.md` (#34) and `docs/store/app-store-privacy-labels.md` (#36); submitting them is B12. **Hosted policy and terms live** on `legal.studafy.com` (#94; 200 on 2026-10-17). **Links:** the study plans and Family+ screens read `STUDAFY_TERMS_URL` and `STUDAFY_PRIVACY_URL`. The development and synthetic define examples point at `legal.studafy.com`, but no production defines file exists yet (`config/` has only the two examples), and the owner's tap-through (B6, 4.3) has not been reported |
| I-12 | Push and email delivered on real devices | **Waiting on owner** (C3, C5, C14) | There is no `google-services.json` or `GoogleService-Info.plist` in the repo; the Gradle plugin applies only when the file exists. `NOTIFICATION_CHANNELS_ENABLED` is unset in `fly.worker.toml`. Test scripts exist: `scripts/send-test-notification.ts` and `scripts/send-test-email.ts` (#70) |
| I-13 | Backups daily with files, off-site copy, PITR, restore drill timed | **Partly** | **Daily with files, restore-checked:** the latest run 38953718872 succeeded. **Off-site: done 2026-10-16:** Cloudflare R2 `studafy-backups`, EU, 30-day lifecycle (#69); run 38896690730 verified it by sha256 read-back. **PITR:** none on the free plan, accepted in DL-064. **Timed drill:** not done. `docs/deployment/backups.md` records only the 2026-09-29 local drill, with no time. **Offline key copy:** not reported. Left: point the backup at production after cutover, a timed drill into a new project, and a USB key copy (4.6, C10) |
| I-14 | Sentry, Axiom and uptime alerts on production; backlog and AI-spend alerts; on-call contact named | **Partly** | **On-call named** 2026-10-16 (DL-066: Yousef, hello@studafy.com). **Backlog alerts:** built (#38), on in `fly.worker.toml` (`QUEUE_ALERTS_ENABLED`), and tested to Telegram from the test worker on 2026-10-13. Safety-report alerts are on (#71). Sentry is scrubbed and tags releases (#38, #52). **Left:** the uptime URL is still `https://studafy-api-test.fly.dev/readyz` (`ops/alert-relay/wrangler.toml:13`); there is no AI-spend alert at the provider (nothing in the repo); Axiom 30-day retention (B7) and the Sentry retention check (owner, `docs/operations/observability-review-2026-10.md`); no dashboards or SLOs |
| I-15 | Capacity re-measured; database sized; pool limits checked | **Partly** | **Re-measured:** #39 (2026-10-12), plus fix rounds #53, #65, #77, #78 and #87, through `docs/capacity/2026-10-17.md`. **Sized:** the free plan (DL-064), against `docs/operations/capacity.md`'s recommendation of at least 4 dedicated vCPUs. The owner accepts that and moves to Pro when needed. **Pool:** `DATABASE_POOL_MAX="10"` in `fly.api.toml` and `fly.worker.toml`. A check of (API machines × 10) + 10 against the free plan's pooler limit is not recorded. Left: record that check before cutover |
| I-16 | Unused secrets removed; credentials rotated; stray Fly app destroyed | **Partly** | **Done 2026-10-14** (work plan 2.5, owner): `studafy-api`'s 43 secrets are removed, `studafy` is destroyed, there are per-app deploy tokens, and AWS is dropped. The `postgres` password was reset (2.3). The exposed Fly token was revoked on 2026-10-16 (handoff). **Left:** rotate the service-role key and signing keys before real users (4.9, C12) |
| I-17 | A person has gone through teacher, student and parent flows on iPhone and Android, in English and Arabic | **Waiting on owner** (B5, 2.9) | A profile build from `main` is on the owner's iPhone 14 Pro (handoff, 2026-10-16). No results have been reported. Android needs the internal-testing build (3.7). Automated device tests pass in CI on both platforms, but they do not replace this |
| I-18 | Moderation owner and process named | **Done** 2026-10-16 | DL-063 and DL-066: the owner is the one report reviewer, in single-reviewer mode (migration `202610160041`). The process is in `docs/security/safe043-operator-runbook.md`. In-app review under Account → Safety reports (#97). Telegram alert per report (#71). Owner set-up still to confirm under PR-28 |
| I-19 | SEC-001 guards removed in one reviewed REL-002 change | **Partly** | **Narrowed 2026-10-16** (#61, ADR-0042): an Android release only with `APP_ENV=development`. Still in place: the iOS Xcode "SEC-001 Release Block"; `blocksApplicationStartup` for production; `allowsRemoteFileUploads` false in production (`lib/core/runtime_environment.dart`). D1 / REL-002 is *in progress* |

## Issue register (PR-01 to PR-30)

| Issue | Status | Evidence / what is left |
|---|---|---|
| PR-01 Release builds blocked | **Partly** | See I-19. Android internal testing is unblocked (#61); iOS and production are still blocked. REL-002 (D1) is *in progress* |
| PR-02 No INTERNET permission | **Done** 2026-10-11 | `16ba19d`, pinned by a test. Release-bundle `aapt` check run before #61 merged (work plan 3.5) |
| PR-03 Debug-key signing | **Waiting on owner** (C1) | The code side is done (#61): release signing uses the upload key or fails. Needs the owner's keystore and Play App Signing |
| PR-04 App identity | **Done** 2026-10-14 | DL-058: `com.studafy.light` on both platforms, link scheme `io.studafy.app`. App links moved to `app.studafy.com` (#94, DL-067) |
| PR-05 Sign in with Apple off | **Waiting on owner** (B11, C13) | `enabled = false` in `supabase/config.toml`. Waits for the Apple Developer Program |
| PR-06 No malware scanner | **Partly** | See I-6. Self-hosted ClamAV is on the test copy; production scanner not deployed |
| PR-07 AI legally blocked | **Waiting on owner** (C17) | See I-8. Overridden by DL-062 (accepted risk). The DPA and DPIA are still open, and the privacy policy's `TODO(legal)` remains (1.5 *in progress*) |
| PR-08 Production data path | **Partly** | See I-2 and I-3. Done on the test copy 2026-10-14; production apps, a paid Redis and cutover hygiene are left |
| PR-09 Domains and Cloudflare | **Partly** | See I-4. Legal and app subdomains live behind Cloudflare; `api.studafy.com` has no DNS; origin lock off; no WAF rules |
| PR-10 Deletion and export never complete | **Partly** | See I-7. Executors on and tested locally (14/14) and on the test worker; the production run is left |
| PR-11 Payments never exercised | **Waiting on owner** (C6, C15) | See I-9 |
| PR-12 Push and email | **Waiting on owner** (C3, C5, C14) | See I-12 |
| PR-13 Work not pushed | **Done** 2026-10-11 | Work plan 1.1 (`21afe7d`) and 1.3 (#20). Today `main` has everything and no PR is open |
| PR-14 CI Flutter job fails | **Done** 2026-10-11 | Work plan 1.2: runs 38151306142 and 38152183833. Green on `main` since (38955081697) |
| PR-15 Production timeout | **Done** 2026-10-11 | `API_REQUEST_TIMEOUT_MS = "20000"` in `fly.api.toml` (checked 2026-10-17), pinned by `scripts/fly-config.test.ts` |
| PR-16 Secrets and stray infrastructure | **Partly** | See I-16. Cleanup done 2026-10-14; key rotation (4.9) is left |
| PR-17 Backup depth | **Partly** | See I-13. Off-site done 2026-10-16; PITR is not available on the free plan (DL-064); the timed drill and offline key copy are left |
| PR-18 Store submission prerequisites | **Partly** | See I-11. Manifest done; policy and terms hosted; forms drafted, not submitted; production defines and the tap-through are left |
| PR-19 Capacity | **Partly** | See I-15. Re-measured (work plan 4.8 ticked); the pool check against the free plan is not recorded |
| PR-20 Lesson-save rejection | **Waiting on owner** (2.9) | Recurred 2026-10-15. The cause was traced to a scan-refused attachment, fixed by `ATTACHMENT_REFUSED` naming the file (#63) and the same for hand-ins and messages (#74). Both are on the test copy since 2026-10-16. Left: a refused-file save on the phone that names the file (work plan 2.8) |
| PR-21 UX inconsistencies | **Done** 2026-10-11 | `76b0c1e` (work plan 2.6): migration `202610110002` and widget tests |
| PR-22 Test coverage gaps | **Done** 2026-10-15 | #40, #41 and #42 (accessibility checks, device tests in CI), then #60 and #67. Work plan 7.1 |
| PR-23 Notebooks not durable | **Done** 2026-10-16 | #78: notebooks are written by the worker from a queue (`docs/capacity/2026-10-16-notebooks.md`). This goes beyond the 2026-10-11 resume (`67fd09a`) |
| PR-24 Lower-severity security items | **Partly** (post-launch by plan) | **Done:** the log shipper is pinned to a digest (`fly.log-shipper.toml:21`, #52). **Still open:** <br>• DNS rebinding is a documented known limit in `packages/infrastructure/src/material/link.ts`; <br>• no minimum password length in `supabase/config.toml`; <br>• the test copy's Turnstile uses test keys; <br>• the free AI replay and the per-denial write |
| PR-25 Monitoring incomplete | **Partly** | See I-14 |
| PR-26 Stale documentation | **Done** 2026-10-12 | #43. New drift since then is listed under "Where a doc and the code disagree" below |
| PR-27 Identity linking | **Not started** | Post-launch by plan |
| PR-28 Moderation operations | **Waiting on owner** | Owner, reviewer, process and in-app tool exist (I-18). Two owner set-up steps are unconfirmed (handoff, night 2026-10-16): <br>1. add himself as the only row in `public.platform_operators` (single-reviewer mode needs exactly one); <br>2. turn on two-factor sign-in |
| PR-29 Dependency drift | **Not started** | Post-launch by plan |
| PR-30 Recent sign-in not enforced | **Done** 2026-10-11 | `7b7b0db`: `RECENT_SIGN_IN_REQUIRED` (403) in `apps/api/src/auth/routes.ts`; checked with real local tokens (work plan 2.10 log). Owner's phone confirmation is part of 2.9 |

## Where a doc and the code disagree

Found while verifying. None blocks internal testing.

1. **ADR-0042 and DL-059 still say "Proposed — needs the owner's
   approval"**, but #61 is merged and work plan 3.5 is ticked. The owner
   approved by merging, so update both statuses to Accepted.
2. **AI key timing.** `docs/deployment/fly-io.md` (production secrets
   table) says to set `AI_API_KEY` "never before the DPA and DPIA (C17)".
   DL-062 and `fly.api.toml` turn AI on from launch, ahead of both. The
   checklist should follow DL-062.
3. **Uploads in the production app.** `lib/core/runtime_environment.dart`
   keeps `allowsRemoteFileUploads` false in production, because "none [no
   malware provider] is contracted". The self-hosted scanner (#50,
   `fly.scanner.toml`) now meets the worker's production rule, so the
   comment is stale. REL-002 must flip it, or a production build offers no
   uploads.
4. **Database CA.** The readiness check wants "database TLS with CA
   verified", but production config validation enforces TLS only, not
   `DATABASE_CA_CERT`. Set it on both production apps; the deploy
   checklist marks it only "recommended".
5. **Work plan 4.1** is ticked, but its Done when says "recorded in an
   ADR". It is recorded as DL-064, which the progress note says.
6. **Privacy policy.** `docs/legal/privacy-policy.md:464` still has the
   `TODO(legal)` "MUST BE RESOLVED BEFORE THESE TOOLS ARE OFFERED TO
   CHILDREN", while production turns AI on. Privacy 1.5 is *in progress*.
7. **Uptime alert.** `ops/alert-relay/wrangler.toml` watches the test copy;
   switch it with the production cutover.
