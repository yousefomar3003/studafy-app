# ADR-0009: Billing product and purchaser/beneficiary model

Status: Deferred — blocks PAY-071 (Phase 6). Decision-log: DL-012.
Date: 2026-09-10.

## Context

The current implementation has one product (`studafy_parent_insights_monthly`,
planned in App Store Connect and Google Play Console), a client that starts
purchases and forwards verification data to a generic verifier Edge Function,
and a single `subscription_entitlements` row per user. The audit found no store
webhook receivers, transaction ledger, replay ownership, or reconciliation.

## Decision

**Deferred.** Working facts and assumptions:

- One paid product exists in scope: `studafy_parent_insights_monthly`
  (Parent Insights+). No store products or credentials exist in any console as
  of 2026-09-10.
- The client never grants entitlement from a local purchase result; only
  server verification writes entitlements (already enforced).
- The purchaser/beneficiary question (a guardian purchasing insights for a
  specific child vs. account-wide), multi-product support, grace/refund/
  revocation handling, and webhook reconciliation are **open** and must be
  decided before PAY-071 implements the ledger/entitlement model.
- Official Apple App Store Server Notifications V2 and Google RTDN receivers
  with signed-payload verification are required; the generic verifier
  endpoint is an interim mechanism only.

## Consequences

- PAY-071 (Phase 6) is explicitly blocked on this decision.
- Until then, `subscription_entitlements` remains single-product/single-row and
  must not be treated as an entitlement system of record.
- No store accounts, products, or signing credentials are created in the
  meantime.
