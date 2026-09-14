# Subscription disclosure and policy requirements

What must appear in the app, in the store listing, and in the hosted legal
documents so the four subscriptions are not rejected.

This is an engineering and review-compliance specification. It is **not legal
advice and not a drafted Terms of Use**: the hosted documents themselves need
counsel (§29, D3), because consumer-subscription law, minors' contracting
capacity, and withdrawal rights all vary by jurisdiction. What follows is the
content those documents and screens must contain for store review to pass.

Related: ADR-0009 (catalogue and beneficiary model), §21.6 / B5 (hosted policy
URLs), §23.5 (Apple 3.1.1), §23.2 (minors), §24 (Google Play).

## 1. The purchase screen, before the buy button

Apple rejects under 3.1.2 when any of these is missing. Google Play's
subscription policy requires the same disclosures prominently and adjacent to
the call to action — not behind a link, not in a scroll-away footer.

Every paywall must show, before purchase:

| Element | Example for Student AI |
|---|---|
| Product title | Studafy Student AI |
| Length of subscription | Monthly |
| Price per period | 6.99 / month |
| Auto-renewal statement | Renews automatically each month until cancelled |
| How to cancel | Cancel any time in your device's subscription settings |
| Link to Terms of Use | tappable, opens the hosted document |
| Link to Privacy Policy | tappable, opens the hosted document |

For the two products with a trial, add:

| Element | Example for Parent Insights |
|---|---|
| Trial length and price | Free for 30 days, then 1.99 / month |
| When the charge starts | Your card is charged when the free trial ends |
| Cancellation window | Cancel at least 24 hours before the trial ends to avoid charge |

The 24-hour figure is Apple's renewal behaviour, not ours. State it because
users who cancel an hour before renewal are still charged, and that is the
single most common subscription complaint and refund trigger.

**Do not** write "free trial" anywhere without the price that follows it in the
same view. Apple treats a trial shown without its subsequent price as
misleading.

## 2. Restore purchases

A visible **Restore purchases** control is mandatory on iOS, reachable without
signing in to a new account. §23.5 already records that the current control
exists but its lifecycle is unverified.

It must restore across: reinstall, a new device on the same Apple ID / Google
account, and a Studafy account switch on the same device. That last case is
where a beneficiary model bites — the entitlement belongs to the beneficiary,
so restoring on an Apple ID whose Studafy account is a different person must
**not** silently move the entitlement. It should report that the purchase
belongs to another account.

## 3. What the hosted Terms of Use must cover

The current implementation is a single hardcoded paragraph in
`login_page.dart:253`. B5 replaces it with hosted documents. Those documents
must contain, at minimum:

- **The catalogue**: each product, its price, its period, whether it has a
  trial, and what it unlocks.
- **Auto-renewal**: that subscriptions renew until cancelled, when the charge
  occurs, and that cancellation takes effect at the end of the paid period.
- **Who is billed**: that payment is taken by Apple or Google, not by Studafy,
  and that Studafy never receives or stores card details.
- **Refunds**: that refunds are handled by the store, with a link to each
  store's refund process. Studafy cannot refund a store purchase directly, and
  saying otherwise creates an obligation that cannot be met.
- **Beneficiary rules**: that a guardian may purchase for a linked child, that
  the entitlement follows the child, and what happens if the guardian link is
  revoked or the child leaves the school.
- **Student purchases and parental consent**: that a student may purchase where
  their school permits it, that a parental gate applies, and how a guardian or
  school can disable it.
- **School-disabled purchasing**: that a school may switch off student
  self-purchase for its pupils.
- **What happens on account deletion**: an active subscription is not cancelled
  by deleting a Studafy account, because the store owns it. This must be stated
  on the deletion screen as well as in the terms — a user who deletes their
  account and keeps being charged will file a store complaint, and the store
  will side with them.
- **Education records**: that purchasing does not change who owns school
  records, and that cancelling does not delete them.

## 4. What the Privacy Policy must add

- That purchase verification data (store transaction identifiers, product
  identifiers, purchase and expiry timestamps) is processed and retained, and
  for how long.
- That **no card or payment instrument data reaches Studafy**, because the
  stores handle payment. This is a genuine privacy strength and should be
  stated plainly.
- For the AI products, if AI-072 resolves to enable: the provider, what leaves
  the tenant, what is redacted, and the retention period. This section cannot
  be written before that decision and the DPA exist.
- Both documents must be published in **English and Arabic**, publicly
  reachable with no login wall (§21.6), and the privacy URL goes into both
  store consoles.

## 5. Minors

Two products are sold to students who are minors. Beyond the parental gate in
ADR-0009:

- The age rating questionnaire in both consoles must be answered for an app
  that has teacher-parent messaging **and** in-app purchases available to
  students. Do not list in the Kids Category (§23.2).
- App Review notes must explain that students are school-provisioned, that a
  school can disable student purchasing, and how a reviewer can see both
  states.
- Where COPPA or GDPR-K applies, verifiable parental consent must precede a
  student-initiated purchase. The threshold age is configurable because it
  varies by jurisdiction; counsel sets the value.

## 6. Things that will get this rejected

Recorded because each is a real, common rejection:

| Mistake | Guideline |
|---|---|
| Any card, Apple Pay, or Google Pay form for these subscriptions | Apple 3.1.1, Play billing policy |
| Linking out to a Stripe checkout from inside the app | Apple 3.1.1 / 3.1.3 |
| Trial shown without the price that follows | Apple 3.1.2 |
| Missing or non-functional Restore purchases | Apple 3.1.1 |
| Terms or Privacy URL behind a login wall or 404 | Apple 5.1.1, Play policy |
| Selling a subscription to an AI feature that is disabled | Apple 2.1, 3.1.2 |
| Price in the app that disagrees with the store tier | Apple 3.1.2 — read prices from the store, never hardcode |

That last row is an implementation rule, not just a listing rule: the paywall
must render price strings from the store's product query, because tiers differ
per storefront and a hardcoded "1.99" is wrong in most countries.
