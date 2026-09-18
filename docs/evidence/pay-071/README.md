# Phase 7, Part 7B (PAY-071) — store billing and entitlement lifecycle

Date: 2026-09-18 · ADR-0009 · DL-036 (beneficiary model), DL-012 (purchaser/beneficiary
rules) · Gateway: §21.8 (`instructions.md:1704`) ·
Disclosures: `docs/release/subscription-disclosure-requirements.md`

## Scope executed

1. **Server-authoritative catalogue.** The billing Hono module
   (`apps/api/src/billing/routes.ts`) serves `/v1/billing/catalogue` with the
   four-product store catalogue (Parent Insights, Student Notebook, Student
   AI, Teacher AI grading) filtered by platform, plus per-school
   self-purchase switches (default off). `student_ai` / `teacher_ai_grading`
   are never returned until AI-072 resolves (ADR-0009 §29). The route surface
   is registered in the authorization/permission catalogue, so every new
   endpoint is covered by policy and the parity drift tests.
2. **Store truth verification, one place only.** The legacy
   `supabase/functions/verify-store-purchase` Edge Function was deleted. Apple
   (App Store Server API status/notification verification + JWS checks,
   bundle-id/environment trust) and Google (Android Publisher API subscription
   verification + package-name trust) live in `packages/infrastructure/src/billing`
   and are reused by the API and the worker. No raw receipt/receipt-like data
   is logged (§21.5).
3. **Transactional ledger + entitlement derivation.** `202609180001` schema
   onward: `store_products`, `store_transactions` (purchaser and beneficiary
   modelled separately, ADR-0009), `store_events`, and derived `billing_entitlements`
   from the last verified state (grant/grace/expired/revoked/refunded).
   Idempotency keys dedupe resubmits; `store_events` is the durable webhook/recovery
   inbox.
4. **Store webhooks.** `apps/api/src/billing/webhookRoutes.ts` receives Apple
   Server Notifications V2 and Google RTDN, records `store_events`, and
   enqueues worker jobs. Signatures/authenticity are validated before any
   ledger write.
5. **Worker drain + reconciliation.** The `billing-events` BullMQ queue
   (`apps/worker/src/billing/`) claims `store_events` rows, re-verifies against
   the store, converges the ledger, acknowledges the platform, and
   dead-letters terminal failures in the database. `billingDispatch.ts`
   derives deterministic job ids from event ids; `reconciliation.ts` re-verifies
   live/expired transactions when enabled (`PAY071_RECONCILIATION_ENABLED`).
6. **Flutter client cutover.** `StoreSubscriptionRepository` (`lib/data/subscription_service.dart`)
   drives purchases through the `/v1/billing` client (`lib/data/billing/v1_billing_api.dart`),
   submits only store-signed verification payloads under a deterministic
   idempotency key (`pay071:<purchaseId>`), completes locally only after the
   server verifies (§13), and serves entitlements from the server.
   `lib/data/billing/store_offer_details.dart` renders the paywall price,
   period and trial **from the store product query, never hardcoded**
   (Apple 3.1.2) for both keepers. The paywall in `parent_insights.dart`
   shows the disclosure set: product title, auto-renewal, cancel path,
   store-payment statement, trial block (charge/cancel-window copy), Terms/
   Privacy links (dart-define host, non-navigable when unset), restore, and
   the free-records note.
7. **Environment gates.** `PAY071_BILLING_ENABLED=false` by default; billing
   environment is derived from the runtime policy (`billingEnvironmentName`);
   the synthetic (preview) policy runs with no billing API.

## Environment

- Worker/domain/contracts/infrastructure suites run with `bun`; no local
  Postgres or Redis was available for this run.
- SQL was verified by replaying `202609180001..006` on a disposable
  `postgres:16-alpine` container (`pay071-sqlcheck`, port 55432) with a
  functional worker-role drain test; the `202609180006` reconciliation query
  was reworked after the replay surfaced an income-tie ambiguity
  (`v_effective_until` now drives convergence).
- Flutter changes cannot be compiled here (no dart/flutter in this build
  environment); they were reviewed against the pinned plugin sources
  (`in_app_purchase` 3.3.0 / platform interface 1.4.1 / Android 0.5.3 /
  StoreKit 0.4.12) but a `flutter analyze`/build pass is still required.
  The OpenAPI-spec-generated Dart client cannot be regenerated locally (dart
  formatter step), so `/v1/billing` is served by a hand-written client over
  the same `V1JsonTransport` (one HTTP path, one idempotency policy).

## Verification transcript

| Suite | Result |
|---|---|
| `bun run --filter='@studafy/*' typecheck` | 0 errors (9 packages) |
| `bun test packages/domain/test/billing.test.ts` | 24 pass / 0 fail — Apple notification/transaction→state mapping + trust (bundle/environment), Google subscription state mapping + package trust, parental gate (correct answer, token can't be fabricated, wrong/expired/tampered rejected) |
| `bun test apps/worker/test/billing.test.ts` | 26 pass / 0 fail — job-id derivation, billing-events processor (Google RTDN verify+ack, noop test notifications, Apple sandbox never production, refund/revoke, unknown-origin retries, dead-letter terminal failures), dispatcher (deterministic ids, idempotent re-enqueue, dead-letter, bounded release), reconciliation (ack/without-ack convergence, untrusted status never converges, school-platform ignored) |
| `bun test apps/worker/test` | 48 pass / 3 fail — the 3 failures are the pre-existing Redis-dependent suites (`worker smoke queue lifecycle`, `OPS-061 notifications queue`) asserting against no local Redis (ECONNREFUSED 127.0.0.1:6379) |
| `bun test apps/api/test/authorization/catalogue.test.ts` | 6 pass / 0 fail — billing routes mounted and asserted against the permission catalogue parity |
| SQL replay + drain (container) | migrations `202609180001..006` replay clean; worker-role drain exercises reconcile convergence |
| `supabase/functions/verify-store-purchase` | deleted; env vars retired from `.env.example` |

## Acceptance criteria (per `instructions.md:1287`)

Status: **implemented, not yet store-certified.** Store-certification sandbox
evidence, guardian-purchase-for-linked-child, student self-purchase switch
behaviour, and parental-gate client wiring are explicitly **open gates**
(store accounts, constants, and API-042 linked-child purchase flows are
Phase 7 dependencies; the local environment cannot produce store sandbox
transactions).

- **Entitlements match authoritative store lifecycle** — implemented in
  domain mapping + worker converge/reconcile; sandbox proof per product and
  per device restore requires the conditions below.
- **No in-app payment form exists** — the app carries no card/Apple Pay/
  Google Pay form (§23.5); payment stays in the stores.
- **Every paywall shows the §3.1.2 disclosure set** — parent Insights paywall
  renders the full set, with price/trial taken from the store query, and
  degrades to neutral wording (store-confirmed price line) when the store
  query fails rather than inventing one. Student/teacher AI paywalls remain
  gated by AI-072.

## Open gates (recorded, not silently skipped)

1. **Store sandbox end-to-end per product** — Apple/Google accounts, products
   (`studafy_parent_insights_monthly` + the other three), and signing
   credentials are not present here. Required before the PAY-071 acceptance
   answer can close.
2. **Parental-gate client flow** — the server-side gate and signing key are
   implemented and unit-tested; the Flutter purchase path does not yet
   surface the challenge/answer round-trip before a student-initiated
   purchase.
3. **Guardian-purchases-for-linked-child** — the ledger models purchaser vs
   beneficiary and API-042 verified links are required; the client passes no
   beneficiary yet.
4. **API route-level flow tests for submit/restore/entitlements/webhooks** —
   granted by the permission-catalogue parity suite and domain/worker unit
   coverage; no Hono flow-level tests exist without a live database.
5. **`flutter analyze` + build** on a machine with the Flutter toolchain
   (pinned lockfile, pubspec now lists the Android/StoreKit federated
   packages directly).
6. **Phase 7 legal gate** — §29 student-AI listing alongside the catalogue
   gating; DL-009/DL-011 remain deferred and block production and real data.