# SEC-001 containment record

Status: repository controls implemented; synthetic deployment evidence recorded
2026-09-09; Phase 0A human gate approved 2026-09-10 (see evidence log).

This record covers only immediate containment. It does not approve a production
release and does not authorize real student, family, teacher, or school data.

## Risk register and accountable roles

| Risk | Severity | Containment | Accountable role | Exit condition | Status |
|---|---:|---|---|---|---|
| Caller-selected private file could be signed and sent to the grading provider | Critical | Grading endpoint always returns `AI_GRADING_DISABLED`; former service-role signing code removed | Security owner | Server-owned immutable `file_object_id`, tenant/relationship authorization, clean scan state, and negative tests | Repository-contained; deployed verification pending |
| Core production screens write to local-only SQLite state | Critical | Production runtime does not initialize the backend/database or expose application routes | Product owner | Server repositories and synchronization acceptance scenarios pass | Contained in app; release verification pending |
| Direct uploads lack metadata ownership, quarantine, malware scanning, and publication gates | High | Forward migration removes authenticated storage insert policy; mobile upload paths removed | Backend/data owner | Phase 5 file pipeline and RLS tests pass | Migration created; application pending |
| Example identities and debug signing could reach a store build | High | Android release and iOS Release/archive builds fail with `SEC-001` | Mobile release owner | Final identities, signing, privacy manifests, and store checks pass under `REL-002` | Repository-contained; store credential restriction pending |
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
| AI paper grading | `propose-paper-grade` returns stable 503 without reading the body, using service credentials, signing a path, or contacting a provider | Upload and generation controls disabled; production repository always throws | Phase 5 clean immutable file objects plus Phase 7 grading authorization, transaction, idempotency, and contract tests |
| New private-file uploads | Storage insert policy dropped; Study Coach rejects `attachment_path` | Study Coach attachment control disabled and upload code removed | Ownership metadata, quotas, signature checks, quarantine, scanning, sanitization rules, clean publication, and tenant-negative tests |
| Production application | No production backend/SQLite initialization and no feature routes | Production-readiness screen only | Core screens use server-backed repositories; offline synchronization, tenant isolation, and upgrade tests pass |
| Android/iOS release | Not applicable | Native Release/archive tasks exit with a `SEC-001` error | `REL-002` final identity, non-debug signing, privacy declarations, CI policy, and store-console evidence |

There is intentionally no environment variable that re-enables grading or
uploads. A synthetic demonstration requiring either capability must use a
separate isolated project and a reviewed replacement implementation; the
contained path must not be restored.

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
- Verify the contained grading function version is deployed in every project.
- Apply `202609090003_contain_unsafe_uploads.sql` and confirm authenticated
  inserts into both `papers/` and `coach/` are denied.
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
unnecessary privileges must be removed in a new forward migration before any
non-synthetic use. The advisor also reported RLS performance improvements that
belong to the later indexing/query-hardening work. A separate platform-created
`public.rls_auto_enable()` warning requires Supabase-specific review rather than
an unreviewed privilege change.

## Human evidence log

| Evidence | Named owner | Private evidence location | Result/exception | Approval |
|---|---|---|---|---|
| Deployed grading endpoint returns stable 503 and no provider request occurs | Repository owner (GitHub `@yousefomar3003`) | CLI evidence in "Synthetic deployment evidence — 2026-09-09"; Supabase log explorer for project `eamewgaptdfqzpmayavx` | Endpoint passed on 2026-09-09 (stable 503, request ID, no path echo). No grading-provider credentials are configured in any environment, so no provider request can occur. | Approved 2026-09-10 |
| Storage containment migration applied and direct inserts denied | Repository owner (GitHub `@yousefomar3003`) | CLI evidence above; `supabase/tests/containment.sql` re-runnable in CI from clean environments | Passed in the synthetic project on 2026-09-09 | Approved 2026-09-10 |
| Provider/storage/function logs inspected | Repository owner (GitHub `@yousefomar3003`) | Supabase dashboard log explorer, synthetic project `eamewgaptdfqzpmayavx` only | Synthetic-project scope only: the project has zero auth users, schools, profiles, and storage objects, and observed traffic is limited to contained smoke requests. No production project exists to inspect. | Approved 2026-09-10 (synthetic scope) |
| Deployment and store credentials restricted | Repository owner (GitHub `@yousefomar3003`) | Owner credential custody; no store integration exists yet | No App Store Connect or Google Play Console products, signing identities, or store credentials exist yet (`studafy_parent_insights_monthly` is planned only). Deployment access is limited to the owner's Supabase and GitHub accounts; MFA and unused-account review are owner-attested. | Approved 2026-09-10 |
| Original Git history scanned or limitation formally bounded | Repository owner (GitHub `@yousefomar3003`) | `docs/governance/git-history-boundary.md` | Original history is unrecoverable (owner confirmation 2026-09-10); scanning is formally bounded to the two-commit baseline, which gitleaks scans in full | Approved 2026-09-10 |
| Android release and iOS archive negative-build evidence | Repository owner (GitHub `@yousefomar3003`) | Local verification record above | Passed locally on 2026-09-09: both native Release guards fail the build as designed | Approved 2026-09-10 |

Phase 0A gate disposition: all rows are assigned and approved on 2026-09-10 by
the accountable repository owner, permitting Phase 0B to start. Rows marked
synthetic-scope must be re-evidenced before any production or real-data
environment is used, and re-approval is required if containment controls change.
