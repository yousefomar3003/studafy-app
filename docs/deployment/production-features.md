# Production features

Every feature of the app and server, its state in production, what turns it
on, and how to check it after the production deploy
(`docs/deployment/production-cutover.md`). Production means `api.studafy.com`
(`fly.api.toml`, `fly.worker.toml`, `fly.scanner.toml`) on the Frankfurt
Supabase project (DL-064), and store builds made under the production defines
contract (`lib/core/production_contract.dart`, ADR-0044).

The rule since DL-070 (the owner, 2026-10-17: "make sure all the features in
the app are enabled and will work on production"): every feature is on in
production unless a recorded decision keeps it off. A feature that needs a key
the owner has not created yet is switched on already, and starts by itself
when its key is set. Until then the apps start normally and the feature is
hidden or says it is not set up. Nothing crashes.

States:

- **On**: works from the first production deploy, once the required secrets
  in the cutover doc are set.
- **On when key X is set**: the switch is already on. Setting the secret or
  define (and deploying, or rebuilding the app) is the only step left.
- **Off by decision DL-xx**: kept off by a recorded decision. Turning it on
  is a reviewed change with the owner's "go".

## Features

| Feature | Production | What enables it | How to verify after the deploy |
|---|---|---|---|
| Sign-in: email, Google, Microsoft | On | Supabase Auth providers on the production project (C7); `SUPABASE_URL` and the publishable key in the build | Sign in with each on a production build; `/v1/me` returns the profile |
| Sign in with Apple (iOS) | On when the Apple keys are set | `APPLE_SIGN_IN_ENABLED=true` (required for iOS by the contract) plus the Apple provider on the Supabase project (Apple Developer account, C13). Without the provider the button shows "Something went wrong", never a crash; Android never shows it | Tap "Sign in with Apple" on an iPhone build and reach the home screen |
| Bot check (Turnstile) | Required key | `TURNSTILE_ENABLED = "true"`, `TURNSTILE_HOSTNAMES = "api.studafy.com"` (`fly.api.toml`) and the secrets `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET` (C9). **The API refuses to start without them**; the build contract requires `TURNSTILE_ENABLED=true` | `https://api.studafy.com/auth/bot-check` loads the widget; linking a child completes the check |
| Classes, joining by code or link, schools, staff, enrolment, invitations | On | `API041_CLASSES_ENABLED`, `API042_*` (on by default; not set in the Fly files) | A teacher creates a class; a student joins with its code |
| Lessons, assignments, hand-ins, grades, attendance, wellbeing notes | On | `API041_CONTENT/ASSIGNMENTS/GRADES/ATTENDANCE/WELLBEING_ENABLED` (on by default) | Publish a lesson and an assignment; a student hands in; release a grade |
| Online exams and the question builder | On | `API041_ASSESSMENTS_ENABLED` (on by default) | Create an online exam with an image question; a student takes it; release answers |
| Announcements | On | `API042_ANNOUNCEMENTS_ENABLED` (on by default) | A teacher posts one; a parent and a student see it |
| Messaging | On (DL-063) | `MESSAGING_ENABLED = "true"` (`fly.api.toml`), and each school's own switch (on for new schools) | A parent messages a teacher; report and block work |
| In-app notifications | On | `OPS061_NOTIFICATIONS_ENABLED = "true"` (`fly.worker.toml`) | A grade release appears in the student's inbox within a minute |
| **File uploads and downloads** (attachments, hand-in files, question images, voice notes, notebook and helper photos) | **On (DL-070)** | App: `allowsRemoteFileUploads` is true in production. API: `FILE050_NEW_INTENTS_ENABLED`, `FILE051_PUBLISH_ENABLED`, `FILE051_DELIVERY_ENABLED` = `"true"`, `FILE051_DELIVERY_PUBLIC_BASE_URL = "https://api.studafy.com"`. Worker: `FILE051_SCAN_ENABLED`, `FILE050_CLEANUP_ENABLED`, `FILE051_RETENTION_ENABLED` = `"true"`, `MALWARE_SCANNER_URL` = the private `studafy-scanner`. Secrets: `SCANNER_API_KEY` (= the worker's `MALWARE_SCANNER_API_KEY`), `FILE051_DELIVERY_SIGNING_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. Kill switch: set the API's `FILE050_NEW_INTENTS_ENABLED` to `"false"` and redeploy | Cutover step 9: an EICAR test file is refused and a clean PDF passes. Then attach a photo to an assignment and open it as a student |
| AI study tools: helper, lesson reading, notebooks, quizzes, flashcards, whiteboard notes | On (DL-062) | `AI_LESSON_TOOLS_ENABLED`, `AI_MATERIAL_INDEX_ENABLED` = `"true"`, `AI_BASE_URL`, `AI_MODEL`; secret `AI_API_KEY` (required by the cutover script). Each student consents first (ADR-0043). Without the key the API starts and tells the app the tools are off (`available: []`, `aiEnabled: false`), so they are hidden | `/v1/me/study-plan` for a student in a class lists the tools and `aiEnabled: true`; ask the helper a question |
| Student Helper tab (five tabs: Today, Lessons, Work, Helper, Messages) | On (DL-070) | Shown whenever AI is on server-wide (`aiEnabled`). A student in no class sees "Join a class to use the study helper"; the server still refuses them the tools. Hidden only when AI is off for everyone | A student in a class sees five tabs; one who has left every class sees the Helper tab's join message |
| Free plan allowance (40k tokens a week) | On | Database (`private.study_plan`); needs no billing | A free student's helper shows the weekly allowance |
| Paid plans: Studafy Plus and Max, Family+ (buying, restoring) | On when the store keys are set (DL-070) | `PAY071_BILLING_ENABLED = "true"`, `PAY071_ENVIRONMENT = "production"` (both Fly files), `PAY071_RECONCILIATION_ENABLED = "true"` (worker). Runs once one store's set is complete: App Store `APPLE_BUNDLE_ID`, `APPLE_ENVIRONMENT`, `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_ROOT_CERTIFICATES_BASE64` (C15); Play `GOOGLE_PACKAGE_NAME`, `GOOGLE_SERVICE_ACCOUNT_JSON`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PUBSUB_AUDIENCE` (C6). Until then no billing route is mounted, and the plan pages say payments are not set up; the worker logs `billing_waiting_for_store_keys` | The worker's start-up line shows `pay071.billingActive: true`; buy Plus in the store's sandbox, then restore on a second device |
| Family+ insights for a parent | On | Database entitlement (a purchase, once billing runs, or a grant) | A parent with Family+ opens a child's insights |
| Guardian links and managed child accounts, account switching | On | `API042_FAMILY_ENABLED` (on by default) | A parent creates a child account and switches to it |
| Push notifications | On when the Firebase keys are set | Worker: `NOTIFICATION_CHANNELS_ENABLED = "true"` (already set) plus the secrets `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_JSON` (C3). App: the `FIREBASE_*` defines in `config/dart-defines.production.json` turn push on by themselves (or the native files plus `PUSH_ENABLED=true`). Without them the app skips push; in-app notifications are unaffected. No push deliveries pile up meanwhile | `scripts/send-test-notification.ts` against an account signed in on a phone (`docs/deployment/push-notifications.md`) |
| Email notifications and notices | On when the Resend key is set | Worker: `NOTIFICATION_CHANNELS_ENABLED = "true"` (already set) plus the secrets `RESEND_API_KEY` and `EMAIL_FROM_ADDRESS` (C5). Email goes only to people who turned it on for a category. No email deliveries pile up before the key | `scripts/send-test-email.ts` (`docs/guides/owner/04-resend.md`) |
| Account deletion and data export | On | `ACCOUNT_DELETION_EXECUTOR_ENABLED`, `DATA_EXPORT_EXECUTOR_ENABLED` = `"true"` (`fly.worker.toml`); `API042_ACCOUNT_RIGHTS_ENABLED` | Request an export and download it; request deletion of a test account and cancel it |
| Safety: reports, blocks, moderation, school content controls | On | `SAFE043_*` (on by default) | Report a message; block a person |
| Safety review for operators | On | The owner as the platform operator on the production database (DL-063), with MFA; the Account screen's "Safety review" row appears for operators only | Open Safety review as the operator and read a test report |
| Safety report alerts and queue alerts (Telegram) | On | `REPORT_ALERTS_ENABLED`, `QUEUE_ALERTS_ENABLED` = `"true"`; secrets `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`. The worker refuses to start without them | A test report reaches the Telegram chat (`docs/deployment/queue-alerts.md`) |
| Meetings: upcoming list and pasted Meet links | On | `API042_MEETINGS_ENABLED` (on by default); a teacher pastes a Meet link into an announcement | A shared link opens Google Meet |
| Meeting creation through Google Workspace | Off by decision DL-065 | `MEETINGS_PROCESSOR_ENABLED` stays unset (pinned). The app has no create-meeting control | Not applicable |
| Retention purge (DL-057) | Off by decision (launch plan D3) | `RETENTION_SCHEDULE_ENABLED = "false"` until the store release with consent version 2026-10-14 is live; then the owner's "go" and a one-word change | Not applicable |
| AI grading | Removed (ADR-0026) | `allowsAiGrading` is a hard-false tripwire | Not applicable |
| Cloudflare-only origin | Off until the proxy is live (C8) | `ORIGIN_REQUIRE_CLOUDFLARE = "true"` after `api.studafy.com` is proxied (cutover step 10) | `studafy-api.fly.dev` is refused, `api.studafy.com` answers |
| Rate limits, database housekeeping, file cleanup | On | `RATE_LIMIT_ENABLED` (on by default) with `RATE_LIMIT_HMAC_SIGNING_KEY`; `DB_HOUSEKEEPING_ENABLED` | Repeated failed sign-ins are slowed down |
| Crash reports | On (server); on when the DSN is set (app) | Secrets `SENTRY_DSN` (API, worker). App: the `SENTRY_DSN` define, empty means off | Sentry "Send Test Notification"; a test crash from a build with the DSN |

The API's `POST /v1/auth/identities/link` refuses every request (provider
identity verification is not wired). The app does not call it, so no
feature depends on it.

## After the deploy

Run these on production after cutover step 8, with a production build from
`scripts/release/build-store.sh`:

1. `fly logs --app studafy-worker`: the start-up line lists the queues.
   `channel_delivery_configured` shows which of email and push have keys.
   `billing_waiting_for_store_keys` is expected until a store's keys are
   set.
2. `fly logs --app studafy-api`: the start-up line's `pay071.billingActive`
   says whether billing routes are mounted.
3. Uploads: cutover step 9 (EICAR refused, clean PDF passes), then a photo on
   an assignment opened by a student.
4. AI: a student in a class asks the helper a question; a student in no class
   sees the Helper tab's join message.
5. Messaging, notifications, export and deletion: the checks in the table.
6. For each key set later (Firebase, Resend, App Store, Play): import the
   secret (`fly secrets import --app <app> --stage`), redeploy that app, and
   run that row's check.
