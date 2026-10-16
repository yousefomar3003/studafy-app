# 03 · Firebase (push notifications)

Launch plan **C3** (work plan 3.8) for Android, and **C14** (work plan 5.4)
for iPhone. Time: 30 minutes, plus 15 minutes for iPhone later.

Push goes through Firebase Cloud Messaging (FCM). On iPhone, FCM passes it
to Apple. The runbook is
[`docs/deployment/push-notifications.md`](../../deployment/push-notifications.md).

## Before you start

- A Google account. Use the same Google Cloud project as Play billing
  ([guide 05](05-play-billing.md)) if you can: one project is simpler.
- The private folder `~/studafy-secrets` ([README](README.md)).
- For part D only: the Apple Developer account ([guide 07](07-apple.md)).

## Exact values

| Field | Value |
|---|---|
| Android package name | `com.studafy.light` |
| iOS bundle ID | `com.studafy.light` |
| Google Analytics | Off (not used) |

## Part A: the project

1. Open [console.firebase.google.com](https://console.firebase.google.com).
2. Click **"Create a project"** (or "Add project").
3. If it offers to use an existing Google Cloud project, choose the one for
   Play billing. Otherwise name it `Studafy`.
4. **Google Analytics: turn it off.** The app does not use it.
5. **"Create project"**. Wait, then **"Continue"**.

## Part B: the Android app

1. On the project page, click the **Android** icon ("Add app").
2. "Android package name": `com.studafy.light`. It must be exact.
3. "App nickname": `Studafy Android`.
4. "Debug signing certificate SHA-1": leave empty. Push does not need it.
5. **"Register app"**.
6. **"Download google-services.json"**. Move it to
   `~/studafy-secrets/google-services.json`.
7. Skip the next steps ("Add Firebase SDK"). Claude does that part. Click
   **"Next"** until **"Continue to console"**.

## Part C: the server key

1. Click the gear ⚙ → **"Project settings"**.
2. **"General"** tab: copy the **"Project ID"** (for example
   `studafy-1a2b3`). It is not secret.
3. **"Cloud Messaging"** tab: "Firebase Cloud Messaging API (V1)" must say
   **"Enabled"**. If not, click the ⋮ menu next to it → "Manage API in
   Google Cloud Console" → **"Enable"**. (The old "Legacy" API is not used;
   leave it off.)
4. **"Service accounts"** tab → "Firebase Admin SDK" →
   **"Generate new private key"** → **"Generate key"**. A JSON file
   downloads.
5. Move it, and lock it:

   ```sh
   mv ~/Downloads/*-firebase-adminsdk-*.json ~/studafy-secrets/firebase-service-account.json
   chmod 600 ~/studafy-secrets/firebase-service-account.json
   ```

   This file is a **secret**. Never open it in chat.

### Give Claude (Android)

> C3 done. Project ID `…`. `~/studafy-secrets/google-services.json` and
> `~/studafy-secrets/firebase-service-account.json`.

## Part D: iPhone (later, after Apple approves; C14)

### D1. The APNs key (Apple)

1. Open [developer.apple.com/account](https://developer.apple.com/account) →
   **"Certificates, Identifiers & Profiles"** → **"Keys"** → **"+"**.
2. "Key Name": `Studafy APNs`.
3. Tick **"Apple Push Notifications service (APNs)"**. If it asks for an
   environment, choose **"Sandbox & Production"**. If it asks for a scope,
   choose the team (or the app `com.studafy.light`).
4. **"Continue"** → **"Register"** → **"Download"**. The file is
   `AuthKey_XXXXXXXXXX.p8`. **It downloads only once.**
5. Move it to `~/studafy-secrets/` and copy it to the USB stick.
6. Note the **Key ID** (10 characters, on the key page) and your
   **Team ID** (top right, or "Membership details"). Both are not secret.

### D2. The iOS app (Firebase)

1. Firebase → project page → **"Add app"** → **iOS** (Apple icon).
2. "Apple bundle ID": `com.studafy.light`.
3. "App nickname": `Studafy iOS`. "App Store ID": leave empty.
4. **"Register app"** → **"Download GoogleService-Info.plist"** → move it
   to `~/studafy-secrets/GoogleService-Info.plist`.
5. Skip the remaining steps → **"Continue to console"**.

### D3. Upload the APNs key to Firebase

1. Gear ⚙ → **"Project settings"** → **"Cloud Messaging"** tab.
2. Under **"Apple app configuration"**, choose the iOS app.
3. "APNs Authentication Key" → **"Upload"**.
4. Choose the `.p8` file. Enter the **Key ID** and **Team ID**.
5. **"Upload"**.

### Give Claude (iPhone)

> C14 done. `~/studafy-secrets/GoogleService-Info.plist`. APNs key uploaded
> to Firebase, Key ID `…`, Team ID `…`.

Claude does not need the `.p8` itself. Only Firebase needs it.

## What Claude does

- Copies `google-services.json` to `android/app/google-services.json` (git
  ignores it). The Gradle plugin turns on when the file is there.
- For iPhone, adds `GoogleService-Info.plist` to the Runner target in Xcode
  (it is not in the project yet), or uses the `FIREBASE_*` build settings
  instead.
- Builds the app with Firebase's config. The `FIREBASE_*` build settings
  turn push on by themselves; the native files also need `PUSH_ENABLED=true`
  (DL-070). Without either the app never starts Firebase.
- Sets the worker's Fly secrets (after your "go"):
  - `FCM_PROJECT_ID` = your project ID;
  - `FCM_SERVICE_ACCOUNT_JSON` = the service-account file, on one line.

  In production `NOTIFICATION_CHANNELS_ENABLED = "true"` is already in
  `fly.worker.toml` (DL-070); on the test copy it is set with the secrets.

  The worker refuses to start if only one of the two `FCM_*` values is set.
  The server side needs nothing new for iPhone: the same key sends to both.

## How Claude checks it

1. The worker's start-up log shows `notificationChannels.pushConfigured:
   true`.
2. Credentials only:
   `bun scripts/send-test-notification.ts --token <token from a debug build>`
   prints `sent`.
3. The whole path:
   `bun scripts/send-test-notification.ts --user <your profile id>` prints
   `sent`, and the phone shows "Test notification". On iPhone, test with
   the app open and closed.

## Common mistakes

- **Wrong package or bundle ID.** It must be `com.studafy.light`, not
  `io.studafy.app` (that is only the sign-in link scheme).
- **"Generate new private key" more than once.** Each click makes a new
  working key. Delete the extra ones: Google Cloud → "IAM & Admin" →
  "Service accounts" → `firebase-adminsdk-…` → "Keys".
- **The `.p8` is lost.** It downloads once. Make a new key, upload it to
  Firebase again, and revoke the old one.
- **Notifications not allowed on the phone.** Android 13+ and iPhone ask
  for permission. If you said no, turn it on in the phone's settings.
- **Analytics left on.** It adds data collection the store forms do not
  declare. Keep it off.
