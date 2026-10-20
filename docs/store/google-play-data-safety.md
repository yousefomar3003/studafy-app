# Google Play Data safety answers

Launch plan item 3.6. Drafted 2026-10-11 from the code on `main`. Every
answer below cites the file it comes from. Re-check this document whenever a
dependency, permission, processor or data flow changes, because Google compares
the form with how the app actually behaves (`docs/planning/instructions.md`
§24.3).

The answers describe the **release build as configured for launch**:
`fly.api.toml` and `fly.worker.toml`, and the app with `PUSH_ENABLED=true` and
a `SENTRY_DSN`. Where a feature is switched off at launch but its data type
would be collected once it is on, the answer still declares it and says so.
That way the form doesn't have to be resubmitted the day the feature is
switched on.

The form must stay consistent with:
- the App Store labels in `docs/store/app-store-privacy-labels.md` (item 5.5);
- the privacy policy in `docs/legal/privacy-policy.md` (item 4.3).

---

## Needs Yousef's decision

**Decided 2026-10-13** (DL-056):
- **Ages:** declare the real student ages, under-13s included (school age 5 to 17), plus adults. Families policy applies (item 3).
- **AI:** off for real students until the Together AI DPA and the DPIA are signed. Leave `AI_API_KEY` unset in production until then (item 2). **Superseded 2026-10-16 by DL-062: AI is on from launch**, for students in a class only, after a separate AI consent (ADR-0043). The DPA and the DPIA are still not signed (item 2).
- **Production database size:** deferred until the pilot's numbers are known.

The items below remain open unless marked.

These answers can't be settled from the code alone. Each one says what this
draft assumes until you decide.

1. **Malware scanner vendor.** *Resolved: there is no vendor.* Files are scanned by ClamAV on our own Fly machines in Frankfurt, on the private network (`fly.scanner.toml`, `infra/scanner/`; privacy policy 1.5 §7.2). No file goes to a third party for scanning, so nothing about scanning is "shared".
   - **Why it mattered:** uploaded files are sent to the scanner (`packages/infrastructure/src/fileScanner.ts`), and a production worker won't start without it (`packages/config/src/index.ts`, the `FILE051_SCAN_ENABLED` checks).
2. **AI provider data processing agreement (DPA) and DPIA** (ADR-0037).
   - **What is sent to Together AI:** questions, chat history, class grade, language, lesson text, student photos, and page images of teacher files (`packages/infrastructure/src/studyAssistant.ts`, `packages/domain/src/study/grounding.ts`, `apps/worker/src/processors/materialIndex.ts`).
   - **What is not sent:** names Studafy knows are replaced with `[student]`, `[classmate]`, `[teacher]` or `[parent]` in all text (ADR-0043, `packages/domain/src/study/nameRedaction.ts`); emails, links and long numbers are removed. **Photos and scanned pages are sent as they are.**
   - **Who can use it:** students in a class who gave the separate AI consent (a parent's, for a managed child), and no one else (ADR-0043, `private.ai_access`).
   - **Assumed:** a service provider under a DPA, and AI chat content not "processed ephemerally", because Together's retention is not confirmed in writing.
   - **State on 2026-10-17:** AI is on from launch (DL-062) and **the DPA is not accepted yet**. Privacy policy 1.5 §6 and §8 say publicly that the agreement is not yet in place. Accept Together AI's DPA before submitting this form, or the "service provider" assumption (and "Shared: No") does not hold for AI data.
3. **Target audience and Families policy.**
   - Students are children, so Families policy applies (`docs/planning/instructions.md` §24.2). Choose the age bands for the Target audience page. There is no age gate in the app (`docs/governance/decision-log.md` DL-037).
   - **Assumed:** you will declare the real student ages, including under 13.
4. **Supabase Auth and raw IP addresses.**
   - Our own tables hold only keyed hashes of IP addresses (`auth_security_events.ip_hash`; `apps/api/src/platform/middleware.ts`). Supabase Auth itself normally keeps raw IPs in `auth.audit_log_entries` and `auth.sessions`, and that can't be seen from the repo.
   - **Assumed:** IPs are used only for security, which is not a declared location type. Confirm on the hosted project, and set a retention period if you can.
5. **The Sentry setting "Prevent Storing of IP Addresses"** (`docs/deployment/fly-io.md`). It's a dashboard setting; turn it on before release. The answers assume it is on.
6. **Wellbeing notes.**
   - Teachers record strengths, notes and concerns about a student (`lib/features/academic/presentation/create_wellbeing_page.dart`).
   - **Assumed:** declared as "Other user-generated content". If schools will record medical or health matters there, declare "Health info" as well.
7. **Retention periods** for files, AI outputs and audit records are not set yet (`apps/worker/src/processors/retentionSweep.ts`; ADR-0008). The form doesn't ask for periods, but the privacy policy has to state them. *Since DL-057 and DL-060 the policy (1.5, §10) states them, helper photos 30 days included; the purges run once `RETENTION_SCHEDULE_ENABLED` is on.*
8. **Account deletion gaps.** These are being fixed in item 3.6b, before this form is submitted. Today the deletion run leaves behind:
   - the child's name on class rosters;
   - notebooks, AI outputs and usage records;
   - gender;
   - uploaded files.

   (Source: `apps/worker/src/processors/accountDeletion.ts`, `supabase/migrations/202609190008_account_deletion_executor.sql`.) The deletion answers below describe the behaviour **after 3.6b**.
9. **Web deletion URL.** Published by item 4.3 at
   `https://legal.studafy.com/delete-account` (DL-067; the old
   `studafy-legal.studafy.workers.dev` address still answers).

---

## Section 1: Data collection and security

| Question | Answer | Evidence |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Sign-in, profiles, class work and messages, all listed below. Answering "no" while users sign in is an automatic rejection (`docs/planning/instructions.md` §24.3). |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | See the encryption notes below this table. |
| Which of the following methods of account creation does your app support? | **Username and password: no. OAuth: yes** (Google, Microsoft, Apple). **Other: yes**, a parent creates a managed child account without an email. | `lib/features/session/data/api_session_repository.dart:138-193`; ADR-0031; `lib/app/account/account_switching.dart` |
| Delete account URL | `https://legal.studafy.com/delete-account` (item 4.3) | Decision 9 |
| Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account? | **No** | There is no partial-deletion request flow. People can delete their own notebook notes and highlights in the app, but there is no general "delete my data" request short of deleting the account. |

**Encryption in transit:**
- **Server:** the API is served only over HTTPS (`fly.api.toml:47` `force_https = true`) and sends HSTS in production (`apps/api/src/platform/middleware.ts:76-80`).
- **App:** Android blocks cleartext by default at the app's target SDK, and the app adds no cleartext exception (`android/app/src/main/AndroidManifest.xml`). iOS ATS allows only local networking for development (`ios/Runner/Info.plist`).
- **Uploads:** they refuse non-HTTPS signed URLs (`lib/features/files/data/signed_upload_transport.dart:26`).
- **Backend connections:** database connections use TLS (`packages/database/src/index.ts`). Production requires `rediss://` (`packages/config/src/index.ts`). The AI client refuses non-HTTPS endpoints (`packages/infrastructure/src/studyAssistant.ts`).

**Deletion mechanism (for the "users can request deletion" answer):**
- **In the app:** Account → Account security → Delete account (`lib/app/account_hub_page.dart:374-395`, `lib/features/account/presentation/delete_account_page.dart`). It calls `POST /v1/account/deletion-request` after a fresh sign-in.
- **Grace period:** 14 days, during which it can be cancelled (`AUTH_DELETION_GRACE_DAYS`; `lib/core/account_lifecycle.dart`). After that, the worker executes it (`ACCOUNT_DELETION_EXECUTOR_ENABLED = "true"` in `fly.worker.toml`).
- **What is kept on purpose:** grades, attendance, messages already delivered to others, audit records and the payment ledger. These are school records, other people's copies, and legal obligations (`docs/legal/privacy-policy.md` §9). Play allows data to be kept for legitimate reasons such as legal obligations, and the policy has to say so.

---

## Section 2: Data types

Terms used in the tables:
- **Collected** means sent off the device to Studafy or to a service provider acting for Studafy.
- **Shared** means transferred to a third party for its own purposes. Following Google's definitions, nothing below is shared. The exempt cases are:
  - transfers to **service providers** that process data for Studafy under contract: Supabase, Fly.io, Sentry, Axiom, Cloudflare (encrypted backups in R2, EU; Turnstile; the network in front of the API), Together AI (DPA not yet accepted: item 2), Resend, Firebase Cloud Messaging and Redis. Telegram receives alerts that carry no user data (a report's id, kind and priority, a hashed school id; counts). The malware scanner is our own (item 1). Google Workspace (Meet) is not used: Studafy creates no meetings (DL-065);
  - transfers the **user starts themselves**: store purchases go to Google Play and Apple as independent controllers.
- **Ephemeral** means processed only in memory and kept no longer than the request.

No location, contacts, calendar, web browsing, health, financial account, SMS or installed-apps data is collected:
- there is no permission or SDK for any of these (`android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`);
- searches in the app run on the device; the API has no search endpoint (`packages/contracts/src/v1/`).

### Personal info

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Name** | Yes | No | No | Required | App functionality, Account management | The display name chosen at first sign-in (`lib/features/account/presentation/profile_setup_page.dart`). A student's name on class rosters (`students.display_name`). A child account's name, entered by the parent (`lib/features/accounts/presentation/create_child_account_page.dart`). Apple sign-in asks for the full name, but the app never forwards it (`api_session_repository.dart:171-193`). |
| **Email address** | Yes | No | No | Required, except managed child accounts, which have none | Account management, App functionality | The sign-in email, held by Supabase Auth. Notification emails go out via Resend when email delivery is switched on (`packages/infrastructure/src/notifications/channelSenders.ts:53-98`). Meeting invitations through Google Calendar are off: Studafy creates no meetings at launch (DL-065; `MEETINGS_PROCESSOR_ENABLED` unset in `fly.worker.toml`), so no attendee email goes to Google (`packages/infrastructure/src/meetings/conferenceProvider.ts`). |
| **User IDs** | Yes | No | No | Required | App functionality, Account management, Fraud prevention, security and compliance | The account UUID and the Studafy ID (`profiles.public_id`). The account UUID is attached to request logs in Axiom (`apps/api/src/platform/middleware.ts:313-358`). It is also passed to the store as the obfuscated account ID or `appAccountToken` (`lib/data/billing/store_subscription_repository.dart`). |
| **Address** | No | | | | | |
| **Phone number** | No | | | | | There is no phone field in the app's tables or forms. |
| **Race and ethnicity, political or religious beliefs, sexual orientation** | No | | | | | |
| **Other info** | Yes | No | No | Gender is optional ("Prefer not to say" is offered). School records are required for students in a class. | App functionality | Gender (`lib/features/account/domain/profile_setup.dart`; returned only to its owner). Language. Education records: school, class and grade-level membership, grades and feedback, attendance, absences (`supabase/migrations/`, `grade_results`, `attendance_records`). Guardian relationship (`guardian_links`). |

### Financial info

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **User payment info** | No | | | | | Payment details are handled entirely by Google Play. The app never sees them. |
| **Purchase history** | Yes | No | No | Optional (only when someone subscribes) | App functionality, Account management | The store receipt or token, product and environment are sent to `POST /v1/billing/purchases` for checking with Google or Apple (`lib/data/billing/store_subscription_repository.dart`; `packages/infrastructure/src/billing/googleVerifier.ts`). Entitlements are also stored. A student buys their own plan with no approval step in Studafy (DL-071); purchase-approval requests made before 21 October 2026 are kept as billing records. |
| **Credit score, other financial info** | No | | | | | |

### Messages

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Emails** | No | | | | | The app doesn't read the user's email. |
| **SMS or MMS** | No | | | | | |
| **Other in-app messages** | Yes | No | No | Optional | App functionality, Fraud prevention, security and compliance | Teacher–parent and class messages, with read receipts (`conversations` and `messages` tables). Abuse reports include the reported messages (`lib/features/messaging/data/api_messaging_repository.dart:126-146`). Messaging is a school-level switch. |

### Photos and videos

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Photos** | Yes | No | No | Optional | App functionality | Attachments from the camera or gallery, re-encoded at 2400 px and quality 85 (`lib/core/platform_attachment_source.dart:19-31`). Whiteboard photos for notebooks, and photos sent with an AI question (`lib/core/file_upload_repository.dart`). These go to Supabase Storage, our own malware scanner and, for AI photos, Together AI, which receives them as they are (names in text are replaced; a photo cannot be, ADR-0043). AI photos are deleted from storage 30 days after upload once `RETENTION_SCHEDULE_ENABLED` is on (DL-060); that does not change these answers. **Profile photos stay on the device and are not collected** (`lib/core/profile_photo.dart:10-16`). |
| **Videos** | No | | | | | Only JPEG and PNG images are accepted (`lib/core/attachment_policy.dart:32-95`). |

### Audio files

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Voice or sound recordings** | Yes | No | No | Optional | App functionality | Voice notes in messages, mono m4a (`lib/core/platform_voice_notes.dart:26-38`; `attachment_policy.dart:71-75`). `RECORD_AUDIO` is asked for at the first recording (`AndroidManifest.xml`). |
| **Music files, other audio files** | No | | | | | |

### Files and docs

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Files and docs** | Yes | No | No | Optional | App functionality | PDF, DOCX and PPTX: student hand-ins and teacher lesson materials (`lib/core/attachment_policy.dart`). Picked with the system picker, without broad storage permissions (`file_picker`). Uploaded to Supabase Storage, checked by the malware scanner, and read to text for AI tools (page images go to Together AI: `apps/worker/src/processors/materialIndex.ts:105`). |

### Calendar and contacts

| Data type | Collected |
|---|---|
| Calendar events | No. The app creates no meetings (DL-065), and the device calendar is never read. |
| Contacts | No. The "contacts" list in the app is the school directory from the API, not the phone's contacts. |

### App activity

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **App interactions** | Yes | No | No | Required | App functionality, Fraud prevention, security and compliance | Server request logs in Axiom: route, status, duration, account UUID, hashed IP, user-agent family. About 10% of successful requests are kept; errors and slow requests are always kept. Kept for 30 days (`apps/api/src/platform/middleware.ts:313-358`; `fly.api.toml` `LOG_SAMPLE_*`; ADR-0035). There is no analytics SDK (`pubspec.yaml`; `lib/core/telemetry.dart` prints only in debug builds). |
| **In-app search history** | No | | | | | Searches run on the device. |
| **Installed apps** | No | | | | | |
| **Other user-generated content** | Yes | No | No | Optional | App functionality | The full list is below this table. |
| **Other actions** | No | | | | | |

**Other user-generated content:**
- **Students:** assignment and exam answers; notebook notes, highlights, bookmarks and sections. AI helper questions and the chat history sent with them, which go to Together AI with emails, links and long numbers redacted (`packages/domain/src/study/studyContent.ts:44`) and the names Studafy knows replaced (ADR-0043). Only students in a class with a current AI consent can send them. The server stores no AI chat; the history is kept on the device (`lib/features/study_assistant/`).
- **Teachers:** lessons, announcements (which may hold a meeting link), and wellbeing notes (decision 6).
- **Everyone:** abuse reports and appeals.

### Web browsing

Not collected. The only web view is the Cloudflare Turnstile bot check, restricted to the API's own page and `challenges.cloudflare.com` (`lib/features/family/presentation/family_challenge_page.dart:29-66`).

### App info and performance

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Crash logs** | Yes | No | No | Required (there is no in-app opt-out) | Analytics, App functionality | Sentry EU, on only when the build carries `SENTRY_DSN` (`lib/core/crash_reports.dart`). The settings are listed below this table. |
| **Diagnostics** | Yes | No | No | Required | Analytics, App functionality | Device model, OS and app version in crash reports (Sentry default contexts). The platform and app version are recorded for the device list (`auth_devices`). |
| **Other app performance data** | No | | | | | Performance tracing is off (`tracesSampleRate = null`). |

**Sentry settings in the app** (`lib/core/crash_reports.dart`):
- `sendDefaultPii = false`;
- no screenshots, no view hierarchy, no request bodies, no print or tap breadcrumbs;
- `user` and `request` are removed from every event;
- emails, tokens and long numbers are masked.

Native crashes on iOS and Android go through the native SDK, not the Dart `beforeSend`. Item 4.7 reviews this.

### Device or other IDs

| Data type | Collected | Shared | Ephemeral | Required or optional | Purposes | What and where |
|---|---|---|---|---|---|---|
| **Device or other IDs** | Yes | No | No | Optional (only if notifications are allowed) | App functionality | What is collected is listed below this table. |

**Device or other IDs:**
- **Collected:**
  - The Firebase Cloud Messaging token, posted to `/v1/me/push-devices` (`lib/features/notifications/data/firebase_push_registrar.dart:64-80`; `push_devices`).
  - The Firebase Installation ID, which the Firebase SDK sends to Google as Firebase declares it.
- **Not collected:** the advertising ID (no `AD_ID` permission, no ads SDK) and the Android ID.

---

## Section 3: Differences by role

The form is answered once for the whole app. This table shows who the data
comes from, to check the answers against each role.

| Role | Data that comes from this role |
|---|---|
| **Student** | Name, email (unless a managed child account), gender (optional), Studafy ID. Class membership. Hand-ins (files, photos, text), exam answers, notebooks, AI questions and photos, messages (if the school allows), voice notes, push token. Grades and attendance are entered about them by teachers. |
| **Managed child account** (created by a parent) | Name and language only, entered by the parent; no email (ADR-0031). Otherwise the same as a student. |
| **Parent or guardian** | Name, email, gender (optional). Guardian links and relationship. Family+ purchases. Messages with teachers. Turnstile check when looking up a student. |
| **Teacher** | Name, email, gender (optional). Workspace and class details. Lessons and materials (files). Grades, attendance, absences, wellbeing notes about students. Announcements, meetings, messages. |

Data on the device only, not collected:
- profile photos;
- the offline cache;
- downloaded attachments;
- the local copy of AI chat history.

See `lib/data/local_cache/`, `lib/core/profile_photo.dart` and
`lib/features/study_assistant/data/file_study_chat_store.dart`.

---

## Section 4: Families policy notes

- **No ads and no ad SDKs:** `pubspec.yaml` has no ads, analytics or attribution packages.
- **Every SDK in the release app is on Google's Families self-certified list or is first-party:**
  - Firebase Messaging and Core;
  - Sentry (confirm it is still listed when you submit);
  - Supabase, used as our backend, not an SDK that collects data for itself;
  - in_app_purchase (Play Billing);
  - sign_in_with_apple;
  - webview_flutter, used only for the Turnstile check.
- **No location, no contacts, no advertising ID** (manifest above).
- **Android Auto Backup is switched off** (`android:allowBackup="false"` and backup and data-extraction rules that exclude everything, in `android/app/src/main/AndroidManifest.xml`). This keeps the offline cache, AI chat history and profile photos out of Google Drive backups. It was changed as part of this item.

---

## Change history

- 2026-10-11: first draft (item 3.6).
