# SEC-001 containment record

Status: repository and synthetic technical controls verified through
`202609090004` on 2026-09-10. The Phase 0A human gate remains open pending the
fresh dashboard-log/credential review and explicit security-owner approval in
the evidence log below.

This record covers only immediate containment. It does not approve a production
release and does not authorize real student, family, teacher, or school data.

**Release cutover, 2026-10-17 (REL-002, ADR-0044, DL-069).** The native
release blocks are replaced by the production defines contract
(`lib/core/production_contract.dart`): Android and iOS release builds run
for `APP_ENV=production` when the contract passes, and for `development`
(the test copy). The owner decided this before the production backend
exists; **no production build may be uploaded to either store until
`https://api.studafy.com` is live** (DL-069). What remains guarded is listed
under "Release-block rationale and removal record".

## Risk register and accountable roles

| Risk | Severity | Containment | Accountable role | Exit condition | Status |
|---|---:|---|---|---|---|
| Caller-selected private file could be signed and sent to the grading provider | Critical | Grading endpoint always returns `AI_GRADING_DISABLED`; former service-role signing code removed | Security owner | Server-owned immutable `file_object_id`, tenant/relationship authorization, clean scan state, and negative tests | **Closed by removal (AI-072, ADR-0026, 2026-09-18):** the grading function and every AI surface are deleted from the repository and, on 2026-09-18, from the synthetic project (both slugs 404; `docs/evidence/phase-7/README.md`) |
| Core production screens write to local-only SQLite state | Critical | Production runtime does not initialize the backend/database or expose application routes | Product owner | Server repositories and synchronization acceptance scenarios pass | **Replaced at the REL-002 cutover (2026-10-17, ADR-0044):** production uses the server repositories like development, and starts only when its compiled defines pass the production contract; otherwise it shows the readiness block. Local SQLite is used only by synthetic builds |
| Direct uploads lack metadata ownership, quarantine, malware scanning, and publication gates | High | Forward migration removes authenticated storage insert policy; mobile upload paths removed | Backend/data owner | Phase 5 file pipeline and RLS tests pass | Direct uploads stay removed. **Replaced by the FILE-050/051 pipeline**, on in production since 2026-10-17 (owner's approval, DL-070): upload intents with per-purpose type and size policy, quarantine, ClamAV scan through the private `studafy-scanner` before anyone can open a file, single-use delivery grants |
| Example identities and debug signing could reach a store build | High | Since the REL-002 cutover (ADR-0044): Android and iOS release builds run only for `APP_ENV=production` under the production defines contract or for `development` (the test copy); Android production is signed with the owner's upload key only, never the debug key | Mobile release owner | Final identities, signing, privacy manifests, and store checks pass under `REL-002` | **Blocks replaced 2026-10-17 (ADR-0044, DL-069)**; identity `com.studafy.light` (DL-058); refusals proved in CI by `.github/scripts/check-android-release-guard.sh` and `check-ios-release-guard.sh`. No production upload until `api.studafy.com` is live |
| Privileged workflows lack consistent validation, idempotency, transactions, and observability | High | Unsafe grading workflow disabled; other workflows remain prohibited from production release | Backend/security owner | Phase 3 service controls and negative tests pass | Broader remediation pending |
| Historical secrets cannot be inspected without repository history | High | Treat history inspection as an explicit gate; do not claim completion | Security owner | Original Git history is restored or the limitation is formally accepted with credential rotation | Formally bounded 2026-09-10: `docs/governance/git-history-boundary.md` |

Role ownership is used because named individuals and organization contacts are
not present in the repository. The human Phase 0A gate must map every role above
to a named person and record approval in the evidence log below. That mapping
was recorded on 2026-09-10: this is a single-owner project, so every
accountable role maps to the repository owner (GitHub `@yousefomar3003`) for
the synthetic phase. Creating any production or real-data environment requires
re-evidencing these rows with named, separated owners.

## Kill-switch registry

| Capability | Server/data control | Client/build control | Removal conditions |
|---|---|---|---|
| AI paper grading and Study Coach | **Removed by AI-072 (ADR-0026).** Both Edge Functions deleted; `ai_grading_drafts`, `question_suggestions` and `practice_sessions` have no grant or policy and refuse every write; the AI store products cannot be activated | AI screens, the `study_coach` slice and the teacher grading controls deleted; `allowsAiGrading => false` retained as a tripwire | Not a kill switch any more: a future AI capability needs a signed DPA, an extended DPIA, a new ADR and the full enable-path engineering in `docs/planning/instructions.md` §20 Part 7C |
| New private-file uploads | Storage insert policy dropped (direct uploads stay impossible); the `coach_attachment` purpose is retired by AI-072. Uploads go only through FILE-050/051, whose server switches are the kill switch: `FILE050_NEW_INTENTS_ENABLED=false` on the API stops new uploads, `FILE051_DELIVERY_ENABLED=false` stops downloads, `FILE051_SCAN_ENABLED=false` on the worker leaves every new file quarantined | Study Coach and its attachment control deleted by AI-072; direct upload code removed. `allowsRemoteFileUploads` is true in every environment since DL-070 (2026-10-17) | Met: ownership metadata, quotas, signature checks, quarantine, ClamAV scanning (`studafy-scanner`), metadata stripping, clean publication and tenant-negative tests (FILE-050/051, `docs/evidence/phase-5/`) |
| Production application | Production initializes the remote backend only (no SQLite) | Starts only when the compiled defines pass the production contract (`RuntimePolicy.blocksApplicationStartup`); otherwise the production-readiness screen | Removed as a block at the REL-002 cutover (ADR-0044); the contract check stays |
| Android/iOS release | Not applicable | Since the REL-002 cutover (ADR-0044): a release task or Xcode `Release` build runs only when every `APP_ENV` is `production` and the dart-defines pass `tools/check_release_defines.dart`, or every `APP_ENV` is `development`; Android also needs an upload key outside the repository, and production refuses the debug-key opt-in. Proved in CI by `.github/scripts/check-android-release-guard.sh` and `.github/scripts/check-ios-release-guard.sh` | Removed as a block 2026-10-17 (DL-069); the contract and signing checks stay. No production upload until `api.studafy.com` is live |
| Legacy meeting Edge Functions (`create-google-meet`, `cancel-google-meet`) | Both return stable `MEETINGS_DISABLED` 503s without reading the body, resolving recipients, using service credentials, or contacting a provider | Not applicable | API-042's `POST /v1/classrooms/{classroomId}/meetings` and `POST /v1/meetings/{meetingId}/cancel` pass authorization, transaction, idempotency and retry tests (`supabase/tests/api042_meetings.sql`, `apps/api/test/meetings`) and replace these functions in traffic |
| Legacy `request-account-deletion` Edge Function | Returns a stable `ACCOUNT_DELETION_PROTOTYPE_DISABLED` 503; its manual JWT-`iat` decode (the broken recent-auth check DL-032 documents) never runs | Not applicable | Already fully superseded by AUTH-030/031's `POST /v1/account/deletion-request`, which uses the real single-use hashed recent-auth grant instead |

There is intentionally no environment variable that re-enables grading or
direct (unscanned) uploads; the FILE-050/051 server switches only turn the
scanned pipeline on or off. A synthetic demonstration requiring either capability must use a
separate isolated project and a reviewed replacement implementation; the
contained path must not be restored.

`study-coach` was the counterexample to this rule: it forwarded lesson
material to whatever `STUDY_COACH_URL` named, gated only by that variable.
AI-072 (ADR-0026, DL-047) removed it rather than adding another gate, and no
AI or Study Coach variable exists in either `.env.example`.

## Configuration and secret handling

Flutter compile-time configuration is extractable from the application binary.
Only these non-secret values may be supplied through `--dart-define`:

- `APP_ENV`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

(and the other public values a production build may carry, which since the
REL-002 cutover are an enforced allowlist: `ProductionContract.allowedNames`
in `lib/core/production_contract.dart`; a production build with any other
define, or a value that looks like a server secret, is refused).

`SUPABASE_SERVICE_ROLE_KEY`, provider/API secret keys, signing credentials,
webhook secrets, database passwords, and encryption keys are server secrets.
Ignored `.env` files may hold synthetic local values. Deployed values must use
the Supabase/provider secret manager with environment separation and least
privilege. Never put server secrets in Flutter, source control, screenshots,
logs, issue trackers, or this evidence document.

The checked-in `.env.example` files contain names and placeholders only. API
routes and application behavior remain in code; an `.env` file is not a secure
production secret store.

## Credential and provider-log checklist

The security owner must complete this checklist for every known Supabase project
and AI provider before closing Phase 0A. Store evidence in the approved private
security system, not in this repository.

- Identify development, staging, synthetic, and production project identifiers.
- Confirm who can deploy Edge Functions, apply migrations, read storage, change
  secrets, view provider prompts/files, and access store-signing credentials.
- Remove unused accounts/tokens and require MFA where the provider supports it.
- Verify no AI Edge Function is deployed in any project: since AI-072
  (ADR-0026), `study-coach` and `propose-paper-grade` must return 404
  (`scripts/verify-synthetic-ai-removal.ts`).
- Apply `202609090003_contain_unsafe_uploads.sql` and confirm authenticated
  inserts into both `papers/` and `coach/` are denied.
- Apply `202609090004_lock_down_function_execute.sql`; confirm the five
  application SECURITY DEFINER helpers and `rls_auto_enable` deny anonymous
  RPC execution and future functions do not inherit an anon EXECUTE grant.
- Search function/storage/provider audit logs for grading calls, signed-object
  creation, unexpected object reads, repeated path guesses, and unknown actors.
- Record query range, environment, reviewer, result, evidence location, and any
  incident reference without copying personal data or credentials.
- Rotate affected credentials if exposure, unauthorized access, or uncertain
  custody is found; validate dependent services after rotation.
- Restore the original Git history and run historical secret scanning. If this
  cannot be done, keep the gap open or formally bound it and rotate credentials
  that could have existed in unavailable history.

## Suspected private-file disclosure response

1. Keep the grading endpoint and direct uploads disabled; verify deployed
   versions and block deployment access not needed by responders.
2. Preserve redacted function, storage, identity, and provider audit evidence.
3. Determine affected project, tenant, object identifiers, actors, timestamps,
   provider requests, and whether signed URLs were used. Do not download school
   content to an unmanaged device.
4. Revoke or rotate affected provider/deployment credentials using provider
   procedures. Do not broadly rotate unrelated keys without an impact plan.
5. Notify the security/privacy owner and follow the approved Saudi PDPL,
   contractual, school, and child-data incident process; qualified counsel
   decides notification obligations.
6. Add regression evidence and complete a reviewed post-incident record before
   any capability is reconsidered.

## Release-block rationale and removal record

Release is blocked because authenticated production use can still reach
local-only school records, package identities are examples, Android release is
debug-signed, iOS privacy declarations are incomplete, and the required tenant,
file, payment, and operational assurance suites do not exist. The native guards
are containment controls, not substitutes for fixing those findings.

Removing a guard requires a reviewed forward change referencing `REL-002` and
the relevant security evidence. Never disable a guard merely to create a store
artifact or demo with real data.

**Removal record (2026-10-17, ADR-0044, DL-069).** The owner removed the
native release blocks in the REL-002 cutover, before the production backend
exists. Removed: the Xcode `SEC-001 Release Block` phase (replaced by the
`Release Defines Check` phase), the Gradle refusal of `APP_ENV=production`,
and the unconditional refusal of production at app start. Still guarded:

- a production build must pass the production defines contract — production
  API, Supabase project and legal host, a publishable (never secret) key,
  Turnstile on, Sign in with Apple on iOS, allowlisted defines only, none
  repeated, a build number above 1 — at Gradle, at Xcode, in
  `scripts/release/build-store.sh`, and again when the app starts;
- staging, synthetic, a missing `APP_ENV` and mixed values are refused on
  both platforms;
- Android release signing needs the upload key outside the repository, and
  production refuses `STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE`;
- the filled `config/dart-defines.production.json` is git-ignored, and
  `build-store.sh` refuses it if tracked;
- AI grading stays removed (`allowsAiGrading` is a hard-false tripwire);
- uploads are guarded on the server, not by the app: since 2026-10-17
  (the owner's approval, DL-070) `allowsRemoteFileUploads` is true in
  production too, and every upload goes through FILE-050 upload intents
  (per-purpose type allowlist and size cap, server-chosen quarantine key,
  quotas) and FILE-051 (structural analysis plus the ClamAV scan through the
  private `studafy-scanner`, metadata stripping, publication, single-use
  delivery grants). Nothing is delivered before its scan passes, production
  refuses to scan without the scanner's URL and key, and the API's
  `FILE050_NEW_INTENTS_ENABLED` / `FILE051_PUBLISH_ENABLED` /
  `FILE051_DELIVERY_ENABLED` and the worker's `FILE051_SCAN_ENABLED` /
  `FILE050_CLEANUP_ENABLED` are the kill switches (pinned on by
  `scripts/fly-config.test.ts`);
- **no production build may be uploaded to any store track until
  `https://api.studafy.com` is live** and the DL-064 cutover steps are done.

## Local verification record

The repository implementation was checked locally on 2026-09-09:

- `flutter analyze`: passed with no issues.
- `flutter test`: all 22 tests passed, including runtime, widget, repository,
  source-containment, configuration, migration-structure, and release checks.
- Bun invocation of the Edge containment handlers: stable 503 codes and redacted
  structured events confirmed for grading and attachment attempts.
- Android `assembleRelease` dry run: failed at the expected `SEC-001` Gradle
  guard; no APK was produced.
- Xcode project loading: passed.
- iOS Release device build without signing: failed at the expected
  `SEC-001 Release Block`; no releasable archive was produced.

Deno and the pinned Supabase CLI were subsequently made available. The CLI's
`test db --linked` wrapper still required Docker, so the transactional pgTAP
file was executed through the authenticated Management API instead.

### Android internal testing (ADR-0042) — 2026-10-15

Local, on the owner's Mac, Flutter 3.47.1. A throwaway upload key in a
scratch folder outside the repository stood in for the owner's key; it was
never uploaded or committed.

- `.github/scripts/check-android-release-guard.sh`: production, staging, no
  `APP_ENV`, and development overridden by production were refused with the
  `SEC-001` message; a keystore inside the repository was refused; a
  development build passed SEC-001 and stopped at "Release signing: no
  upload key". About 1.5 minutes, no compilation.
- `STUDAFY_ANDROID_KEY_PROPERTIES=<scratch>/key.properties flutter build
  appbundle --release --dart-define-from-file=config/dart-defines.device.json`
  (`APP_ENV=development`, the Fly test API): built
  `app-release.aab`, 72.7 MB (72,736,801 bytes; arm64-v8a, armeabi-v7a,
  x86_64) in 10 minutes. `keytool -printcert -jarfile` showed the
  throwaway upload certificate, not the debug key.
- Launch plan 3.2: the bundle's base module, converted with
  `aapt2 convert --output-format binary`, and read with
  `aapt dump permissions`, lists `android.permission.INTERNET` (with
  RECORD_AUDIO, POST_NOTIFICATIONS, WAKE_LOCK, ACCESS_NETWORK_STATE,
  BILLING and C2DM RECEIVE). `aapt dump badging`: package
  `com.studafy.light`, label `Studafy`, versionCode 1 / 1.0.0, minSdk 24,
  targetSdk 36, not debuggable.
- `STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true` with no key: built, printed the
  "signed with the DEBUG key … Do not upload it" warning, signer
  `CN=Android Debug`.
- iOS: `flutter build ios --release --no-codesign
  --dart-define=APP_ENV=development` failed with "SEC-001: iOS archives and
  release builds are blocked"; the Xcode phase is unchanged.
- `flutter analyze`: no issues; `flutter test`: 800 passed;
  `dart format --set-exit-if-changed lib test`: no changes.

### Release cutover (REL-002, ADR-0044) — 2026-10-17

Local, on the owner's Mac, Flutter 3.47.1. A throwaway upload key in a
scratch folder outside the repository stood in for the owner's key; it was
never uploaded or committed. The publishable key in the production defines
was a made-up `sb_publishable_` placeholder of the right shape.

- `.github/scripts/check-android-release-guard.sh`: 12 cases. Staging, no
  `APP_ENV` and development overridden by production were refused
  (`REL-002: Android release builds must be …`). Production with no other
  defines, the unfilled example, production pointed at the test API, an
  unknown `DEMO_MODE` define, and production without a build number failed
  the contract. Production with `STUDAFY_ALLOW_DEBUG_SIGNED_RELEASE=true`
  and a keystore inside the repository were refused. A production build
  matching the contract, and a development build, both stopped only at
  "Release signing: no upload key". No compilation.
- `.github/scripts/check-ios-release-guard.sh`: 16 cases, run against the
  Xcode phase script with Xcode's environment. Debug and Profile were not
  checked. Release with no `APP_ENV`, staging, synthetic, or a development
  plus production mix was refused. Production failed the contract with
  missing values, the test API, a repeated define, Sign in with Apple off,
  build number 1, an unknown define, a secret-looking value, or broken
  `DART_DEFINES`. Production matching the contract passed, and so did
  development. No iOS archive was made (no signing available).
- `STUDAFY_ANDROID_KEY_PROPERTIES=<scratch>/key.properties
  scripts/release/build-store.sh android --build-number 2 --defines
  <scratch>/dart-defines.production.json`, with the example's two
  placeholders filled: `build-store.sh` printed "Release defines: production
  contract passed (android)". Gradle's release check then passed: the
  contract was re-run on Gradle's own dart-defines, and the throwaway upload
  key was accepted. The build then compiled the release. It failed in
  `compileReleaseJavaWithJavac` because a `flutter test` run started at the
  same time regenerated `GeneratedPluginRegistrant.java` with the
  `integration_test` dev plugin partway through; that is not related to
  this change. Only one Android release build was allowed, so it was not
  repeated. The unchanged path compiled and signed a bundle on 2026-10-15
  (ADR-0042 above).
- `flutter analyze`: no issues. `flutter test`: 979 passed.
  `dart format --set-exit-if-changed lib test tools`: no changes.
  `dart run tools/check_dart_bounds.dart`: passed. `shellcheck` on the four
  changed or new scripts: clean. `actionlint` on both workflows: the only
  finding is an existing SC2046 at the same step on `main`.
- `plutil -lint ios/Runner.xcodeproj/project.pbxproj`: OK.

### Synthetic deployment evidence — 2026-09-09

The tooling became available and the containment baseline was deployed only to
Supabase project `eamewgaptdfqzpmayavx` (`studafy light`):

- The linked project identity matched the authorized project before mutation.
- Remote migration history was empty and the dry-run listed exactly migrations
  `202609080001` through `202609090003`, with no seed or role files.
- All seven migrations applied successfully in order; a subsequent dry-run
  reported the remote database as up to date.
- Post-migration counts were zero for auth users, schools, profiles, and storage
  objects.
- Database lint reported no schema errors.
- The transactional containment SQL test confirmed that the upload policy is
  absent and an authenticated direct insert is denied.
- Deno containment tests passed: 4 tests, 0 failures.
- `propose-paper-grade` and `study-coach` are ACTIVE at version 1 with JWT
  verification enabled.
- A remote grading request returned `503 AI_GRADING_DISABLED`, included a
  request ID, and did not echo the substituted private path.

The pre-deployment schema dump did not run because Docker was not active. The
project was verified empty, so recovery remains project recreation or a new
forward migration; no backup is claimed.

Post-deployment advisors identified public/anonymous execute privileges on five
application-owned `SECURITY DEFINER` helpers: `is_school_member`,
`is_class_teacher`, `can_access_student`, `can_access_classroom`, and
`handle_new_auth_user`. Their current implementations derive identity from
`auth.uid()` or are trigger-only, and the project has no real data, but these
unnecessary privileges were removed by the forward-only
`202609090004_lock_down_function_execute.sql` migration on 2026-09-10. The same
migration removed direct anonymous/authenticated execution of platform-created
`public.rls_auto_enable()` without dropping or modifying its event trigger, and
removed the future anon/PUBLIC default function privilege. Local pgTAP and
remote schema/RPC negative evidence are recorded in
`docs/evidence/schema/privilege-lockdown-2026-09-10.md`. RLS performance
improvements remain later indexing/query-hardening work.

### Synthetic follow-up evidence — 2026-09-10

- Dry run listed exactly `202609090004_lock_down_function_execute.sql`; it was
  then applied to `eamewgaptdfqzpmayavx` only.
- Remote migration history is aligned through `202609090004`.
- Fresh schema evidence and anonymous RPC probes prove all six reviewed
  helpers deny anonymous execution.
- An authenticated ephemeral synthetic user tested Study Coach attachment and
  grading path substitution. Both returned their stable 503 codes with request
  IDs, no path echo, no signed URL/token, and no provider branch.
- Direct private-object access failed. The ephemeral user was deleted; remote
  auth-user and listed storage-object counts returned to zero.
- Full redacted evidence is in
  `docs/evidence/smoke/remote-authenticated-containment-2026-09-10.md`.

## Human evidence log

| Evidence | Named owner | Private evidence location | Result/exception | Approval |
|---|---|---|---|---|
| Authenticated grading and attachment substitution return stable 503s and no provider request occurs | Repository owner (GitHub `@yousefomar3003`) | `docs/evidence/smoke/remote-authenticated-containment-2026-09-10.md` | Passed 2026-09-10; request IDs recorded; no provider credentials exist | Technical pass; security-owner approval pending |
| Storage containment and function privilege migrations applied | Repository owner (GitHub `@yousefomar3003`) | `docs/evidence/schema/privilege-lockdown-2026-09-10.md`; pgTAP in CI | Eight migrations aligned; direct upload denied; all six anon RPC probes denied | Technical pass; security-owner approval pending |
| Provider/storage/function logs inspected | Repository owner (GitHub `@yousefomar3003`) | Supabase dashboard log explorer, synthetic project `eamewgaptdfqzpmayavx` only | CLI/API evidence proves zero remaining users/objects and no configured provider; a fresh dashboard log-range review after the 2026-09-10 probes is still required | **Pending human review** |
| Deployment and store credentials restricted | Repository owner (GitHub `@yousefomar3003`) | Owner credential custody; no store integration exists yet | Repository/GitHub contain no deployment secret; only Supabase system secret categories exist. Console sessions, MFA and unused credential revocation require owner review. No exposure requiring rotation was found. | **Pending human re-approval** |
| Original Git history scanned or limitation formally bounded | Repository owner (GitHub `@yousefomar3003`) | `docs/governance/git-history-boundary.md` | Original pre-baseline history is unrecoverable (owner confirmation 2026-09-10); all six currently available commits and the 323-file tracked/untracked source snapshot have zero gitleaks findings | Approved boundary 2026-09-10; new commits remain continuously scanned |
| Android release and iOS archive negative-build evidence | Repository owner (GitHub `@yousefomar3003`) | Local verification record above | Passed locally on 2026-09-09: both native Release guards fail the build as designed | Approved 2026-09-10 |
| AI-072 removal: no AI function, route, credential or data path remains | Repository owner (GitHub `@yousefomar3003`) prepared; security owner to review | `docs/evidence/phase-7/README.md` (security review and approval packet) | Technical pass 2026-09-18: both synthetic slugs 404, no AI secret, 772 local pgTAP assertions pass; remote migration promotion deferred | **Pending security-owner approval** |

Phase 0A gate disposition: technical containment now passes in the repository,
local disposable stack, and remote synthetic project. The gate remains open
until the named security owner performs the two pending human reviews above and
records explicit approval. No production or real-data environment is permitted.
