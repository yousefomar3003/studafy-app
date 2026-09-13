# Whole-repository launch-readiness audit — 2026-09-13

## Verdict

**NO-GO for App Store, Google Play, beta users, or real school data.**

The repository has a strong local database-security foundation and effective
SEC-001 containment. It is not yet a functional production product: the public
API has no product routes, the worker has only a smoke queue, most mobile
journeys remain synthetic/local, and native release builds are intentionally
blocked.

This is not a recommendation to remove the guards. The correct next
engineering task remains AUTH-030, followed by AUTH-031 and the complete API
sequence in `instructions.md`.

## Scope and method

The audit inventoried the repository and reviewed every source/configuration
area: Flutter bootstrap, session, repositories, parent/teacher/student
presentation, SQLite modules, Bun API/worker/packages, Edge Functions,
migrations/tests/evidence, Android/iOS configuration, CI, secret exclusions and
the three planning documents. Generated/ignored build output was measured but
not treated as source code. Previously verified DB-020/DB-021 SQL evidence was
cross-checked rather than re-claiming a remote deployment.

No remote Supabase, Cloudflare, Apple, Google or production state was changed.

## Verified implementation state

| Area | Evidence | Status |
|---|---|---|
| SEC-001 | AI grade proposal always disabled; attachment paths rejected; remote uploads blocked; mobile/native production guards active | Effective containment; human Phase 0 gate still open |
| DB-020/DB-021 | Six migrations per part, public generated types, policy/grant matrices and 113 prior local pgTAP assertions | Implemented locally; independent review, PR and current main CI open |
| API | health/readiness/version only; all `/v1/*` returns `NOT_IMPLEMENTED` | Skeleton, not functional |
| Worker | one `smoke` queue/processor | Skeleton, not functional |
| Remote mobile | session and classroom reads exist; parent and teacher-dashboard adapters fail closed | Partial |
| Preview mobile | 94 direct SQLite calls across bounded legacy student and teacher modules; 98 including linking/account; hard-coded student ID `1` remains | Structurally bounded, but still prototype-only |
| Billing | visible purchase and restore controls, but a generic verifier is trusted and lifecycle states/webhooks/ledger are absent | Unsafe stub; sales blocked |
| Native | example identifiers, Android debug signing, missing release INTERNET permission, no iOS privacy manifest, default assets, release guards | Intentionally unshippable |
| CI | last successful main run is commit `5326e6e`; current feature branch is two commits ahead, pushed, with no PR | Current DB-021/plan not covered by main CI |

## Code-health measurements

| Measurement | Result |
|---|---:|
| `lib/student_features.dart` | 15-line compatibility barrel |
| Student presentation modules | 15 independent libraries; largest is 602 lines |
| Teacher compatibility root | 34 lines, but 14 legacy `part` modules retain 62 SQLite calls |
| Parent compatibility root | 47 lines over 12 `part` modules; map-shaped port remains transitional |
| Preview DB facade | 106 lines over six local-data modules |
| `StudafyDatabase.instance` occurrences | 121 total; 94 in student + legacy teacher UI |
| Map-shaped Dart declarations | 222; 60 remain across student presentation modules |
| Explicit localization lookups | 15 |
| Literal `Text` widgets | at least 251 |
| Explicit `Semantics` widgets | 1 |
| Repository disk footprint | about 4.0 GB; about 3.1 GB `build/`, 436 MB `.dart_tool/`, 4.3 MB Git objects |

The student monolith has now been replaced with independently compiled bounded
libraries and a regression-enforced responsibility budget. This completes the
structural extraction only. MOB-070 must still replace direct SQLite access and
map-shaped data with typed repository boundaries, then prove English/Arabic
parity, accessibility and cross-device behavior. Structural splitting alone is
not production completion.

## Critical functional and security gaps

| Severity | Gap | Evidence | Owning work |
|---|---|---|---|
| Critical | No product API | Empty `/v1` router | AUTH-030/031, API-040/041/042 |
| Critical | Most launch journeys are local-only | SQLite counts and unavailable remote repositories | API-041/042, MOB-070 |
| Critical | No production school operating flow | No provisioning/invite/admin/family backend or reviewer fixture | API-042 (added) |
| Critical | Messaging lacks report/block/moderation/safeguarding | Local message UI/schema only | SAFE-043 (added) |
| Critical | Billing trusts a generic verifier | `verify-store-purchase` and mutable legacy entitlement | PAY-071 |
| High | Prototype privileged functions remain | Wildcard CORS, weak body validation, service role, multi-write races, N+1 meetings, JWT-`iat` reauth | API-040/041/042; no production deployment |
| High | API logging lacks an approved redaction policy | Current Bun logger normalizes fields but does not recursively redact sensitive values; raw error messages can contain internal detail | API-040 structured allowlist/redaction tests and retention controls |
| High | OAuth callback is an unclaimed custom scheme | Android/iOS `io.studafy.app://login-callback`; `autoVerify` is attached to a non-HTTPS scheme | AUTH-030 claimed links and hijack tests |
| High | Mobile session storage is not explicitly Keychain/Keystore-backed | No secure-storage adapter/dependency | AUTH-030 |
| High | Localization/accessibility are incomplete | Counts above; no device acceptance suite | MOB-070 |
| High | Operational platform absent | no deployed origin/Cloudflare/managed Redis, real queues, SLOs, alerts/on-call or restore evidence | OPS-060/061, INFRA-080/081, OPS-090 |
| High | Legal/privacy decisions open | minors, Saudi PDPL/residency, retention, paid insights and processors unresolved | SEC-091 plus named legal owners |

## Configuration and secret posture

Values were not printed or copied into evidence.

- Ignored `.env`: all five keys currently needed by the local API/worker
  skeleton are set: `ENVIRONMENT`, `API_PORT`, `DATABASE_URL`, `REDIS_URL`, and
  `LOG_LEVEL`. They target local development services.
- Ignored `config/dart-defines.development.json`: `APP_ENV`, `SUPABASE_URL`, and
  `SUPABASE_PUBLISHABLE_KEY` are set; the URL identifies the authorized
  synthetic project `eamewgaptdfqzpmayavx`.
- `config/dart-defines.synthetic.json`, `android/key.properties`, production
  provider/signing/deployment credentials: absent, as expected at this phase.
- The tracked-sensitive-filename check passes. `.env*`, Dart define values,
  keystores, signing artifacts, provider plist/JSON files and private keys are
  ignored while sanitized examples remain trackable.

The local configuration is sufficient for contained development when Docker
services run. It is neither a production credential set nor a reason to add
future secrets early. Production secrets belong in phase-owned provider/CI
secret managers; service-role, database, Redis, AI, signing and webhook secrets
must never enter Flutter.

## Verification in this audit

| Check | Result |
|---|---|
| Bun frozen install, format, lint, typecheck and architecture bounds | Pass |
| Generated Dart client and public database type drift | Pass |
| Bun unit/integration tests with disposable Redis/Postgres | 51 pass, 0 fail |
| API/worker bundle builds and Bun high-severity dependency audit | Pass; no vulnerabilities reported |
| Deno format, lint, frozen type check and containment tests | Pass; 4 tests |
| Flutter format, boundary check and analysis | Pass; no source changes and no analyzer issues |
| Flutter tests | 58 pass, 0 fail, including the student architecture guard |
| Synthetic Android debug build | Pass |
| Android production app-bundle negative build | Expected failure with the SEC-001 release-block message |
| iOS archive negative build | Expected failure with the SEC-001 release-block message |
| Database lint | Pass; no schema errors |
| Database containment/RLS/DB-020/DB-021/grants | 113 pgTAP assertions pass |
| DB-020/DB-021 populated query-plan checks | Pass; worst measured DB-020 0.050 ms and DB-021 13.287 ms, under provisional local limits |
| Git history secret scan | 10 commits, no leaks found |
| Whole-directory secret scan | Five expected ignored/local findings: one Flutter publishable key and four disposable Supabase generated values; no production credential or tracked secret finding. Large compiled artifacts over 20 MB were skipped and are not source inputs. |

## Roadmap corrections made from this audit

1. Added API-042 for school provisioning, invitations, full role lifecycle,
   families, communications, meetings, notifications, accounts/support and a
   deterministic reviewer tenant.
2. Added SAFE-043 for in-app reporting/blocking, moderation and safeguarding.
3. Strengthened MOB-070 to include the student/legacy decomposition, typed UI,
   localization, accessibility, claimed links, push navigation and lifecycle
   recovery.
4. Corrected Google Play's current ordinary-app target floor to API 36 for
   submissions from 31 August 2026.
5. Corrected Apple login guidance: guideline 4.8 includes an education/
   enterprise existing-account exception; Studafy must implement Sign in with
   Apple or truthfully document and obtain acceptance of the exception.
6. Corrected the restore-purchase finding: the UI control exists, while the
   authoritative restore lifecycle is still unimplemented.
7. Corrected Google Families guidance so it depends on the honestly declared
   target ages; the student-facing product cannot be labelled adult-only to
   avoid policy.
8. Corrected branch/CI, recovery-command, disk-footprint and README claims.
9. Replaced speculative privacy-manifest reason codes and store-account calendar
   estimates with archive-derived evidence and live enrollment checks.

## Current official store-policy sources

- Apple App Review Guidelines (login, account deletion, UGC):
  <https://developer.apple.com/app-store/review/guidelines/>
- Apple privacy manifests and required-reason APIs:
  <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
- Google Play 2026 target API requirement:
  <https://developer.android.com/google/play/requirements/target-sdk>
- Google Play target audience and children:
  <https://support.google.com/googleplay/android-developer/answer/9867159>
- Google Play UGC moderation:
  <https://support.google.com/googleplay/android-developer/answer/12923286>
- Google Play account deletion:
  <https://support.google.com/googleplay/android-developer/answer/13327111>

Store policy is release-time input: repeat the live review immediately before
submission and reconcile declarations against the exact shipped binaries and
server behavior.

## Next gate

Before AUTH-030 is called complete:

1. Open a PR for the current feature branch and obtain green current CI.
2. Obtain the independent DB-021 review and close the inherited Phase 0/2 human
   gates without implying remote deployment.
3. Decide the school-provisioned/public-registration model and Apple login
   posture; provide OAuth sandbox setup without exposing secrets.
4. Implement AUTH-030 locally, preserving all release/upload/AI containment.
