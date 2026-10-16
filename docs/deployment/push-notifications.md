# Push notifications (Firebase Cloud Messaging)

Push goes through FCM, which relays to Apple's push service on iPhone. What
is sent is fixed, content-free copy ("New message", "Subscription
renewed"); the app shows the details after sign-in.

## How it fits together

- **App** (`lib/features/notifications/data/firebase_push_registrar.dart`,
  bound by `lib/app/push_binder.dart`): when an account signs in, or after
  an account switch, it initialises Firebase, asks for notification
  permission, and registers the FCM token with
  `POST /v1/me/push-devices`. It re-registers when Firebase
  rotates the token. On sign-out it unregisters the token.
- **Server:** tokens are stored in `public.push_devices`, which has RLS on
  and no client or runtime grants; it is reached only through the API's
  functions. The worker (`NOTIFICATION_CHANNELS_ENABLED=true`) fans each
  in-app notification out to the recipient's phones. Push is on by default
  and can be turned off per category. Tokens Firebase reports dead are
  revoked.
- **Keys:** the app holds only Firebase's public app identifiers. The
  service-account private key that sends messages is the worker's
  `FCM_SERVICE_ACCOUNT_JSON`, and nothing else has it.

## Setup

1. **Firebase console → Add project** (it can be the Google Cloud project
   used for Play billing).
2. **Add apps:** Android with package `com.studafy.light`; iOS with the
   Runner bundle id.
3. **iOS:** Apple Developer → Keys → create a key with *Apple Push
   Notifications service (APNs)*, then upload the `.p8` in Firebase →
   Project settings → Cloud Messaging → Apple app configuration. In
   Xcode, the Runner target needs the *Push Notifications* capability
   (`aps-environment` is already in `Runner.entitlements`) and *Background
   Modes → Remote notifications* (already in `Info.plist`). Release signing
   uses `production`.
4. **Give the app its Firebase config**, one of:
   - **dart-defines** (no native project changes). From Firebase → Project
     settings → Your apps:

     ```sh
     flutter build apk \
       --dart-define=FIREBASE_PROJECT_ID=<project id> \
       --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender id> \
       --dart-define=FIREBASE_ANDROID_API_KEY=<android api key> \
       --dart-define=FIREBASE_ANDROID_APP_ID=<1:…:android:…> \
       --dart-define=FIREBASE_IOS_API_KEY=<ios api key> \
       --dart-define=FIREBASE_IOS_APP_ID=<1:…:ios:…> \
       --dart-define=FIREBASE_IOS_BUNDLE_ID=<bundle id>
     ```

   - **or native files:** `android/app/google-services.json` (the Gradle
     plugin applies itself when the file is present), and
     `ios/Runner/GoogleService-Info.plist` added to the Runner target in
     Xcode. Both are git-ignored and belong in CI secrets.

   These values identify the app to Firebase; they are not secrets.
   Since DL-070 the complete `FIREBASE_*` defines turn push on by
   themselves (`pushEnabledFor` in `firebase_push_registrar.dart`); for a
   production store build add them to `config/dart-defines.production.json`
   (they are on the production contract's allowlist). The native files
   need `PUSH_ENABLED=true` as well, because Dart cannot see them.
   `PUSH_ENABLED=false` keeps push off whatever is configured. A build with
   none of it starts normally and never initialises Firebase.
5. **Server (worker):** Firebase → Project settings → Service accounts →
   *Generate new private key*. Set `FCM_PROJECT_ID` and
   `FCM_SERVICE_ACCOUNT_JSON` (one line) in the host's secret store.
   Production's `fly.worker.toml` already has
   `NOTIFICATION_CHANNELS_ENABLED = "true"` (DL-070): push starts on the
   worker's next deploy after the secrets are imported. Until then the
   worker fans out and sends nothing for push (and nothing for email
   without the Resend pair), so no backlog is sent late.

## Testing

Send a test notification through the whole pipeline to an account that has
signed in on a phone with notifications allowed:

```sh
DATABASE_URL=<operator connection> bun scripts/send-test-notification.ts --user <profile uuid>
```

It queues an in-app *Test notification*, waits for the worker to push it,
and prints `sent`, or the error code (for example `UNREGISTERED`).

To check only the Firebase credentials, without the database or the worker:

```sh
FCM_PROJECT_ID=… FCM_SERVICE_ACCOUNT_JSON='…' \
  bun scripts/send-test-notification.ts --token <FCM token from a debug build>
```

To check email (Resend), send one test email to an address you can read,
with the worker's `RESEND_API_KEY` and `EMAIL_FROM_ADDRESS` in the
environment (from the host's secret store, never typed into a file):

```sh
RESEND_API_KEY=… EMAIL_FROM_ADDRESS=… \
  bun --no-env-file scripts/send-test-email.ts you@example.com
```

It goes through the worker's own sender (`ResendEmailSender`) and prints
`sent <Resend message id>`, or `error <code>` (for example
`PROVIDER_AUTH_401` for a wrong key, `EMAIL_ADDRESS_REJECTED`). It never
prints the key, the sender or the address. A user receives email only for
the categories they turned email on for (email is off by default).

Tested so far (2026-09-29, local): the test notification is queued, fans
out to push for a registered device, and is claimed by the push sender.
Delivery to a real phone needs your Firebase project, the APNs key and the
service account.
