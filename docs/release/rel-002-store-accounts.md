# REL-002 store account and application identity record

Status: application identity **decided** 2026-09-11 (ADR-0015, DL-029). Store
account registration **open** — it is console work performed by the Account
Holder, not a repository change.

This record prepares store submission. It does **not** authorize a release, does
not remove any SEC-001 containment guard, and does not change application
behaviour. Submission remains blocked by Phases 3–10 of `instructions.md`; the
accounts prepared here are obtained early only because their verification lead
times are long.

## Scope

| This record does | This record does not |
|---|---|
| Fix the permanent bundle/application ID | Apply that ID to the build files |
| Prepare Apple and Google organisation enrolment | Register either account |
| Define credential custody for store artifacts | Generate any signing key |
| Resolve the identity half of `DL-015` | Close `DL-015` (signing and privacy manifests remain open) |

## 1. Application identity

| Field | Value |
|---|---|
| iOS bundle identifier | `io.studafy.app` |
| Android application ID | `io.studafy.app` |
| Android namespace | `io.studafy.app` |
| Display name | `Studafy` |
| Supported platforms | iOS and Android only (ADR-0003) |

**This identifier is permanent.** After the first publish to either store it
cannot be changed; a new identifier means a new app listing with no reviews,
ranking, or installed base.

`io.studafy.app` was chosen because it is already the OAuth redirect scheme in
every functional location, so adopting it costs no redirect changes:

| Location | Reference | Change needed |
|---|---|---|
| iOS URL scheme | `ios/Runner/Info.plist:20` | none |
| Android deep link | `android/app/src/main/AndroidManifest.xml:31` | none |
| Supabase auth callback | `supabase/config.toml:11` | none |
| Flutter redirect | `lib/features/session/data/supabase_session_repository.dart:30` | none |
| Setup instructions | `README.md:96` | none |

### Deferred to the REL-002 cutover

The identifier is decided but **not yet applied**. These edits happen last,
after the Phase 10 gate, per `instructions.md` §21.5:

| File | Current | Cutover change |
|---|---|---|
| `android/app/build.gradle.kts:18` | `namespace = "com.example.studafy"` | → `io.studafy.app` |
| `android/app/build.gradle.kts:29` | `applicationId = "com.example.studafy"` | → `io.studafy.app` |
| `android/app/build.gradle.kts:46` | debug `signingConfig` | → release config |
| `android/app/build.gradle.kts:9-15` | SEC-001 `GradleException` | delete |
| `ios/Runner.xcodeproj/project.pbxproj:402,583,605` | `com.example.studafy` | → `io.studafy.app` |
| `ios/Runner.xcodeproj/project.pbxproj:418,435,450` | `com.example.studafy.RunnerTests` | → `io.studafy.app.RunnerTests` |
| `ios/Runner.xcodeproj/project.pbxproj:155,239-252` | SEC-001 Release Block phase | delete |
| `android/app/src/main/AndroidManifest.xml:3` | `android:label="studafy"` | → `"Studafy"` |
| `ios/Runner/Info.plist` | `CFBundleName` = `studafy` | → `Studafy` |

Removing a guard requires a reviewed forward change referencing REL-002 and a
decision-log entry, per `docs/security/sec-001-containment.md`.

## 2. Gather before starting

Both registrations need the same underlying facts. Collect once.

| Item | Notes |
|---|---|
| Legal entity name | Must match the commercial registration **exactly**, character for character |
| Commercial registration (CR) number | Or equivalent incorporation document |
| Registered address | Must match the CR and the D-U-N-S record |
| D-U-N-S number | See §3.1 — obtain first |
| Legal entity website | Must be live and resolve to a domain associated with the entity |
| Support email | On the entity's domain, monitored; appears publicly on both listings |
| Account Holder | A person with legal authority to bind the entity |
| Phone number | Used for verification callbacks |
| Payment method | Corporate card in the entity's name |
| Privacy policy URL | Required by both consoles — see `instructions.md` §21.6 |

> Name and address mismatches between the CR, the D-U-N-S record, and the
> enrolment form are the most common cause of multi-week enrolment delays.
> Reconcile them before submitting anything.

## 3. Apple Developer Program — Organization

An Organization account publishes under the entity's name. An Individual
account publishes under a personal name, which is unsuitable for a product sold
to schools and creates a contractual problem with them.

### 3.1 D-U-N-S number

1. Check whether the entity already has one — many registered companies do.
2. If not, request one through Apple's free D-U-N-S lookup tool (do not pay a
   third party).
3. Allow **up to 5 business days** for issuance, longer for a correction.
4. Verify the returned legal name and address match the CR before proceeding.

### 3.2 Enrolment

1. Create an Apple ID for the entity — use a role address (not a personal
   mailbox), with two-factor authentication enabled.
2. Enrol at `developer.apple.com/programs/enroll` as an **Organization**.
3. Supply the D-U-N-S, legal entity name, website, and Account Holder details.
4. Apple verifies the entity and may call the listed phone number.
5. Pay the annual membership (~$99/yr). **Renewal is annual — a lapse removes
   the app from sale.** Set a calendar reminder.

Expect **1–4 weeks** end to end, dominated by verification.

### 3.3 Immediately after approval

| Step | Detail |
|---|---|
| Register the App ID | `io.studafy.app` in Certificates, Identifiers & Profiles |
| Enable Sign in with Apple | Guideline 4.8 makes it **mandatory** — the app already offers Google and Microsoft sign-in (`lib/features/session/domain/session_repository.dart:8`) |
| Create the Sign in with Apple key | Service ID, Key ID, Team ID, `.p8` — needed for Supabase Auth (`instructions.md` §22.5) |
| Reserve the app name | In App Store Connect; names are first-come and cannot be held indefinitely |
| Record the Team ID | Needed for `DEVELOPMENT_TEAM` at cutover |

## 4. Google Play Console — Organization

### 4.1 Enrolment

1. Create a Google account for the entity (role address, 2FA enabled).
2. Register at `play.google.com/console` as an **Organization**.
3. Pay the **$25 one-time** registration fee.
4. Supply D-U-N-S, legal entity details, and complete identity verification —
   Google requires verified contact details for organisation accounts.

Expect **days to several weeks**, again dominated by verification.

### 4.2 Play App Signing — enrol at first upload

Google holds the app signing key; the local keystore becomes only an *upload*
key.

> **Without Play App Signing, losing the upload keystore permanently ends your
> ability to update the app.** With it, an upload key can be reset by Google.
> Enrol. There is no good reason not to.

The keystore itself is generated at cutover by the Account Holder, not now —
see `instructions.md` §21.1.

### 4.3 Package name

The package name is fixed at **first upload**, not at listing creation, and
`com.example.*` is **refused outright** by Play. Ensure `io.studafy.app` is what
ships.

### 4.4 Closed testing

New developer accounts may face a closed-testing requirement — a cohort of
testers over a sustained period before production access is granted. This is
generally lighter for organisation accounts, and is a further reason to register
as one. Verify the current requirement in the console at registration time, as
this policy has changed repeatedly.

## 5. Credential custody

Each account produces artifacts that must never enter Git. Full register in
`instructions.md` §22.2.

| Artifact | Produced by | Custody |
|---|---|---|
| App Store Connect API key (`.p8`) | Apple | **Downloadable once.** Password manager + CI secret. Record Key ID and Issuer ID separately |
| Apple Distribution certificate (`.p12`) | Apple | Password manager + CI secret |
| Provisioning profile | Apple | CI secret |
| Sign in with Apple `.p8` | Apple | Password manager; configured in Supabase Auth |
| Play service account JSON | Google Cloud | CI secret; grant **Release manager** only |
| Android upload keystore | Generated at cutover | Password manager **and** an offline backup |

`.gitignore` already excludes `config/dart-defines.*.json`. Add
`android/key.properties` and `*.jks` before the cutover.

## 6. Sequencing

| Account unblocks | Still blocked by |
|---|---|
| App ID registration, Sign in with Apple credentials | — |
| App Store Connect record, name reservation | — |
| TestFlight distribution | Phases 3–10 (a functional, server-backed app) |
| Play internal testing track | Phases 3–10 |
| IAP product creation (`studafy_parent_insights_monthly`) | PAY-071, and legal approval of paid insights |
| Submission | Every gate in `instructions.md` §20 |

Obtaining the accounts does **not** shorten the engineering path. It removes the
verification wait from the critical path so it does not become the final delay.

## 7. Exit conditions

This record closes when all of the following hold:

- [ ] Apple Developer Program Organization account approved; Team ID recorded
- [ ] `io.studafy.app` App ID registered with Sign in with Apple enabled
- [ ] App Store Connect record created and the app name reserved
- [ ] Google Play Console Organization account approved and verified
- [ ] Play App Signing enrolment confirmed
- [ ] Account Holder and a backup admin named for both accounts
- [ ] Every credential in §5 stored per its custody rule
- [ ] Renewal reminder set for the Apple annual membership

Signing material, privacy manifests, and the native cutover remain open under
`DL-015` and are tracked by `instructions.md` §21.

## Related

- ADR-0015 — application identity and store accounts
- ADR-0003 — supported platforms (deferred identity to REL-002)
- DL-015 (deferred), DL-029 (identity decided)
- `docs/security/sec-001-containment.md` — the release guards this record must not remove
- `instructions.md` §21 (edit list), §22 (credential register), §23–§24 (rejection registers)
