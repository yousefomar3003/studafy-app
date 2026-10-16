# Owner guides: your parts of the launch

Launch plan item A7. These guides cover the steps only you can do: accounts,
keys, consoles and store forms. Each one says what to prepare, what to click,
what to type, what to give Claude, and how Claude checks it.

The task numbers (C1, B11, ...) come from the launch plan
(`docs/planning/launch-plan-2026-10-15.md`, in PR #54). The numbers in
brackets (3.3, 5.4, ...) come from
[`launch-work-plan.md`](../../planning/launch-work-plan.md).

Written 2026-10-15 from the code on `main`. The console screens are
described as best we know them. Consoles change often. **If a screen looks
different, look for the words in "quotes"**: the button or field name
usually stays the same even when the menu moves.

## The order

Do them from top to bottom. The "Needs" column says what must be done first.

| # | Launch plan | Guide | Needs |
|---|---|---|---|
| 1 | C1 (3.3) | [01 Android upload key](01-android-upload-key.md) | Nothing |
| 2 | C4 (3.7) | [09 Play Console](09-play-console-listing.md), parts A and B: create the app, upload Claude's first build | C1, and Claude's build (A3) |
| 3 | C2 (3.4) | [02 Google sign-in and fingerprints](02-google-signin-sha1.md) | The first upload |
| 4 | C3 (3.8) | [03 Firebase](03-firebase.md), parts A to C | Nothing |
| 5 | C5 | [04 Resend (email)](04-resend.md) | Your DNS (Cloudflare) |
| 6 | C6 (3.9) | [05 Play billing](05-play-billing.md) | The first upload (Play needs it before it lets you create subscriptions) |
| 7 | C7 (4.1) | [06 Production Supabase](06-production-supabase.md) | Decisions B2 and B3 |
| 8 | B11 (5.1, 5.2) | [07 Apple](07-apple.md), parts A to C | The Apple Developer account |
| 9 | C13 (5.3) | [07 Apple](07-apple.md), parts D and E | B11 |
| 10 | C14 (5.4) | [03 Firebase](03-firebase.md), part D | B11 |
| 11 | C15 (5.6) | [08 App Store products](08-app-store-products.md) | B11 |
| 12 | C16 (5.7) | [10 App Store Connect](10-app-store-connect.md), part A | B11, and Claude's iOS build |
| 13 | B12 (3.6, 5.5) | [09 Play Console](09-play-console-listing.md) parts C to F, and [10 App Store Connect](10-app-store-connect.md) parts B to D | The steps above |

## How to give things to Claude

1. Make one private folder for everything secret, **outside** the project:

   ```sh
   mkdir -p ~/studafy-secrets && chmod 700 ~/studafy-secrets
   ```

2. Save every key, password and downloaded secret file there.
3. In chat, give Claude the **file path**, never the contents. For example:
   "C3 done. Service account: `~/studafy-secrets/firebase-service-account.json`."
4. Values that are **not** secret (project IDs, client IDs, key IDs, team
   IDs, email addresses) can be typed in chat. Each guide says which ones.
5. For the test copy only, you may instead add a `NAME=value` line to
   `.env.hosted` in the project folder and tell Claude the name. Claude
   reads the file without printing it.
6. To save a copied secret into a file without it entering your shell
   history, copy it, then run (with your own file name):

   ```sh
   pbpaste > ~/studafy-secrets/NAME.txt && chmod 600 ~/studafy-secrets/NAME.txt
   ```

7. Back up the things that cannot be downloaded again (the Android upload
   key, Apple `.p8` keys): Apple Passwords for passwords, and a USB stick for
   files.

If you paste a secret into chat by mistake, say so. Claude will help you
replace it (a secret that has been in a chat counts as leaked).

## What Claude does after each guide

Claude puts the values where the code reads them (Fly secrets, the release
build settings, git-ignored files), tests them, and tells you the result.
Every Fly change and every merge still waits for your "go".

## Gaps found while writing these guides

Places where the plan and the code do not match. Each guide repeats the
ones that affect it.

1. **Google sign-in does not use the Android SHA-1.** The app signs in with
   Google through Supabase in the browser
   (`lib/features/session/data/api_session_repository.dart`,
   `signInWithOAuth`). There is no native Google sign-in package, so the
   Android OAuth client (C2, 3.4) is not needed for sign-in today. The
   release **SHA-256** is still needed later for Android App Links
   (`assetlinks.json`). See guide 02.
2. **Sign in with Apple needs no Service ID or key today.** The app uses
   Apple's native sign-in on iPhone only, and does not offer Apple on
   Android. Supabase only needs the bundle ID `com.studafy.light` in the
   Apple provider's "Client IDs". The Service ID and key in C13 are only for
   a web flow the app does not use. See guide 07.
3. **Google Play "voided purchase" notifications are not handled.** The
   worker accepts only subscription and test notifications
   (`apps/worker/src/billing/processor.ts`). Refunds still arrive as
   subscription events. See guide 05.
4. **No email test command.** `scripts/send-test-notification.ts` tests push
   only. Claude must test email another way (guide 04).
5. **No way for store reviewers to sign in.** The app only offers Google,
   Microsoft and Apple sign-in. `scripts/seed-reviewer-tenant.ts` makes
   email accounts, runs on the local stack only, and the app has no email
   sign-in screen. Reviewers need working demo accounts (guides 09 and 10).
6. **Old app ID in two docs.** `docs/release/rel-002-store-accounts.md` and
   `docs/release/auth030-site-association.md` still say `io.studafy.app` as
   the app ID. The app ID is `com.studafy.light` (DL-058).
   `io.studafy.app` is only the sign-in link scheme.
7. **Android release signing is not wired yet.**
   `android/app/build.gradle.kts` still signs release with the debug key and
   blocks release builds (SEC-001). Another PR adds this; guide 01 only
   covers your side.
8. **The iOS Firebase file is not in the Xcode project.**
   `ios/Runner.xcodeproj` has no `GoogleService-Info.plist`. Claude must add
   it to the Runner target, or build with the `FIREBASE_*` settings instead.
