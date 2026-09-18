# SEC-001 containment record

Status: repository and synthetic technical controls verified through
`202609090004` on 2026-09-10. The Phase 0A human gate remains open pending the
fresh dashboard-log/credential review and explicit security-owner approval in
the evidence log below.

This record covers only immediate containment. It does not approve a production
release and does not authorize real student, family, teacher, or school data.

## Risk register and accountable roles

| Risk | Severity | Containment | Accountable role | Exit condition | Status |
|---|---:|---|---|---|---|
| Caller-selected private file could be signed and sent to the grading provider | Critical | Grading endpoint always returns `AI_GRADING_DISABLED`; former service-role signing code removed | Security owner | Server-owned immutable `file_object_id`, tenant/relationship authorization, clean scan state, and negative tests | **Closed by removal (AI-072, ADR-0026, 2026-09-18):** the grading function and every AI surface are deleted from the repository and, on 2026-09-18, from the synthetic project (both slugs 404; `docs/evidence/phase-7/README.md`) |
| Core production screens write to local-only SQLite state | Critical | Production runtime does not initialize the backend/database or expose application routes | Product owner | Server repositories and synchronization acceptance scenarios pass | Contained in app; release verification pending |
| Direct uploads lack metadata ownership, quarantine, malware scanning, and publication gates | High | Forward migration removes authenticated storage insert policy; mobile upload paths removed | Backend/data owner | Phase 5 file pipeline and RLS tests pass | Upload containment applied and tested; safe replacement pending |
| Example identities and debug signing could reach a store build | High | Android release and iOS Release/archive builds fail with `SEC-001` | Mobile release owner | Final identities, signing, privacy manifests, and store checks pass under `REL-002` | Release guards verified; REL-002 replacement pending |
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
| AI paper grading and Study Coach | **Removed by AI-072 (ADR-0026).** Both Edge Functions deleted; `ai_grading_drafts`, `question_suggestions` and `practice_sessions` have no grant or policy and refuse every write; the AI store products cannot be activated | AI screens, the `study_coach` slice and the teacher grading controls deleted; `allowsAiGrading => false` retained as a tripwire | Not a kill switch any more: a future AI capability needs a signed DPA, an extended DPIA, a new ADR and the full enable-path engineering in `instructions.md` §20 Part 7C |
| New private-file uploads | Storage insert policy dropped; the `coach_attachment` purpose is retired by AI-072 | Study Coach and its attachment control deleted by AI-072; direct upload code removed | Ownership metadata, quotas, signature checks, quarantine, scanning, sanitization rules, clean publication, and tenant-negative tests |
| Production application | No production backend/SQLite initialization and no feature routes | Production-readiness screen only | Core screens use server-backed repositories; offline synchronization, tenant isolation, and upgrade tests pass |
| Android/iOS release | Not applicable | Native Release/archive tasks exit with a `SEC-001` error | `REL-002` final identity, non-debug signing, privacy declarations, CI policy, and store-console evidence |
| Legacy meeting Edge Functions (`create-google-meet`, `cancel-google-meet`) | Both return stable `MEETINGS_DISABLED` 503s without reading the body, resolving recipients, using service credentials, or contacting a provider | Not applicable | API-042's `POST /v1/classrooms/{classroomId}/meetings` and `POST /v1/meetings/{meetingId}/cancel` pass authorization, transaction, idempotency and retry tests (`supabase/tests/api042_meetings.sql`, `apps/api/test/meetings`) and replace these functions in traffic |
| Legacy `request-account-deletion` Edge Function | Returns a stable `ACCOUNT_DELETION_PROTOTYPE_DISABLED` 503; its manual JWT-`iat` decode (the broken recent-auth check DL-032 documents) never runs | Not applicable | Already fully superseded by AUTH-030/031's `POST /v1/account/deletion-request`, which uses the real single-use hashed recent-auth grant instead |

There is intentionally no environment variable that re-enables grading or
uploads. A synthetic demonstration requiring either capability must use a
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

Phase 0A gate disposition: technical containment now passes in the repository,
local disposable stack, and remote synthetic project. The gate remains open
until the named security owner performs the two pending human reviews above and
records explicit approval. No production or real-data environment is permitted.
