# ADR-0044: Release cutover (REL-002)

- Status: Accepted — the owner's decision of 2026-10-17
- Date: 2026-10-17
- Decision owner: repository owner
- Decision log: DL-069
- Supersedes in part: ADR-0042 (its "production stays blocked" half; the
  development build and the upload-key signing rules stay as written)
- Relates to: SEC-001 (`docs/security/sec-001-containment.md`), REL-002
  (`docs/release/rel-002-store-accounts.md`), DL-033 (Sign in with Apple),
  DL-064 (production database), DL-067 (domains); launch plan D1, launch
  work plan 7.3

## Context

SEC-001 blocked every native release build: an Xcode build phase failed
every iOS `Release` build, and a Gradle task-graph check refused every
Android release task except, since ADR-0042, the development test copy. The
app itself refused to start with `APP_ENV=production`. REL-002 was always
meant to replace these blocks in one reviewed change.

The owner decided on 2026-10-17 to do that now, before the production
backend exists, so that store builds can be made and checked in production
mode while the remaining launch items finish. The production values are
decided: the API at `https://api.studafy.com` and app links on
`app.studafy.com` (DL-067), the Frankfurt Supabase project
`cyrngoqnhqflzovlybbr` (DL-064), legal pages on `legal.studafy.com`.

Removing the blocks must not make a wrong production build easy. A build is
only as safe as the values compiled into it, and they are fixed at build
time: a production app pointed at the test API, an old project, a missing
legal page, or carrying a secret key or a demo switch is exactly what the
blocks prevented.

## Decision

**Replace the blocks with one production defines contract, checked
everywhere a production build can be made.** The contract is Dart,
`lib/core/production_contract.dart`, so the app and the build checks share
one implementation. A production build must carry:

| Define | Rule |
|---|---|
| `APP_ENV` | `production`, once |
| `STUDAFY_API_URL` | exactly `https://api.studafy.com` |
| `SUPABASE_URL` | exactly `https://cyrngoqnhqflzovlybbr.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | a publishable key, `sb_publishable_…`; a secret key or a legacy JWT (which could be the service role) is refused |
| `STUDAFY_PRIVACY_URL`, `STUDAFY_TERMS_URL` | https on `legal.studafy.com`, no port, query or credentials |
| `TURNSTILE_ENABLED` | `true` |
| `APPLE_SIGN_IN_ENABLED` | `true` on iOS (guideline 4.8, DL-033); `true` or `false` on Android |
| `SENTRY_DSN` | empty or an https `sentry.io` DSN |
| `PUSH_ENABLED` | `true` or `false` when given |
| build number | above 1 (the `pubspec.yaml` baseline), from `--build-number` |

Only allowlisted names may appear (plus the `FLUTTER_*` defines the Flutter
tool adds and refuses to let a build set), none may be given twice (a later
`--dart-define` silently wins), and no value may look like a server secret.
An unknown define such as a future demo or seed switch is refused until it
is reviewed into the allowlist.

**Android.** `android/app/build.gradle.kts` still checks every release task
in the task graph. Every `APP_ENV` in Flutter's dart-defines must be the
same value, `production` or `development`; staging, synthetic, none, and a
mix are refused. Production then runs `tools/check_release_defines.dart` on
exactly the dart-defines Gradle received (with the Flutter SDK's Dart, found
through `local.properties`); anything but a clean pass, including Dart not
starting, fails the build. Production is signed with the upload key only:
`STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE` is refused for it and stays a local
check for development builds. A development release behaves as under
ADR-0042.

**iOS.** The `SEC-001 Release Block` phase is replaced, in place and still
first, by `Release Defines Check`, which runs
`scripts/release/ios-release-check.sh`. For the `Release` configuration
(builds and archives) it runs the same tool on Xcode's `DART_DEFINES`, which
the Flutter tool writes into `ios/Flutter/Generated.xcconfig`, with the same
production/development rule. Debug and Profile are not checked. Signing stays
with the owner's team in their local Xcode settings; no `DEVELOPMENT_TEAM`
is committed. The `project.pbxproj` change is the phase's name and script
only.

**The app.** `RuntimePolicy.blocksApplicationStartup` is now true only for a
production build whose compiled defines fail the contract; such a build
shows the readiness block instead of starting. Production initializes the
remote backend like development and staging. Remote file uploads stay off in
production (`allowsRemoteFileUploads`) in this change.

**Production defines and the build script.** The committed
`config/dart-defines.production.example.json` holds the public production
values, with placeholders for the publishable key and the Sentry DSN, which
the contract refuses until filled. The filled copy,
`config/dart-defines.production.json`, is git-ignored.
`scripts/release/build-store.sh android|ios --build-number N` refuses a
missing or tracked defines file, checks the contract, refuses the debug-key
opt-in and a missing upload key on Android, and runs `flutter build
appbundle` or `flutter build ipa` with the file and the build number.

## Version numbers

The version name comes from `pubspec.yaml` (`1.0.0`). The build number
(Android `versionCode`, iOS `CFBundleVersion`) comes from `--build-number`:
the Flutter tool passes it to Gradle (`local.properties`), to Xcode
(`FLUTTER_BUILD_NUMBER`) and into the dart-defines, where the contract
reads it. Each store refuses an upload whose number is not above every
earlier one, rejected uploads included. In GitHub Actions
`.github/scripts/build-number.sh` gives `1000 + GITHUB_RUN_NUMBER`; a local
build passes a number above the last upload to that store (Play Console >
App bundle explorer; App Store Connect > TestFlight).

## Building

1. Copy `config/dart-defines.production.example.json` to
   `config/dart-defines.production.json`. Fill `SUPABASE_PUBLISHABLE_KEY`
   from the Supabase dashboard (project `cyrngoqnhqflzovlybbr` > Project
   Settings > API Keys, the `sb_publishable_…` key; never the secret key)
   and `SENTRY_DSN` with the app's Sentry DSN, or empty.
2. Android (upload key as in ADR-0042, "Building the internal-testing
   bundle"):

   ```sh
   STUDAFY_ANDROID_KEY_PROPERTIES=~/studafy-signing/key.properties \
     scripts/release/build-store.sh android --build-number 1001
   ```

   The bundle is `build/app/outputs/bundle/release/app-release.aab`.
3. iOS (the owner's team selected in Xcode for the Runner target):

   ```sh
   scripts/release/build-store.sh ios --build-number 1001
   ```

   The archive and IPA are under `build/ios/`.

## Consequences

- Store builds can be made in production mode. **None may be uploaded, to
  any track, until `https://api.studafy.com` is live** and the DL-064
  cutover steps are done (DL-069): a production app pointed at an API that
  does not answer fails every sign-in.
- What still refuses: staging and synthetic release builds on both
  platforms; production builds that miss the contract (at Gradle, at Xcode,
  in `build-store.sh`, and at app start); debug-key signing of production;
  a keystore inside the repository; a tracked production defines file.
- `.github/scripts/check-android-release-guard.sh` (CI Android job and the
  release-artifacts workflow) runs each refusal through Gradle and shows a
  production build that matches the contract and a development build both
  reach signing. `.github/scripts/check-ios-release-guard.sh` (CI Flutter
  job and release-artifacts) runs the Xcode phase script with Xcode's
  environment. Neither builds or signs anything.
- `test/architecture/release_containment_test.dart` pins the wiring, and
  `test/core/production_contract_test.dart` the contract.
- Changing a production value (a new API host, project or key format) is a
  reviewed change to the contract, the example file and this ADR.

## Verification (local)

Recorded in `docs/security/sec-001-containment.md` under "Release cutover
(REL-002, ADR-0044)".
