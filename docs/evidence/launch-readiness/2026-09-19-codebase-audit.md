# Repository, roadmap, security and credential audit

Date: 2026-09-19. Scope: the current working tree, `prompts.md`, `instructions.md`, `inputs.md`, phase evidence, Flutter composition and feature adapters, API/auth/authorization/platform code, workers, database migrations/tests, configuration, native projects and CI.

**Verdict: substantial backend implementation exists, but the product is not ready for a real-school pilot, payments or production release. Missing credentials are only part of the remaining work.** The roadmap's opening status tables are stale. Conversely, the existence of routes and passing unit tests does not establish complete mobile workflows or safe billing.

This is a repository review with local verification, not an independent penetration-test certification. There are 744 tracked files, 53 migrations and 131 versioned route contracts at review time. External consoles, hosted legal documents, DNS, production secret managers and physical devices were not inspected. A value absent locally may exist in an external secret store; this report does not claim otherwise. No remote deployment, migration or store transaction was performed. The pre-existing `pubspec.lock` change was left in place.

## What has been built from prompts.md

“Implemented locally” below means code and local evidence exist; it does not close the prompt's external acceptance gates.

| Prompt | Current implementation | Remaining gap |
|---|---|---|
| A1 AUTH-030 | JWT/JWKS checks, session/device revocation, secure token storage, MFA enrollment, recent-auth grants, deletion impact/request/cancel, provider client code | All three OAuth providers disabled/unconfigured locally; actual identity-link verifier not injected; administrator MFA coverage incomplete; physical Apple/provider/link verification and deletion execution outstanding |
| A2 AUTH-031 | Permission catalogue, server-derived resource/tenant authorization, membership-version cache, API/RLS parity tests | Independent BOLA/BFLA review; review new billing and admin surfaces rather than relying on catalogue presence |
| A3 API-040 | Strict schemas, bounded requests, errors, security headers, timeouts, redacted logging, durable idempotency and SSRF helper | Billing bypasses durable completion; sensitive billing/webhook limiter rules are not connected |
| A4 API-041 | Academic APIs for classes, resources, assignments, assessments, attendance, grades and wellbeing; transactional SQL, audit/outbox and generated contracts; some mobile adapters | Complete role-specific mobile workflows and cross-device acceptance. Legacy screens still reference preview SQLite |
| A4b API-042 | School lifecycle, roster, invitations, family links, communications, meetings, notifications, account rights and support-access APIs | Parent/admin/mobile wiring; Calendar provider execution; export and deletion workers; full onboarding/offboarding E2E |
| A4c SAFE-043 | Reporting, blocks, moderation, content controls, holds and audited grants in API/SQL; tests and drill | Discoverable report/block/moderation mobile controls; named trained operators, independent review and response drill acceptance |
| A5 FILE-050 | Server-selected upload paths, owner/tenant/purpose binding, quotas, quarantine and completion checks | Local service-role configuration absent; remote mobile upload adapter remains unavailable |
| A6 FILE-051 | Structural scanning, image metadata stripping, external scanner adapter, publication, single-use reauthorizing delivery, dedupe, retention machinery | Real scanner integration/credential, approved retention, independent file testing, mobile wiring and reviewed activation. Structural validation alone is not malware scanning; image re-encoding and PDF CDR remain limited/deferred |
| A7 OPS-060 | Redis rate-limit primitives, namespace separation, cache versioning, production TLS/AUTH configuration checks | Correct billing/webhook classification; managed infrastructure/ACL/failover proof. Cache and queue allocation separation is not supplied by distinct runtime URLs |
| A8 OPS-061 | BullMQ outbox dispatch, in-app notification delivery, retries, durable dead letters and re-drive; billing queue added later | Six inventory queues remain `declared`: file-security, media-processing, meeting-operations, exports, search-index, retention-maintenance. File workers do run separately by DB polling; email/push/Calendar and general account retention execution remain missing |
| A9 MOB-070 | Typed session/classes/academic/notification slices; notification offline cache and mutation outbox | Major incomplete phase: parent and teacher-dashboard remote adapters unavailable; uploads unavailable; 21 direct SQLite references in legacy student code and 62 in legacy teacher code; remaining migration, Arabic/RTL/accessibility/device/offline acceptance |
| A10 PAY-071 | Catalogue, Apple/Google verifiers, ledger/entitlements, webhook routes, billing queue/reconciliation, partial Flutter billing client | Confirmed defects below; no real store certification; guardian beneficiary selection and student parental-gate purchase UI missing; Student Notebook purchase flow incomplete |
| A10b AI-072 | REMOVE path implemented: AI screens/functions/egress removed, products retired and SQL writes restricted | Recorded security-owner acceptance and migration promotion remain open. AI credentials are not missing launch requirements |
| A11 INFRA-080 | Dockerfiles and local Compose foundation | No completed production infrastructure, private network/origin controls, approved residency/region, managed services or recovery evidence |
| A12 INFRA-081 | Quality CI, dependency/secret scans and debug builds | Signed release/deployment pipeline, environment approvals, rollback and signing integration absent |
| A13 OPS-090 | Structured server logs and debug-only client telemetry | Production telemetry, SLO measurements, alerts, tracing, on-call and recovery drills absent |
| A14 SEC-091 | Threat models, local security controls and tests | Independent penetration/privacy review, open security fixes, named security/privacy/safeguarding owners, approved data processing/retention/residency decisions |
| A15 LAUNCH-100 | Synthetic fixtures, seed tooling and local evidence | Accepted migration rehearsal, real school pilot, role-by-role physical-device E2E and rollback evidence |
| A16 SCALE-101 | Planning and some query-plan evidence | Production capacity/failover/load evidence and progressive rollout |
| B1–B4 REL-002 | Identity/signing instructions and release containment | Both native IDs still `com.example.studafy`; Android release signing points at debug; release blocked on both platforms; no main-manifest INTERNET permission, completed app privacy manifest/branding/signing/version pipeline |
| B5–B6 | Legal-copy scaffolding and deletion request/cancel UI | Verified hosted privacy/terms/support URLs; executable deletion lifecycle, not just requests |
| B7 | Extensive RLS/grant lockdown | Supabase Data API still exposes `public`; Flutter consent still calls an RPC. Final posture and mobile dependency removal require review |
| C1–C3 | Submission/rollout checklists | Actual listings, declarations, signed binaries, reviewer access and staged rollout evidence |
| D1–D5 | Decisions/checklists partially documented | External account/domain/owner/legal/commercial inputs require owner verification; repository text is not evidence that a console account or signed agreement exists |

Primary implementation evidence: `lib/app/app_dependencies.dart`, `apps/api/src/index.ts`, `apps/worker/src/index.ts`, `apps/worker/src/platform/queueInventory.ts`, `supabase/migrations/`, `.github/workflows/ci.yml`, and phase evidence under `docs/evidence/`.

## Security and correctness findings

Severity describes risk if the affected feature is enabled. Existing production/mobile containment and billing's default-off switch limit current exposure. Preserve those controls until the corresponding fixes and acceptance checks pass.

### H1 — Restore bypasses parental-gate verification

`apps/api/src/billing/routes.ts:96` verifies the submitted parental challenge on purchase, but the restore handler at line 172 sets `parentalGateConfirmed = Boolean(body.parentalGate)` without verification. `private.billing_restore` falls through to `billing_submit_verification` for a transaction the server has not seen. That SQL trusts the normalized boolean when resolving student self-purchases.

**Reproduced locally:** with an injected successful store verifier and fake repository, `{token: "forged", answer: 0}` is rejected by purchase with 403, but accepted by restore with 200 and passed to the repository as `parentalGateConfirmed: true`. This proves the route bypass; it is not evidence of a real store purchase. A valid receipt and an enabled school self-purchase policy are still needed for an actual entitlement.

Fix: share verified gate processing across submit/restore, and add route-plus-database tests for invalid, absent, expired and replayed challenges on first-seen restores.

### H2 — Billing environment and product availability are not authoritative throughout

`apps/api/src/billing/routes.ts:270` and `:303` take the ledger environment from the request body instead of binding it to `deps.environment`. The production-configured route in the isolated reproduction passed `environment: synthetic` through to its repository. The Google verifier also discards the provider's `testPurchase` marker.

Separately, `supabase/migrations/202609180003_pay071_private_functions.sql:279` requires a product to be active but does not require `storefront_listed`; only the catalogue query checks that field. Parent Insights is active but unlisted outside synthetic. Hiding it in the catalogue does not prevent a direct verification request from granting it if a valid receipt exists.

Fix: derive/reject environment server-side, bind Apple/Google test/live status to the configured environment, separate eligibility to sell from entitlement restoration, and enforce the applicable product gate inside the authoritative command. Entitlement reads must have an intentional environment policy too; the current query is user-scoped without an environment filter.

Google documents the test marker in [SubscriptionPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2).

### H3 — Administrator MFA is implemented selectively

`apps/api/src/auth/middleware.ts` computes `mfaRequiredByPolicy`, but authentication itself does not deny an AAL1 administrator. `requireAal2()` only protects routes that explicitly install it. `apps/api/src/school-admin/routes.ts:114` adds recent-auth for close/suspend without an AAL2 requirement; ordinary membership/roster commands have no equivalent MFA gate. `private.is_school_admin` checks active membership, not assurance level. School-admin integration tests inject AAL1 actors and successfully execute privileged operations.

Fix: define and enforce a consistent privileged-operation MFA policy, including platform operators who may have no school membership. Test a correctly authenticated AAL1 admin against every privileged route. Do not count “MFA enrollment exists” as proof of enforcement.

### H4 — Subscription ownership is not bound consistently to the account/lineage

The verifiers do not expose/check Apple's `appAccountToken` or Google's external account identifiers, and the Flutter purchase call supplies no account binding. SQL submit checks ownership for the exact transaction ID, whereas restore checks original lineage. A different renewal transaction from an already claimed Apple lineage can therefore bypass the exact-transaction ownership lookup if its valid signed payload is presented by another eligible account.

Fix: bind store purchase initiation and verification to a server-controlled account identity, enforce ownership across the entire subscription lineage, and test receipt replay across two accounts and multiple renewals. Google recommends checking the purchase's account mapping in its [billing security guidance](https://developer.android.com/google/play/billing/security). This finding is source-derived; no live receipt replay was attempted.

### M1 — Successful billing mutations never complete durable idempotency

The purchase, restore and self-purchase-settings handlers set `idempotencyCompleted = true` (`apps/api/src/billing/routes.ts:141`, `:180`, `:218`), but their repository/SQL functions do not persist the reservation's response or receive its ID/generation. `apps/api/src/platform/idempotency.ts` then skips completion.

**Reproduced:** first restore 200; identical retry 409 `IDEMPOTENCY_IN_PROGRESS`; reservation remains `reserved`. The fake does not model lease expiry; in the real implementation the expired lease can eventually permit re-execution instead of returning the recorded response.

Fix: atomically complete the reservation with the mutation, as academic commands do. Add real database replay/concurrency tests for all billing commands.

### M2 — Sensitive billing and webhook limiter definitions are unused

`apps/api/src/platform/rate-limit/policies.ts:153` defines `billingPurchase` and `storeWebhook`, but `flowFor()` sends purchase/restore to ordinary `authenticatedApi`. Reproduced by calling that classifier. `/webhooks/apple` and `/webhooks/google` are outside the `/v1/*` edge limiter and the authenticated router (`apps/api/src/bootstrap/app.ts`). They retain global request limits and signature checks, but lack the declared traffic budgets.

Fix: install explicit webhook limiting and classify billing mutations into the intended sensitive, fail-closed policy. Test Redis outage and abusive verification traffic.

### M3 — Signing out does not wipe all of the user's offline caches

`lib/data/local_cache/session_cache_binder.dart:44` wipes only the immediately previous scope. Switching school closes the earlier file without deleting it. Sequence: user visits school A, switches to B, signs out; B is wiped, A remains. Direct account switching also preserves the departed account's file. File scoping helps isolation but does not meet the stated wipe-on-sign-out requirement.

Fix: keep a user-wide cache index and await wiping all relevant cache files/outboxes on sign-out, account removal and revocation; synchronize in-flight cache work with scope changes. Add a multi-school/account persistence test. Current SQLite payloads are plain text; also document OS backup/device-storage protection before caching more sensitive records.

### M4 — Offline conflict is incorrectly treated as success

`lib/data/local_cache/mutation_outbox_engine.dart:186` maps `IDEMPOTENCY_KEY_REUSED` to `MutationAlreadyApplied`, which marks the mutation done. The server emits that code for a **different request body using the same key**, not a successful replay (`apps/api/src/platform/idempotency.ts`). This can silently discard a rejected mutation.

Fix: surface the mismatch as a conflict/rejection. Successful replay is already a successful response with `Idempotency-Replayed`. Add a semantic client/server contract test.

### M5 — Account deletion/export and meeting requests lack completed executors

Deletion impact/request/cancel and export request/status exist; there is no complete account-deletion executor, export processor or Calendar/Meet processor registered. Meeting/export queue contracts are declarations. Credentials alone will not make these workflows finish.

The previously recorded deletion obstacle also remains: `public.audit_events.actor_id` uses `ON DELETE SET NULL`, while audit rows reject updates. Deleting an audited profile requires a deliberate retention/anonymization design, not simply calling delete. See `docs/evidence/phase-3/README.md` and the foundation/append-only migrations.

Fix: implement processors and durable completion/failure states, resolve retention/legal holds and referential actions with forward migrations, then prove a complete lifecycle using synthetic data.

### M6 — Identity linking cannot succeed in the real bootstrap

`apps/api/src/auth/routes.ts:310` depends on `verifyProviderIdentity`, but `apps/api/src/index.ts:135` does not supply it. It correctly refuses requests, but A1's account-linking capability remains incomplete even after OAuth secrets are provided.

Fix: supply a reviewed provider identity-verification/linking flow and test subject/account substitution and replay.

### Additional billing acceptance gaps

- `lib/data/subscription_service.dart` passes neither `beneficiaryStudentId` nor a parental-gate answer. Parent Insights requires a linked-child beneficiary in SQL; Student Notebook self-purchases require the gate. The current client cannot complete either model end to end.
- The entitlement API returns entitlements for the authenticated beneficiary. The parent client asks for its own Parent Insights entitlement, although the purchase model attaches it to the child. Add authorized child-scoped reads and selection.
- Existing-lineage restore returns success without applying the freshly verified state. Apple submit verifies a signed transaction but does not fetch current subscription state. Prove refund/revocation/grace recovery and out-of-order replay before enabling sales.
- The Apple wrapper imports unscoped `app-store-server-library@0.1.3`. Apple's current documented package is [`@apple/app-store-server-library`](https://github.com/apple/app-store-server-library-node). Reconcile the dependency with the maintained API and sandbox-test the actual Flutter verification payload. This is dependency/support drift, not a claim that the installed package is malicious.
- Billing has domain/worker tests but no dedicated Hono billing flow suite. That coverage gap explains why the above route defects survive the current green suite.

## Exact credential and configuration inventory

Inspected `.env`, `supabase/.env`, `config/dart-defines.development.json`, sanitized examples, configuration schemas and code consumers. Only names/statuses were recorded; no secret values are included.

### Present locally

| Configuration | Observed status |
|---|---|
| `DATABASE_URL`, `REDIS_URL`, `SUPABASE_URL` | Populated, localhost; Postgres and Redis exercised by the passing backend suite |
| `ENVIRONMENT`, `API_PORT`, `LOG_LEVEL`, AUTH tuning | Populated for development |
| Flutter `APP_ENV`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `STUDAFY_API_URL` | Populated for local development; publishable key is public configuration, not a server secret |
| `API_CURSOR_SIGNING_KEY` | Present but still a replacement placeholder; replace with a random local key before relying on cursor integrity |

The local env file also repeats `AUTH_DELETION_GRACE_DAYS`; remove the duplicate during configuration cleanup.

### Absent or placeholders locally, with existing code consumers

| Purpose | Exact names / required inputs | Destination and next step |
|---|---|---|
| Google OAuth | `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID`, `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` | Placeholders in ignored `supabase/.env`; configure matching provider callback, then enable Google in Supabase config |
| Microsoft OAuth | `SUPABASE_AUTH_EXTERNAL_AZURE_CLIENT_ID`, `SUPABASE_AUTH_EXTERNAL_AZURE_SECRET` | Placeholders in `supabase/.env`; configure app registration, redirect and expiry tracking, then enable Azure |
| Apple OAuth | `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID`, `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET`; Apple Team ID, Key ID, private key and bundle/service identity | Placeholders locally; complete provider/native configuration and physical-device verification |
| Cursor signing | `API_CURSOR_SIGNING_KEY` | Replace placeholder with a purpose-specific random key in the API environment |
| Rate-limit/cache key hashing | `RATE_LIMIT_HMAC_SIGNING_KEY` | Absent; development generates an ephemeral key, production requires a configured key |
| Private storage | `SUPABASE_SERVICE_ROLE_KEY` | Absent from root env; API/worker only. Obtain the local stack's own key for local pipeline testing; never add to Flutter |
| File delivery | `FILE051_DELIVERY_SIGNING_KEY`, `FILE051_DELIVERY_PUBLIC_BASE_URL` | Absent; separate signing key and correct externally reachable delivery origin |
| Malware provider | `MALWARE_SCANNER_URL`, `MALWARE_SCANNER_API_KEY` | Absent; choose/integrate provider, establish processing terms and prove verdict/error behavior |
| Parental challenge | `PARENTAL_GATE_SIGNING_KEY` | Absent; generate separately, after fixing the restore bypass |
| Apple billing | `APPLE_BUNDLE_ID`, `APPLE_ENVIRONMENT`, `APPLE_APP_APPLE_ID`, `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_ROOT_CERTIFICATES_BASE64` | Absent; API/worker secret configuration. IDs, environment and root certificates are configuration, not all secrets |
| Google billing | `GOOGLE_PACKAGE_NAME`, `GOOGLE_SERVICE_ACCOUNT_JSON`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PUBSUB_AUDIENCE` | Absent; configure service-account permissions, RTDN topic/subscription and authenticated push |
| Billing environment and activation | `PAY071_ENVIRONMENT`, `PAY071_BILLING_ENABLED`, worker `PAY071_RECONCILIATION_ENABLED` | Not configured in local env; billing defaults off. Keep off pending fixes and store tests |
| Queue/file activation | `OPS061_NOTIFICATIONS_ENABLED`, `FILE050_NEW_INTENTS_ENABLED`, `FILE050_CLEANUP_ENABLED`, `FILE051_DELIVERY_ENABLED`, `FILE051_PUBLISH_ENABLED`, `FILE051_SCAN_ENABLED`, `FILE051_RETENTION_ENABLED` | Not locally configured; default off. Flags are not credentials and must follow their release gates |

Provider callback distinctions matter: OAuth provider consoles point back to Supabase's `/auth/v1/callback`; Supabase's allowed app redirects then point to the app's HTTPS/custom callback. Do not replace one with the other. Claimed HTTPS links also need owned DNS/hosting, Apple association data and Android signing fingerprints.

### Later integrations / external inputs not established by this review

| Area | Still needed |
|---|---|
| Production stores | Separate approved Supabase environment, API/worker least-privilege database logins, server-only storage credential, managed Redis TLS/AUTH/private networking and secret rotation |
| Infrastructure | Approved region/provider, container-host deployment identity, domain/DNS, Cloudflare scoped token/zone/origin controls, backup/PITR and restore proof |
| Android release | Final registered app ID, upload keystore, alias/passwords, Play App Signing, upload service account and organization console access |
| iOS release | Final bundle ID, Team ID, distribution certificate/private key, provisioning profile and App Store Connect upload credentials |
| Store products | Configure the retained Parent Insights and Student Notebook products in both stores, environment matching, webhook URLs and sandbox accounts. AI products stay retired |
| Push | FCM server credentials/configuration and APNs provider configuration/signing material; delivery code and native integration are also missing |
| Email | Provider credential, verified sending domain and email delivery implementation |
| Calendar/Meet | Approved integration and delegated credentials/token-broker design plus a worker. The old `GOOGLE_TOKEN_BROKER_*` example entries are stale: the remaining meeting Edge Functions return containment responses |
| Telemetry | Error tracking/metrics/traces destination and credentials, scrubbing, retention and alert routing; a DSN alone is not observability |
| Governance | Named security/privacy/safeguarding/on-call owners; accepted legal/privacy/retention/residency and paid-insights decisions; public legal/support URLs and independent security sign-off |

Deploy/signing/runtime secrets belong in their respective approved CI/platform secret stores. Local testing should use disposable credentials. BullMQ has no separate API key. AI/Study Coach and the retired generic purchase-verifier credentials should not be obtained to complete the current product.

## Verification performed in this audit

| Check | Current result |
|---|---|
| `bun run typecheck` | Pass, all nine workspace packages |
| `bun run lint`, `bun run format:check` | Pass: 204 linted files, 227 formatted files |
| `bun run generate:check` | Pass after allowing the installed Dart SDK cache access |
| `bun run check:bounds` | Pass: 122 source files, zero violations; file boundary check also passes |
| `dart run tools/check_dart_bounds.dart` | Pass: 61 feature files, zero violations |
| `flutter analyze --no-pub` | No issues |
| `flutter test --no-pub --concurrency=1` | 150 pass |
| Backend tests with localhost Postgres/Redis | 520 pass, 1 storage integration test skipped, 0 fail |
| `deno test --frozen=true` | 1 pass |
| 25 pgTAP entry points against existing local DB | 22 suites pass; 3 fail/abort, detailed below. Not a clean migration replay |
| Isolated billing route reproduction | Confirms forged restore gate accepted, caller environment forwarded, durable idempotency not completed, and ordinary limiter classification |
| Gitleaks across all local Git history | 83 commits scanned; no findings |
| Gitleaks working-directory scan | Five detections, confined to ignored local Flutter publishable config and generated local Supabase runtime env files. No finding establishes a committed production secret; large build artifacts were skipped |
| `bun audit --audit-level high` | No vulnerabilities reported by the registry |
| OSV scan of `pubspec.lock` and `bun.lock` | No vulnerabilities reported; 148 Dart and 142 Bun packages inspected |

The pgTAP failures were fixture-related on the existing, already-populated local stack: `db021_access_seed.sql` expected two roster members and saw three; `ops061_outbox_seed.sql` expected four staff deliveries and saw five; `db020_constraints.sql` hit an existing assignment primary key. The run used a batched ordering, not the clean CI replay sequence. It produced 696 assertions, with five assertion failures and an aborted 31-test plan after six assertions. These results do **not** establish a tenant-isolation bug or replace the need to rerun in a newly isolated stack using CI order. No existing database was reset to make the audit green.

The storage skip means this audit did not freshly prove the full signed-upload/scanner/delivery lifecycle. Real OAuth, real billing, physical devices, production networking and deployment remain unverified. Passing dependency scans do not prove the absence of vulnerabilities.

## Documentation corrections needed

- `README.md` still describes an empty `/v1` router, prototype billing and JWT-issuance-based deletion despite later implementations.
- `instructions.md` §1 marks authentication unstarted, APIs skeletal and queues smoke-only. Treat its design requirements as requirements, not its opening table as current evidence.
- `prompts.md` A9's 94 student/teacher SQLite references are outdated; current literal count is 83 across those two legacy directories. That is progress, not completion.
- `docs/security/credentials-map.md` says only Google/Microsoft are needed today and refers to deleting a billing stub. It now omits credentials for existing scanner/file/billing implementations.
- Older phase evidence contains historical open items later completed; PAY-071 still discusses four store products, while AI-072 retired two. A single up-to-date acceptance matrix is needed.
- Evidence recorded on 2026-09-18 says the remote synthetic project had 45 pending migrations. That is historical evidence, not a current remote check; local code must not be assumed deployed there.

## Recommended work order

1. Fix the billing trust, parental-gate, ownership, idempotency and limiter defects; add real route/database negative and replay tests. Apply consistent privileged MFA and fix offline cache/conflict handling.
2. Complete MOB-070 by role/feature: parent and guardian links, teacher operations, student workflows, school-admin operations, report/block/moderation and uploads. Finish child-beneficiary billing access/purchase UI.
3. Implement Calendar/Meet, export, deletion, push/email and retention completion. Connect real scanner/provider sandboxes and configure the matching credentials as each integration is ready.
4. Run a clean isolated migration/test replay plus full storage, auth, billing and physical-device E2E. Close independent security/privacy/safeguarding reviews and external decisions.
5. Complete infrastructure/telemetry/recovery and signed CI/CD. Apply native identity/release cutover and remove only the specifically approved containment guards after those gates close.

Adding credentials or changing the native app ID alone cannot make this codebase launch-ready.

## Remediation status (later on 2026-09-19)

Work done after this audit, all local and uncommitted, verified against the local stack. Decisions are DL-048 to DL-054.

| Finding or gap | Status |
|---|---|
| H1 restore bypasses the parental gate | Fixed, and the arithmetic gate is replaced by guardian approval behind recent-auth (DL-048) |
| H2 environment and storefront gate | Fixed; environment is server-derived, test purchases refused in production, first-seen receipts cannot bypass `storefront_listed` |
| H3 administrator MFA | Fixed; privileged and administrator permissions require AAL2 except MFA-bootstrap account controls |
| H4 subscription ownership | Fixed; receipts bind to a server-issued account token and lineage ownership is serialized in SQL |
| M1 billing idempotency | Fixed; completion is atomic with the mutation |
| M2 billing and webhook limits | Fixed |
| M3 sign-out cache wipe | Fixed, and a self-deadlock in the new open path found and fixed |
| M4 conflict treated as success | Fixed |
| M5 deletion, export and meeting executors | Built (DL-051, DL-052); off by default |
| M6 identity linking | Open |
| New: `store_transactions` updates always raised | Found and fixed; refunds and acknowledgements now record (DL-048) |
| New: private messages broadcast to all staff with their text | Found and fixed; contact policy and messaging switch enforced (DL-049) |
| Report and block controls in the app | Built for all roles (DL-049) |
| Parent, student and teacher real-build screens | Parent and teacher homes on /v1 data; account screen with sign-out, deletion and data download for every role (DL-050, DL-051) |
| Push and email | Server delivery built (DL-053); app-side push token needs Firebase |
| Signed release pipeline | Artifacts, SBOM, provenance and migration gate built; no deployment (DL-054) |
| Infrastructure (INFRA-080) and native release (REL-002) | Not started: ADR-0005 is Deferred and the REL-002 preconditions are unmet |
