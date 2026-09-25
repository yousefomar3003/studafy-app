# Student Notebook subscription

Product decision: **US$2.49 per month**, with **one calendar month free** for eligible new subscribers. This is an auto-renewing digital-content subscription using Apple In-App Purchase and Google Play Billing. Store-local prices and eligibility govern checkout; a trial is not granted on signup, by parent approval, or by a client timer.

## Implemented

- Student Notebook has an English/Arabic paywall, parent-approval request, restore, renewal/cancellation disclosure and subscription management links. Its copy lives in `lib/l10n/app_en.arb`/`app_ar.arb` under the `notebook*` keys, so it is translated through the same pipeline as the rest of the app and is covered by the localization parity test.
- Work and Grades no longer expose the content feed through their tab selectors. Notebook content widgets are mounted only after an unexpired, server-verified own entitlement is returned. Returning to the tab, resuming, expiry and purchase verification recheck access.
- Checkout rechecks the authenticated account, offered SKU, school purchasing switch and current guardian approval. Google checkout uses the same offer token whose price/trial was displayed. Apple's introductory terms and eligibility are read from StoreKit, not guessed.
- Database migration `202609220001_student_notebook_access.sql` gates both the authoritative content API and direct resource/version/publication reads (also used by attachment authorization). Existing publication, enrollment and guardian/staff permissions remain required. Assignment, grade and messaging access does not require Notebook.
- The existing verified store ledger handles trial periods, renewals, expiry, billing grace, refunds and revocation. No Stripe digital checkout or direct wallet buttons were added.

## Store configuration required before enabling sales

Use existing product ID `studafy_student_notebook_monthly` on each store; do not create duplicate identifiers if already configured.

| Setting | App Store Connect | Google Play Console |
| --- | --- | --- |
| Type | Auto-renewable subscription | Auto-renewing subscription |
| Renewal period | 1 month | Monthly base plan, suggested ID `monthly` |
| Reference renewal price | USD 2.49, confirm Jordan/local storefront price | USD 2.49, confirm Jordan/local storefront price |
| Introductory offer | Free trial, 1 month | New-customer offer, suggested ID `one-month-free`; free phase P1M followed by the monthly base plan |
| Eligibility | Store-managed, one intro offer per subscription group | Store-managed new-customer eligibility; avoid developer-determined offers |
| Availability | Include Jordan | Include Jordan |

Configure the Apple subscription group, agreements, banking/tax information, review information and sandbox users. The Apple developer account was still pending at implementation time. Configure Google license testers and the internal test track; the signing/package must match `com.studafy.light`.

The paywall never states a price the store has not confirmed. With no usable store terms it says the store confirms the price before subscribing, and checkout stays disabled; a successful store query replaces that with the store's own localized renewal price. That price is rendered exactly as the store formatted it, with no currency code appended, because the formatted value already carries its storefront's symbol. The free-month CTA appears only when the queried offer supports it. Never market a guaranteed trial to a returning or ineligible subscriber.

The US$2.49 figure above is the reference price to configure in each console. It is a store-configuration input, not app copy: Jordanian buyers are charged the JOD tier the storefront resolves, which is not a dollar amount.

Store references: [Apple introductory offers](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions), [Google subscriptions setup](https://support.google.com/googleplay/android-developer/answer/140504).

## Backend deployment

Apply all pending migrations in order, then this migration. `private.notebook_runtime` defaults to **production**, so sandbox purchases cannot unlock production reads. In an isolated sandbox database, a trusted database operator must set its environment to `development`, `staging` or `synthetic` matching the API. Never expose this table or accept its environment from the client.

Example for a development database only:

```sql
update private.notebook_runtime set environment = 'development' where singleton;
```

The existing per-school purchasing switch still defaults off. Enable it only for intended testing/launch schools using the existing trusted operator path. No school-admin interface is added. Guardian approval remains mandatory for student self-purchases, and the parent must have a verified live link. Parent approval alone never charges or unlocks content.

Configure working store receipt-verification credentials and lifecycle webhooks/reconciliation before setting `PAY071_BILLING_ENABLED=true`. Supply deployed HTTPS `STUDAFY_TERMS_URL` and `STUDAFY_PRIVACY_URL` in the app build. Missing policy links disable checkout. Supabase service secrets and store verification keys remain server-only.

The migration was applied to the local database and its Notebook environment set to `development`. The hosted database/API and store consoles were not changed. Transaction-based tests roll back all fixture data. Deploying the code does not create store products or activate payments.

## Release checks

Use real sandbox store transactions to verify: eligible trial, ineligible subscriber paying monthly, restore after reinstall, canceled/pending purchase, parent approval revoked before checkout, renewals, expiration, refund, account switching and access revoked while Notebook is open. Confirm terms/local pricing on both stores in Jordan. Synthetic simulator UI checks are not proof of a successful store payment.
