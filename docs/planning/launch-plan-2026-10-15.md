# Launch plan: Android and iOS (2026-10-15)

Everything left before Studafy is in the Play Store and the App Store with
real students, split by who can do it. The numbers in brackets point to the
detailed items in [`launch-work-plan.md`](launch-work-plan.md).

**Where things stand.** The app and server are feature-complete and running
on the Fly test copy:

- the security items (restricted database logins, TLS Redis, cleanup) are
  done;
- the app ID is `com.studafy.light`;
- privacy policy 1.4 is live in both languages, with consent version
  `2026-10-14`;
- the retention schedule is built and switched off;
- the test copy has a self-hosted malware scanner;
- uploads work on the phone, including PDFs made with ReportLab (PR #55).

**Open PRs:** #52 (observability), #53 (capacity fixes), #54 (handoff and
this plan), #55 (PDF fix and scan messages).

**The fastest route to a store:** A1, then B4–B6 and C1–C3, while Claude
does A3 and C4. That gives Android internal testing on the test copy
without waiting for production or Apple.

---

## A. Claude can do these without you

Most only need a merge or a "go" at the end, because a change to Fly or a
merge is yours to approve.

| # | Task | Ends with | Status |
|---|---|---|---|
| A1 | After you merge #52–#55: back up, apply #53's migrations to the test database, redeploy the test worker from `main` and the log shipper | Your "go" for each Fly step | **Done 2026-10-16**: #52–#78 merged; backup, 19 migrations, test API, worker and log shipper deployed |
| A2 | Tick the finished launch-plan items (capacity 4.8, privacy labels draft 5.5, tests 7.1, docs 7.2) | — | **Done 2026-10-15** (4.8, 5.5, 7.1, 7.2 ticked) |
| A3 | Allow an Android release build for internal testing only, production mode still off (3.5) | A PR for your approval | **Done**: #61 merged (ADR-0042); waits for your upload key (C1) |
| A4 | Store listing copy in English and Arabic (short and full description, "what's new"), and screenshots from the simulator for each role | Your review | **Done**: copy and iPhone set (#64), decisions (#80); Android set in progress |
| A5 | A draft DPIA (children's data and AI) for you and the lawyers (6.2) | Your review | **Done**: draft in `docs/legal/dpia-draft.md` (#57); questions for counsel in `docs/legal/questions-for-counsel-2026-10.md` |
| A6 | Production configs ready to deploy: `fly.scanner.toml` (a copy of the test scanner), and checks of `fly.api.toml` and `fly.worker.toml` against the production config rules (runtime roles, TLS Redis, executors on, `RETENTION_SCHEDULE_ENABLED` off) | A PR | **Done**: #56 |
| A7 | Step-by-step guides for your parts: upload keystore (3.3), Play Console (3.6), Firebase (3.8, 5.4), Resend, sign-in providers on a new Supabase project, Apple (5.1–5.6) | A doc | **Done**: `docs/guides/owner/` (#59) |
| A8 | Capacity, next round: the lessons and conversations lists a page at a time (about 26% of database time now), with the zero-difference proof | A PR | **Done**: fixes 4–6 (#65, #77) and notebooks on the worker (#78); `study_lesson` in progress |
| A9 | Watch for the lesson-save rejection (2.8) in the logs, and fix it if it recurs | — | **Fixed**: recurred 2026-10-15; #63 and #74 deployed 2026-10-16 |
| A10 | Optional: commit the synthetic school seed and run the exam and coursework device tests in CI | A PR | **Done**: #60 |

## B. Only you can do these

Decisions, accounts, money and signatures.

| # | Task | Why it matters |
|---|---|---|
| B1 | ~~Decide AI at launch~~ **Decided 2026-10-16 (DL-062): AI on from launch**, before the DPA and DPIA. Still recommended: accept Together AI's DPA and have the DPIA draft reviewed (6.1, 6.2) | Accepted risk recorded in DL-062 |
| B2 | ~~Decide the production database~~ **Decided 2026-10-16 (DL-064): the existing Frankfurt project `cyrngoqnhqflzovlybbr`, free plan until scale needs Pro.** At cutover: stop `studafy-api-test` and `studafy-worker-test`, and remove your test accounts (4.1) | Test and production share the database; the R2 backups stand in for Supabase's |
| B3 | ~~Decide domains~~ **Decided 2026-10-16 (DL-067):** `api.studafy.com`, app links `app.studafy.com`, legal pages `legal.studafy.com`, email hello@studafy.com; DNS on Cloudflare (4.2) | The store listings and release builds need final URLs |
| B4 | ~~Merge PRs #52, #53, #54, #55~~ **Done 2026-10-16** (with #56–#82) | Unblocked A1 |
| B5 | Hands-on check on the phone as teacher, student and parent, in English and Arabic: a lesson with Word and PDF files, a homework hand-in with a photo, opening a student's file, an online exam end to end (2.9) | The last proof before testers |
| B6 | Tap Terms and Privacy on the Study plans screen (4.3); check one real crash from a test build in Sentry shows the user as "anonymous" (#52) | Closes 4.3 and the crash-privacy fix |
| B7 | Set the Axiom dataset retention to 30 days | The privacy policy says 30 days |
| B8 | ~~Decide whether to launch with meeting invitations~~ **Decided 2026-10-16 (DL-065): no meeting creation at launch**; `MEETINGS_PROCESSOR_ENABLED` stays off; teachers can paste a Meet link into an announcement | No attendee emails go to Google |
| B9 | ~~Name the owners~~ **Decided 2026-10-16 (DL-066): all five roles are Yousef (owner), hello@studafy.com.** Messaging launches with you as the one report reviewer, in single-reviewer mode (DL-063); name a second reviewer when you can (6.4) | Store reviewers and schools ask |
| B10 | Lawyers: retention for safeguarding notes, school-wide announcements, other notifications and roster rows with no account | Open questions from the retention PR |
| B11 | Apple: wait for the Developer account, then register `com.studafy.light` with Sign in with Apple and Push Notifications (5.1–5.2) | Unblocks all of iOS |
| B12 | Store listings: Play Console (Families policy, content rating, Data safety from `docs/store/google-play-data-safety.md`, privacy and deletion links); App Store Connect (Education category, honest age rating, not Kids; privacy labels from `docs/store/app-store-privacy-labels.md`) (3.6, 5.5) | Required to publish |

## C. You start, Claude finishes

You create the account or key and give Claude the **file path**, never the
contents, in chat. Claude wires it in and tests it.

| # | You | Claude |
|---|---|---|
| C1 | Create the Android **upload keystore** and keep it and its password backed up outside the repo; turn on Play App Signing (3.3) | Sign release builds with it |
| C2 | Add the **release SHA-1** (from Play App Signing) to the Android OAuth client in Google Cloud (3.4) | Check Google sign-in in the release build |
| C3 | **Firebase:** a project with Android and iOS apps (`com.studafy.light`); `google-services.json`, `GoogleService-Info.plist` and the service-account key (3.8; runbook `docs/deployment/push-notifications.md`) | Add the files, set the worker's FCM secrets, build with `PUSH_ENABLED=true`, send a test push |
| C4 | Upload the internal-testing build Claude makes to Play Console; install it with one tester (3.7) | Build the release bundle (after A3 and C1) |
| C5 | **Resend:** a verified sending domain, API key and sender address | Set them on the worker; email notifications and the inactive-account warning by email |
| C6 | **Play billing:** products `studafy_plus_monthly`, `studafy_max_monthly`, `studafy_family_plus_monthly`, `studafy_family_plus_8_monthly`; license testers; Pub/Sub topic; service account (3.9) | Wire it and test buy, renew, cancel, refund and restore |
| C7 | **Production Supabase project** (B2: the existing Frankfurt project, DL-064), and Google, Microsoft and Apple sign-in set up in it | Apply every migration, set the runtime roles, point the production apps at it |
| C8 | **DNS** for the domains (after B3) | Cloudflare proxy, certificates, refuse direct `*.fly.dev`, legal pages on the domain, URLs in release builds (4.2, 4.3) |
| C9 | **Real Turnstile keys** for the production domain | Set them on the production API |
| C10 | **Backup storage** for production (S3 or similar), and a second offline copy of the backup key (4.6) | Point the daily backup at production; a timed restore drill |
| C11 | Approve each production Fly step | Deploy `studafy-api`, `studafy-worker` and `studafy-scanner` in production mode; alerts for uptime, backlog and AI spend (4.4, 4.5, 4.7) |
| C12 | Approve the key rotation (4.9) | Rotate the database password, service-role key and signing keys; old values stop working |
| C13 | **Sign in with Apple:** Service ID and key (5.3) | Add them to Supabase, turn on `APPLE_SIGN_IN_ENABLED`, test on a device |
| C14 | **APNs key** (`.p8`) uploaded to Firebase with its Key ID and Team ID (5.4) | iOS push, tested with the app open and closed |
| C15 | **App Store products** in App Store Connect (5.6) | Wire and test them in sandbox |
| C16 | Upload the TestFlight build Claude makes; install it with one tester (5.7) | Build the signed iOS release |
| C17 | Accept Together AI's DPA; have the DPIA reviewed (DL-062 turned AI on ahead of them) | AI is already on in the production config (DL-062) |

## D. Launch day (both)

| # | Task | Who |
|---|---|---|
| D1 | One reviewed change that removes the remaining release blocks (SEC-001), only after A–C (7.3) | Claude, approved by you |
| D2 | The go-live checklist, every item ticked with evidence (7.4) | Claude and you |
| D3 | After the store release carrying consent version `2026-10-14`: turn on the production retention purge (`RETENTION_SCHEDULE_ENABLED = "true"` in `fly.worker.toml`) | Claude, with your "go" |

## Order

1. **This week:** B4–B7 and A1–A4. You do C1–C3; Claude does A3 and C4.
   Android internal testing starts on the test copy.
2. **Decisions:** B1, B2, B3, B8 and B9, all decided 2026-10-16 (DL-062
   to DL-067). Production is built from them.
3. **Production:** C5–C12. Then point the release builds at production.
4. **iOS, when Apple approves:** B11, then C13–C16.
5. **Store listings and launch:** B12, then D1–D3.
