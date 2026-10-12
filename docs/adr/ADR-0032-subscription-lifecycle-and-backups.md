# ADR-0032: Subscription lifecycle, upgrade-at-limit, and independent backups

- Status: Accepted; deployed to the Fly test copy, not yet to production
  (status reviewed 2026-10-12, launch plan 7.2). Originally accepted for
  local/disposable use
- Date: 2026-09-29
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Relates to: ADR-0007 (RTO/RPO), ADR-0009 (store billing), ADR-0029 (plans)

## Context

The owner asked for a complete subscription flow: an upgrade path at every
free-plan limit, a subscription screen with terms and renewal timing,
verified monthly renewal with failure, cancellation, refund and expiry
handling, pause before cancel, receipts for every charge, backups at least
every 48 hours, and FCM push.

PAY-071 already had store-only billing, server verification and a ledger. A
review for this work found defects that stopped it being complete:

1. `public.store_events` carried DB-020's `updated_at` trigger without the
   column, so **every update of a store event failed**. Webhook events were
   recorded but could never be claimed or finished. No renewal,
   cancellation or refund from either store could reach the ledger.
2. The API contract's feature-key enums did not include `studafy_plus` or
   `studafy_max`, so **every Plus/Max purchase and approval request was
   rejected with a 400** before reaching the database.
3. The worker applied a store event to the newest row of a subscription
   lineage. A Google Play upgrade issues a new token linked to the old one,
   so the old token's later expiry would have ended the new plan.
4. Apple billing grace periods were computed from the transaction's expiry,
   which has already passed during grace, so access ended early. Auto-renew
   changes (`DID_CHANGE_RENEWAL_STATUS`) were ignored.
5. Google's v2 acknowledgement state was compared with the v1 value, so
   acknowledged purchases were re-acknowledged on every pass.
6. The Plans screen offered Plus to a Max subscriber, and on Android Max to
   a Plus subscriber as a second subscription: both double charges.
7. Nothing recovered a renewal whose webhook was lost.

## Decision

### Payments stay in the stores; no web checkout

ADR-0009 and the Jordan launch decision (docs/deployment/jordan-subscriptions.md,
2026-09-22) stand. Plus and Max unlock in-app digital features, so they are
sold only through Apple In-App Purchase and Google Play Billing. There is no
Stripe or web checkout, no card form, and no Apple Pay or Google Pay button
in the app. The payment methods are the store account's own: cards, and
Apple Pay or Google Pay where the store offers them. The app says so, and
describes nothing it cannot deliver. On the web and desktop, plans are
described and purchase is sent to the mobile app. A web checkout would need
its own eligibility review per storefront and a second billing ledger. It
is not built.

### Lifecycle

- Access stays `private.study_plan`: `active` or `grace_period` with a future
  end. What happens next is stored separately, as
  `store_transactions.renewal_status` (`renewing`, `cancelled`, `paused`,
  `payment_issue`), derived from Apple's status and renewal info or
  Google's state and `autoRenewEnabled`. It is for display only.
- Apple's own subscription status decides the state when the status API
  answers. Grace periods keep access until `gracePeriodExpiresDate`.
- A store event lands on the exact transaction it names. A transaction the
  ledger has not seen in a known lineage (a Google replacement or
  resubscribe, an Apple plan change made in the device's settings) is
  recorded as a new row with the lineage's payer, child and approval.
- The reconciliation sweep also re-reads subscriptions whose access ended in
  the last 30 days, at most hourly per row.

### No second subscription

The client refuses any purchase whose plan is already covered, or where the
current plan is paid by a parent, billed by the other store, or (Google) not
owned by this phone's Google account. Plus to Max is a replacement:
`chargeProratedPrice` on Google Play, and the shared subscription group on
the App Store. The server still collapses a second entitlement for the same
plan.

### Pause and cancel

The app cannot pause or cancel for the subscriber on either store. The cancel
sheet explains both choices, offers pause first where the store has it
(Google Play), and opens the store's own subscription page.

### Receipts and notices

The stores email the receipt for every charge; Studafy sends none of its own
for store billing. The payer receives in-app/push (and opt-in email)
notices when the entitlement changes: active, renewed, payment problem,
ended. They are raised by a trigger on `entitlements`, which only verified
store data can change, so no message can claim a payment before the store
has confirmed it.

### Backups

A scheduled workflow takes a snapshot-consistent logical dump of the app
schemas, plus optionally Storage objects, every 24 hours. It restores the
dump into a fresh Supabase Postgres container and checks every table's row
count before keeping it. It encrypts with age to an offline-held key and
keeps the result 30 days as an artifact, plus an optional S3 copy through
an OIDC role. Supabase's own daily backups and PITR remain the in-place
path. This adds what they lack: an off-Supabase copy, the file bytes, and a
restore proved on every run. Failures open an issue.

## Consequences

- Migration `202609290004_subscription_lifecycle.sql` fixes (1), (3), (4) in
  the ledger and (7), and adds the notification trigger. The contract fix
  (2) changes the OpenAPI document and the generated Dart client.
- The App Store products must be in one subscription group with Max ranked
  above Plus, or the upgrade path would create two subscriptions.
- An upgrade inside an existing lineage inherits the lineage's guardian
  approval on the server. The app still asks for approval of the higher
  plan first; making the server require it too is a follow-up.
- Backups hold minors' personal data. They are readable only with the
  offline private key, and retention (30 days by default) must be reflected
  in the privacy notice (ADR-0008).
