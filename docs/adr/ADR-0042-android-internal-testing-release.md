# ADR-0042: Android release builds for internal testing of the test copy

- Status: Proposed — needs the owner's approval, because it changes the
  SEC-001 release guards
- Date: 2026-10-15
- Decision owner: repository owner
- Decision log: DL-059
- Relates to: SEC-001 (`docs/security/sec-001-containment.md`), ADR-0003
  (platforms), ADR-0004 (environments), ADR-0015 and DL-058 (app ID
  `com.studafy.light`); launch plan items 3.2, 3.3, 3.5 and 7.3
  (`docs/planning/launch-work-plan.md`)

## Context

SEC-001 blocks every native release build: a Gradle task-graph check throws
for any task named `*release*`, and an Xcode build phase fails the iOS
`Release` configuration. The guards exist so that no store build can carry
example identities, debug signing, or a production app that is not ready.
REL-002 (launch plan 7.3) removes them in one reviewed change once every
launch item has passed.

Internal testing on Google Play needs a release bundle well before that:
Play accepts only release-signed `.aab` files, and the testers' build is
also the first proof of the release manifest (3.2), the upload key (3.3)
and Google sign-in with the Play signing certificate (3.4). Those testers
use the hosted test copy (`APP_ENV=development`, the Fly test API), not
production, which does not exist yet.

The app ID is settled (`com.studafy.light`, DL-058), INTERNET is in the main
manifest (3.2), and a production app still refuses to start
(`RuntimePolicy.blocksApplicationStartup`). The remaining SEC-001 reasons for
blocking an Android release of the **test copy** are debug signing and the
risk of a production build; both can be handled without removing the guard.

## Decision

**Narrow the Android guard; do not remove it.** `android/app/build.gradle.kts`
still refuses any release task unless every `APP_ENV` in the dart-defines the
Flutter tool passes to Gradle (`-Pdart-defines`, which carries both
`--dart-define` and `--dart-define-from-file` values) is exactly
`development`. Refused:

- `APP_ENV=production` and `staging`;
- no `APP_ENV` (the app reads that as `synthetic`), including a bare
  `./gradlew bundleRelease` without the Flutter tool;
- any second `APP_ENV` that is not `development`, so a later
  `--dart-define=APP_ENV=production` cannot slip past an earlier one.

The allowed value is a single constant (`sec001ReleaseAppEnv`). Widening it
to staging or production is a reviewed change; production is REL-002's.

**Sign with the upload key, or fail.** Release signing reads a
`key.properties` file named by `STUDAFY_ANDROID_KEY_PROPERTIES` (or, failing
that, the git-ignored `android/key.properties`) with `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`. A relative `storeFile` is
resolved from the properties file's folder. The build fails if the file is
named but missing, a field is missing, the keystore is missing, or the
keystore is inside the repository. With no key configured the release build
**fails** rather than falling back to the debug key: Play refuses
debug-signed bundles, so a fallback would only produce an artifact that
looks shippable and is not. `STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true` signs
with the debug key for a local check that the release build compiles, with a
warning; that bundle must never be uploaded.

**iOS is unchanged.** The Xcode `SEC-001 Release Block` phase still fails
every `Release` build, whatever the environment. TestFlight waits for the
Apple account (launch plan 5.x) and its own reviewed change.

**Production is unchanged.** `APP_ENV=production` still blocks startup in the
app, and Gradle refuses to build it.

## Consequences

- `flutter build appbundle --release --dart-define-from-file=config/dart-defines.device.json`
  builds the test copy for Play internal testing once the owner's upload key
  is configured (launch plan 3.3, C1).
- The SEC-001 kill-switch row for Android release now reads "release of the
  development test copy only, upload-key signed"; REL-002 still removes the
  guard for production.
- `.github/scripts/check-android-release-guard.sh` runs the guard in CI (the
  Android job, and the tag-triggered release-artifacts workflow): production,
  staging, no `APP_ENV`, a production override, and a keystore inside the
  repository are refused, and a development build passes SEC-001 and stops
  only because CI holds no upload key. CI never builds or signs a release.
- `test/architecture/release_containment_test.dart` pins the single allowed
  value, the no-silent-debug-signing rule, the ignore rules for signing
  material, and the unconditional iOS block.
- The upload keystore and its passwords stay with the owner (password manager
  and an offline backup). Play App Signing holds the app signing key, so a
  lost upload key can be reset.

## Building the internal-testing bundle

1. The owner creates the upload keystore outside the repository, for
   example `~/studafy-signing/upload.jks`, and backs it and its password up.
2. Next to it, `~/studafy-signing/key.properties`:

   ```properties
   storeFile=upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

3. Build:

   ```sh
   STUDAFY_ANDROID_KEY_PROPERTIES=~/studafy-signing/key.properties \
     flutter build appbundle --release \
     --dart-define-from-file=config/dart-defines.device.json
   ```

   The bundle is `build/app/outputs/bundle/release/app-release.aab`.
   `keytool -printcert -jarfile` on it shows the upload certificate.

## Verification (2026-10-15, local)

Recorded in `docs/security/sec-001-containment.md` under "Android internal
testing (ADR-0042)".
