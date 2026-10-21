# App Store privacy labels ("App Privacy")

Launch plan 5.5, drafted 2026-10-12. These are the answers for App Store Connect → App Privacy, in the order the form asks. **Nothing has been submitted.** Item 5.5 drafts these; the owner submits them once the Apple Developer account is approved.

These answers have to agree with:
- `ios/Runner/PrivacyInfo.xcprivacy`, the app's own privacy manifest, in this same PR;
- the Google Play answers in `docs/store/google-play-data-safety.md` (item 3.6), which also hold the full evidence for each data type, with file paths;
- the privacy policy (item 4.3).

When one changes, change all of them.

---

## Needs Yousef's decision

**Decided 2026-10-13** (DL-056):
- **Category:** not the Kids category. Education, with an honest age rating (item 1).
- **Arabic permission prompts:** added in `ios/Runner/ar.lproj/InfoPlist.strings` (item 4).
- **AI:** off for real students until the DPA and DPIA are signed (item 2). **Superseded 2026-10-16 by DL-062: AI is on from launch**, for students in a class only, after a separate AI consent; the DPA and DPIA are still not signed. **Changed 2026-10-21 by DL-072 (ADR-0045):** AI is for every student account, in a class or not, still after the AI consent. The study helper is now the AI Tutor.
- **Sentry IP storage** (item 3) needs the Sentry dashboard. The CI token cannot change project settings.

1. **Age rating and the Kids category.** Students are children.
   - "Made for Kids" (the Kids category) adds rules: no third-party analytics or ads, and parental gates on links out and purchases.
   - Studafy is used in school, by teachers and parents as well, so the usual choice is **not** the Kids category, with an honest age rating. Decide this together with the Google Play target audience (decision 3 in the Play doc).
2. **AI provider DPA.** Same as decision 2 in the Play doc. Without a DPA, Together AI is not a service provider and the answers change. AI is on from launch (DL-062) and the DPA is not accepted yet; privacy policy 1.5 §8 says so. Accept it before submitting these answers.
3. **The Sentry setting "Prevent Storing of IP Addresses"** (`docs/deployment/fly-io.md`). These answers say crash data is not linked to the user, which needs that setting on. Also needed: the native crash handler must attach no installation ID. Item 4.7 checks this.
4. **Arabic permission prompts.** `ios/Runner` has no `ar.lproj/InfoPlist.strings`, so Arabic users see the camera, microphone and photo prompts in English. Add Arabic strings before release. They need a localized variant group in Xcode, which is best done in Xcode itself.

---

## Step 1: Data collection

**"Do you or your third-party partners collect data from this app?"** Yes.

Apple defines "collect" as sending data off the device where it is kept longer than needed to serve the request in real time.

Not collected, because it stays on the device:
- profile photos (`lib/core/profile_photo.dart`);
- the offline cache (`lib/data/local_cache/`);
- the local AI chat history (`lib/features/study_assistant/data/file_study_chat_store.dart`);
- quizzes and flashcards a Studafy Max student makes from their own notes, held by the app while they practise (DL-072).

Not collected under Apple's definition, because it is kept no longer than the request: a photo or screenshot that a student with no class adds to an AI Tutor question, or that any student turns into a personal note. It is redrawn on the API, sent once to Together AI and discarded, never stored (DL-072, ADR-0045). Photos or Videos stays ticked because other photos are stored.

---

## Step 2: Data types

These are the boxes to tick, in the form's order. Anything not listed stays unticked.

| Category | Data type | Tick? | Notes |
|---|---|---|---|
| Contact Info | Name | **Yes** | Display name; the name on class rosters |
| | Email Address | **Yes** | Sign-in email. Managed child accounts have none. |
| | Phone Number | No | |
| | Physical Address | No | |
| | Other User Contact Info | No | |
| Health & Fitness | Health, Fitness | No | See decision 6 in the Play doc (wellbeing notes) |
| Financial Info | Payment Info | No | Handled entirely by Apple |
| | Credit Info, Other Financial Info | No | |
| Location | Precise, Coarse | No | IPs are only kept as keyed hashes in our own tables. No location is derived. |
| Sensitive Info | Sensitive Info | No | Gender is not in Apple's sensitive list; it goes under Other Data |
| Contacts | Contacts | No | The in-app directory comes from the school, not the phone |
| User Content | Emails or Text Messages | **Yes** | In-app messages |
| | Photos or Videos | **Yes** | Photo attachments, whiteboard photos, photos a student in a class sends to the AI Tutor (kept 30 days). Photos from a student with no class, and photos turned into personal notes, are not stored (Step 1). No video. |
| | Audio Data | **Yes** | Voice notes in messages |
| | Gameplay Content | No | |
| | Customer Support | No | There is no in-app support channel. Abuse reports are counted under Other User Content. |
| | Other User Content | **Yes** | Hand-ins, exam answers, documents, notebooks (personal notes included), AI questions, lessons, announcements, wellbeing notes, reports |
| Browsing History | | No | |
| Search History | | No | Searches run on the device |
| Identifiers | User ID | **Yes** | Account ID, Studafy ID |
| | Device ID | **Yes** | Push token |
| Purchases | Purchase History | **Yes** | App Store subscriptions |
| Usage Data | Product Interaction | **Yes** | Server request logs (route, status, account ID), kept 30 days |
| | Advertising Data | No | |
| | Other Usage Data | No | |
| Diagnostics | Crash Data | **Yes** | Sentry |
| | Performance Data | No | Tracing is off |
| | Other Diagnostic Data | **Yes** | Device model, OS and app version in crash reports |
| Surroundings | Environment Scanning | No | |
| Body | Hands, Head | No | |
| Other Data | Other Data Types | **Yes** | Gender (optional), language, school records (classes, grades, attendance, guardian links) |

---

## Step 3: For each ticked type

Every type: **purpose App Functionality**, **not used for tracking** (no ads, no data brokers, no linking with other companies' data). The only differences are in the table.

| Data type | Purposes | Linked to the user's identity? | Tracking? |
|---|---|---|---|
| Name | App Functionality | Yes | No |
| Email Address | App Functionality | Yes | No |
| Emails or Text Messages | App Functionality | Yes | No |
| Photos or Videos | App Functionality | Yes | No |
| Audio Data | App Functionality | Yes | No |
| Other User Content | App Functionality | Yes | No |
| User ID | App Functionality | Yes | No |
| Device ID | App Functionality | Yes | No |
| Purchase History | App Functionality | Yes | No |
| Product Interaction | App Functionality | Yes (account ID in logs) | No |
| Crash Data | App Functionality, Analytics | **No** (see decision 3) | No |
| Other Diagnostic Data | App Functionality, Analytics | **No** | No |
| Other Data Types | App Functionality | Yes | No |

"Analytics" on crash and diagnostic data matches the Play answer and means understanding how the app performs. No analytics SDK exists (`pubspec.yaml`; `lib/core/telemetry.dart` prints only in debug builds).

---

## The privacy manifest (`ios/Runner/PrivacyInfo.xcprivacy`)

- **Tracking:** `NSPrivacyTracking = false`, with no tracking domains.
- **Required-reason APIs declared by the app itself:**

  | API category | Reason | Why |
  |---|---|---|
  | `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` (files inside the app container) | The offline file cache reads modification times to evict the oldest (`lib/data/local_cache/offline_file_cache.dart:77,82`) |
  | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` (the app's own data) | Device settings through `shared_preferences` (`lib/data/settings/preferences_device_settings.dart`) |

- **Collected data types:** exactly the ticked types above, with the same purposes and linkage.

### Third-party SDK manifests

Xcode merges each SDK's own manifest into the privacy report (Product → Archive → Generate Privacy Report).

**SDKs that ship a manifest** (seen in the 2026-10-11 release build and `~/.pub-cache`):
- **Flutter plugins:** app_links, file_picker, firebase_messaging, flutter_secure_storage, image_picker, in_app_purchase_storekit, package_info_plus, path_provider, record, share_plus, shared_preferences, sqflite, url_launcher, webview_flutter.
- **Native SDKs:** Sentry, FirebaseCore, FirebaseCoreInternal, FirebaseInstallations, FirebaseMessaging, GoogleDataTransport, the GoogleUtilities modules, FBLPromises, nanopb, and Flutter.framework.

**SDKs that ship no manifest, flagged:**

| Plugin | Version | Finding |
|---|---|---|
| `audioplayers_darwin` | 6.5.0 | No `PrivacyInfo.xcprivacy`. Its native code calls no required-reason API (no UserDefaults, file timestamp, boot time, disk space or keyboard APIs found). |
| `sign_in_with_apple` | 8.2.0 | Same |
| `firebase_core` (Flutter wrapper) | 4.15.0 | Same; the native FirebaseCore it wraps has its own |
| `sentry_flutter` (Flutter wrapper) | 9.30.1 | Same; the native Sentry framework has its own |

None of these four is on Apple's list of commonly used SDKs that must ship a signed manifest. Re-check when upgrading them, and open an issue upstream if Xcode's privacy report flags them.

### Permission prompts (`ios/Runner/Info.plist`)

The camera and photo-library prompts now name every use. The camera prompt used to mention only the whiteboard, but the camera is also used for attachments (`lib/core/platform_attachment_source.dart:19-24`) and profile photos (`lib/app/account_hub_page.dart:659`).

| Key | Text |
|---|---|
| `NSCameraUsageDescription` | "Studafy uses the camera when you take a photo to attach to your work or a message, photograph the lesson whiteboard for your notebook, or set a profile picture." |
| `NSPhotoLibraryUsageDescription` | "Studafy uses only the photos you choose: to attach to your work or a message, add to your notebook, or set as your profile picture." |
| `NSMicrophoneUsageDescription` | Unchanged: voice notes in messages |

There is no `NSUserTrackingUsageDescription`, because there is no tracking and so no App Tracking Transparency prompt.

---

## Consistency with the Google Play answers

| Play data type | App Store data type | Agree? |
|---|---|---|
| Name | Name | Yes |
| Email address | Email Address | Yes |
| User IDs | User ID | Yes |
| Other info (gender, school records) | Other Data Types | Yes |
| Purchase history | Purchase History | Yes |
| Other in-app messages | Emails or Text Messages | Yes |
| Photos | Photos or Videos | Yes |
| Voice or sound recordings | Audio Data | Yes |
| Files and docs; Other user-generated content | Other User Content | Yes. Apple has no separate "files" type. |
| App interactions | Product Interaction | Yes |
| Crash logs | Crash Data | Yes (both: functionality and analytics) |
| Diagnostics | Other Diagnostic Data | Yes |
| Device or other IDs | Device ID | Yes |
| Location, contacts, calendar, search, browsing, health, financial | Not ticked | Yes |

---

## Change history
- 2026-10-12: first draft (item 5.5).
- 2026-10-21: DL-072 (ADR-0045, privacy policy 1.7). AI for every student account; the AI Tutor name; personal notes; photos that are not stored. No box changes.
