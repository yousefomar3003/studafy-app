# ADR-0009: Billing product and purchaser/beneficiary model

Status: **Decided** 2026-09-14 (supersedes the Deferred status of 2026-09-10).
Decision-log: DL-012 (deferral), DL-036 (this decision).

## Context

The 2026-09-10 audit found one planned product, a client that forwarded
verification to a generic Edge Function, and a single `subscription_entitlements`
row per user. The purchaser/beneficiary question, multi-product support, and
reconciliation were left open, and PAY-071 was explicitly blocked on them.

The product owner has now defined a four-product catalogue and asked that
payments run through Stripe.

## Decision

### Store in-app purchase only. Stripe is not used for these products.

Apple Guideline 3.1.1 and Google Play's billing policy both require digital
content unlocked inside the app to be sold through in-app purchase. All four
products below unlock in-app features, so all four must use
`in_app_purchase`. This is not a margin preference: §23.5 already records
"digital content sold outside IAP" as a rejection cause, and no wording in a
Terms of Use changes it.

Stripe remains available for a future **school or district licence** billed
off-app by invoice, which stores permit because the transaction does not occur
in the app. Nothing in this catalogue is sold that way today, and if it ever is,
the app must not link out to it without the relevant store entitlement.

A consequence worth stating plainly, because it inverts the original request:
**the app must not collect card details at all.** There is no card form, no
Apple Pay sheet, and no Google Pay sheet for subscriptions — the stores own the
payment surface. The most secure card-handling design available here is to
handle no cards.

### Product catalogue

| Product | Price | Trial | Beneficiary |
|---|---|---|---|
| Parent Insights | 1.99/month | 30 days | The purchasing guardian's linked child |
| Student Notebook | 1.99/month | 30 days | One student |
| Student AI | 6.99/month | none | One student |
| Teacher AI grading | 8.99/month | none | The purchasing teacher |

Prices are the product owner's intent in the store's local currency tier;
Apple and Google set the actual tier per storefront and neither guarantees an
exact figure in every country.

Trials are implemented as store **introductory offers**, not as app-side
countdowns. Eligibility is tracked by the store per Apple ID / Google account,
not per Studafy account, so a user with two Studafy accounts on one Apple ID
gets one trial. The app must read eligibility from the store rather than
inferring it, or it will promise a trial the store then refuses.

### Purchaser and beneficiary

The deferred question is answered as: **purchaser and beneficiary are distinct,
and the entitlement is held against the beneficiary.**

- A guardian may purchase Student Notebook or Student AI **for a linked child**.
  The entitlement attaches to the student, not to the guardian's account, and
  it survives the guardian's own subscription changes only while the guardian
  link is verified and unexpired.
- A student may purchase those products **for themselves**.
- Parent Insights is purchased by a guardian and scoped to one linked child, so
  a guardian with three children needs three subscriptions or the product must
  be re-scoped. This is deliberate: account-wide insight across children is a
  different product and a different price.
- Teacher AI grading is purchased by and scoped to the purchasing teacher.

Because the same product can be bought by either a guardian or a student, the
ledger records `purchaser_user_id` and `beneficiary_student_id` separately, and
duplicate active entitlements for one beneficiary are detected and refunded or
collapsed rather than double-charged.

### Student self-purchase is permitted, with guards

Students are minors. The product owner has decided that students may purchase
for themselves, and that decision is recorded here rather than argued with. The
conditions that make it defensible are not optional:

- A **parental gate** before any student-initiated purchase flow, as §23.2
  requires for purchases in a child-facing context.
- A **per-school switch**, default **off**, letting a school disable student
  self-purchase for its tenant. Schools will expect this, and a school that
  cannot turn it off will refuse the product.
- The app is **not** listed in the Kids Category, per the §23.2
  recommendation, and the age rating is set to reflect that students do not
  self-register.
- Where COPPA or GDPR-K applies, verifiable parental consent is required before
  a student-initiated purchase completes. The mechanism is configurable because
  the threshold age varies by jurisdiction; the policy value is counsel's (§29,
  D3), not engineering's.

If counsel advises against student self-purchase in a given market, the
per-school switch and a storefront-level product availability rule are the
levers, not a code change.

### The two AI products depend on AI-072

Student AI and Teacher AI grading sell access to a capability that is currently
disabled and whose enable/remove direction is undecided (Part 7C). Neither SKU
may be listed in a store console until AI-072 resolves in the enable direction
with a signed DPA. Selling a subscription to a feature that is then removed is
a refund event and a store-trust problem.

> **Resolved 2026-09-18 by ADR-0026 (DL-047): AI-072 removed the AI
> capability.** Both AI products are retired: a database constraint keeps them
> inactive and unlisted in every environment, and their feature keys remain
> only as ledger vocabulary.

Parent Insights additionally remains gated on the legal review in §29.

## Consequences

- PAY-071 is unblocked and grows from one product to four, with two purchase
  paths and a beneficiary model.
- `subscription_entitlements` is replaced as the system of record by the
  DB-020 `store_transactions` / `store_events` ledger, with entitlements
  derived from it.
- `StoreSubscriptionRepository.insightsMonthlyProduct` becomes a catalogue,
  and the Flutter surface gains a guardian purchase path scoped to a child.
- Guardian-purchased entitlements depend on the verified guardian link from
  API-042, so PAY-071 now depends on API-042 as well.
- Two of the four SKUs cannot ship before AI-072.
- Store console setup (§25, C1) grows from one product to four, each needing
  its own localised name, description, and disclosure text.

## Recovery

Prices and trials are store-console values and can be changed without a
release. The beneficiary model is in the ledger schema and cannot: changing it
later requires a forward migration plus reconciliation of live entitlements,
which is why it is decided before implementation rather than after.

## Addendum 2026-09-19 (DL-048): guardian approval replaces the parental gate

The parental gate originally shipped as a signed single-digit multiplication
challenge. It could not satisfy this ADR's intent: the question was answerable
by the child it was meant to stop, and the token carried both operands in
readable form, so a script could answer it too. It is removed.

A student-initiated purchase now requires **guardian approval**:

1. The student requests approval for one product
   (`POST /v1/billing/purchase-approvals`). The school's self-purchase switch
   must be on and at least one verified, unexpired guardian link must exist.
   Each such guardian receives an in-app notification.
2. A guardian decides (`POST /v1/billing/purchase-approvals/{id}/decision`)
   from their own authenticated session, behind a single-use recent-auth grant
   for the `billing_purchase_approval` purpose. Only a guardian with a live
   link to that student can see or decide the request; anyone else receives
   the same `404`.
3. An approval is spendable for 72 hours. The server consumes it when it
   records the first ledger row of the subscription lineage and records the
   approval id on that row. Renewals of the lineage inherit it. A client
   cannot assert approval: the request field no longer exists.

The per-school switch still defaults to off, and the verifiable-consent
condition above is unchanged; counsel may still require a stronger consent
mechanism for particular markets.
