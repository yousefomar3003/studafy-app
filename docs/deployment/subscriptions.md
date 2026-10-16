# Subscriptions: setup, operation and testing

Studafy Plus (US$3.99/month) and Studafy Max (US$5.99/month) are
auto-renewing monthly subscriptions sold through Apple In-App Purchase and
Google Play Billing. What each plan unlocks is in
[study-plans.md](study-plans.md); the decisions are in
[ADR-0009](../adr/ADR-0009-billing-and-entitlements.md),
[ADR-0029](../adr/ADR-0029-study-plans-and-ai-lesson-tools.md) and
[ADR-0032](../adr/ADR-0032-subscription-lifecycle-and-backups.md).

## How it works

1. **At a limit.** When the server refuses an AI action with `AI_DAILY_LIMIT`,
   `AI_ALLOWANCE_USED` or `PLAN_REQUIRED`, the app shows the upgrade prompt
   (`lib/features/study/presentation/upgrade_prompt.dart`). It says which
   limit was reached and what the next plan adds. Its **Upgrade** button
   opens the Plans screen. On Max there is nothing higher, so the prompt
   only explains.
2. **Plans screen.** It shows the store's own monthly price in the student's
   currency, the renewal terms and the Subscribe button. A student's own
   purchase first needs a linked parent's approval (DL-048). Payment happens
   only in the App Store or Google Play sheet, with whatever the student's
   store account offers: cards, Apple Pay or Google Pay where the store
   supports them. The app has no card form and no wallet button, and it never
   sees card details. On the web and desktop the plans are described, and
   buying is sent to the mobile app.
3. **Verification.** The store hands the app a signed transaction. The API
   verifies it with Apple (JWS chain to Apple's root CA, bundle id,
   environment, `appAccountToken`) or Google (Play Developer API, package,
   `obfuscatedExternalAccountId`, test flag). Only then is the ledger written
   and access granted (`private.billing_apply_verification`). The app
   completes the store transaction only after the server accepts it.
4. **Lifecycle.** Renewals, billing retries, grace periods, pauses,
   cancellations, refunds and expiries arrive as App Store Server
   Notifications V2 (`POST /webhooks/apple`, JWS-verified) and Google
   Real-Time Developer Notifications (`POST /webhooks/google`, Pub/Sub OIDC
   token verified). Each event is stored once (deduplicated on the store's
   event id and a payload hash). The worker then re-reads the subscription
   from the store's API before changing anything. A sweep re-verifies
   pending, unacknowledged and recently lapsed subscriptions, so a lost
   webhook cannot strand a paying subscriber.
   Google *voided purchases* (refunds, chargebacks, revocations) are the
   exception: no store API reports a void per token, so the worker finds the
   transaction by its purchase token and ends the access it granted
   (`refunded` for a full refund, otherwise `revoked`). A void for a
   one-time product is logged and skipped, since Studafy sells none. A
   refund or revocation is final: when Google also sends
   `SUBSCRIPTION_REVOKED` for the same refund, nothing is revoked twice.
5. **Access** is only ever `private.study_plan(user)` on the server: an
   `active` or `grace_period` entitlement whose end is in the future. The
   app displays the plan it is given and decides nothing itself.

### Duplicate subscriptions and charges

- A plan that is already active, or included in the active plan (Max
  includes Plus), is never offered or sold.
- **Plus to Max** replaces Plus instead of adding Max beside it. On Google
  Play the app names the Plus subscription being replaced
  (`ReplacementMode.chargeProratedPrice`: at once, same billing date, only the
  difference charged). On the App Store both products are in one subscription
  group, and Apple upgrades within the group and credits the unused time.
- Purchases are refused when a parent pays for the current plan, when the
  current plan is billed by the other store, or when Google Play cannot
  find the Plus purchase on this phone's Google account.
- A second entitlement for the same plan and person is never granted: it
  is recorded and collapsed (`duplicate_entitlement`). Client submissions
  carry a deterministic idempotency key, so a replayed store event cannot
  record twice.

### Pause and cancel

Plans screen → **Cancel subscription** opens a sheet that says what each
choice does to access and billing:

- **Google Play:** *Pause instead* first (1 week to 3 months; the plan runs
  to the end of the paid period, then no features and no charges until it
  resumes), then *Cancel*.
- **App Store:** Apple has no pause, so only *Cancel*.

Neither store lets an app pause or cancel for the subscriber, so both open
the store's subscriptions page (Google Play opens straight on the plan).
The screen then reflects what the store reports: renewing, cancelled
(access until the date shown), paused, or a payment problem with **Update
payment method**. A plan a parent pays for can only be changed by the
parent.

### Receipts and messages

- **Receipts.** Apple and Google email a receipt for every charge,
  renewals included, to the store account. Studafy never sends its own
  receipt for store billing.
- **Subscription notices.** When the ledger changes from verified store data,
  the payer gets an in-app notification: *subscription active*, *renewed*,
  *payment problem* or *ended*. It also goes by push, and by email if the
  payer turned billing email on. These notices fire from entitlement changes
  (the `subscription_lifecycle_notify` trigger), which only verified data
  can make, so nothing claims a payment before the store has confirmed it.
  They say only that the subscription changed and that the store sends the
  receipt. They never include an amount.

### Security controls

- Secrets are server-only: the Apple `.p8` key and the Google and Firebase
  service-account keys are read by the API and worker from the environment.
  The app holds only public identifiers.
- Webhooks: Apple JWS chain verification against Apple's root certificates;
  Google Pub/Sub OIDC token (signature, audience, service account). Both
  have their own fail-closed IP rate limit. Unverifiable events are never
  recorded.
- Sandbox and production cannot mix: `PAY071_ENVIRONMENT` must match the
  app's billing environment, and Apple/Google environment and test-purchase
  flags are checked on every transaction.
- Idempotency: events are deduplicated in `store_events`; ledger writes run
  under advisory locks; client calls need an idempotency key.
- Financial records (`store_transactions`, `store_events`, `entitlements`)
  have RLS with no client policies. They are reached only through
  `SECURITY DEFINER` functions that check the caller, and only the worker
  may drive the ledger from store events. The ledger is append-only, and
  every state change is kept in `store_transaction_history`.
- Logs carry ids and outcomes only. They never contain receipts, tokens,
  emails or card data (`apps/api/src/platform/logging.ts` redacts
  receipt and token fields).

## What you must set up

### 1. Accounts and agreements

- [ ] Apple Developer Program (organisation), and in App Store Connect the
      **Paid Apps agreement**, banking and tax forms.
- [ ] Google Play Console developer account, and a **payments profile**
      (merchant account) linked to it.
- [ ] A Google Cloud project for Pub/Sub and the service accounts (the
      Firebase project can be the same one).
- [ ] Live HTTPS pages for Terms of Use and the Privacy Policy. The
      Subscribe button stays disabled until the app is built with both
      URLs.

### 2. App Store Connect

- [ ] **Subscriptions → one subscription group** (e.g. "Studafy plans") with
      two auto-renewable subscriptions, 1-month duration:
      - `studafy_max_monthly`, level 1 (highest), US$5.99
      - `studafy_plus_monthly`, level 2, US$3.99

      Both must be in the **same group**. That is what makes Plus to Max an
      upgrade rather than a second subscription.
- [ ] **A second subscription group** (e.g. "Family+") with two
      auto-renewable subscriptions, 1-month duration, for parents:
      - `studafy_family_plus_8_monthly`, level 1 (highest), US$4.99 - up to
        8 linked children
      - `studafy_family_plus_monthly`, level 2, US$2.99 - up to 4 linked
        children

      Same rule: both in **one group**, so 4 to 8 is an upgrade. The plan is
      held by the parent (no child is named at purchase); the server works
      out which linked children it covers on every read, earliest linked
      first. The per-child `studafy_parent_insights_monthly` is no longer
      sold; leave it in App Store Connect so existing subscribers renew.
- [ ] Localised display name and description for each (English and
      Arabic), and the review screenshot.
- [ ] Optional introductory offer: 1-month free trial. The app shows "Start
      a free month" only when StoreKit says the account is eligible.
- [ ] **Billing Grace Period**: on. The server now keeps access through it.
- [ ] **App Store Server Notifications**: Version 2. Production URL
      `https://<api-host>/webhooks/apple`; Sandbox URL the same (or your
      staging API).
- [ ] **Users and Access → Integrations → In-App Purchase**: generate a key.
      Note the Key ID and the Issuer ID, and download the `.p8` (it can be
      downloaded only once).
- [ ] App Information → **Apple ID** (the numeric app id).
- [ ] Sandbox testers (Users and Access → Sandbox).
- [ ] Download Apple Root CA - G3 (and G2) from
      <https://www.apple.com/certificateauthority/> for
      `APPLE_ROOT_CERTIFICATES_BASE64`.

### 3. Google Play Console

- [ ] **Monetize → Subscriptions**: create `studafy_plus_monthly` and
      `studafy_max_monthly`, each with an auto-renewing monthly base plan and
      its price. Optional: a free-trial offer with a 1-month free phase.
- [ ] Also `studafy_family_plus_monthly` (US$2.99, up to 4 children) and
      `studafy_family_plus_8_monthly` (US$4.99, up to 8), the same way. The
      app upgrades 4 to 8 by naming the subscription it replaces, exactly as
      it does Plus to Max.
- [ ] In the subscription settings: a **grace period** and **account hold**,
      and **subscription pause** allowed. The app offers Pause first on
      Android.
- [ ] **Monetization setup → Real-time developer notifications**: topic
      `projects/<cloud-project>/topics/play-billing`. On that topic, give
      `google-play-developer-notifications@system.gserviceaccount.com` the
      Pub/Sub Publisher role, then send a test notification.
- [ ] Pub/Sub **push subscription** on the topic to
      `https://<api-host>/webhooks/google`, with **authentication enabled**.
      Use a service account whose email becomes
      `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL`, and set the audience to exactly
      that URL (`GOOGLE_PUBSUB_AUDIENCE`). The API's startup log reports
      `googlePushAudienceMatchesRoute: false` if that URL is not the push
      endpoint; every Play notification is then refused with 403.
- [ ] A Cloud service account for the Play Developer API. Invite its email in
      Play Console → **Users and permissions** with *View financial data* and
      *Manage orders and subscriptions*, then create a JSON key
      (`GOOGLE_SERVICE_ACCOUNT_JSON`).
- [ ] **License testers** (Setup → License testing) for test purchases.
- [ ] Upload a signed build to a testing track: Play Billing works only for
      an app installed from Play.

### 4. Server environment

Every variable, with a dummy value and where it comes from, is in
[`.env.example`](../../.env.example) under *PAY-071* and *DL-053*. Real values
go into the host's secret store (for the hosted development API, the ignored
`.env.hosted`), never into the repository or the app.

| Variable | Value from |
| --- | --- |
| `PAY071_BILLING_ENABLED` | `true` once the rest is set |
| `PAY071_ENVIRONMENT` | `development` for sandbox, `production` live |
| `APPLE_BUNDLE_ID` | Xcode → Runner → Signing |
| `APPLE_ENVIRONMENT` | `Sandbox` / `Production` |
| `APPLE_APP_APPLE_ID` | App Store Connect → App Information |
| `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | In-App Purchase key (step 2) |
| `APPLE_ROOT_CERTIFICATES_BASE64` | Apple root CAs, DER, base64, comma-separated |
| `GOOGLE_PACKAGE_NAME` | `com.studafy.light` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Play Developer API service account key |
| `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PUBSUB_AUDIENCE` | Pub/Sub push subscription |
| `PAY071_RECONCILIATION_ENABLED` | `true` on the worker |
| `NOTIFICATION_CHANNELS_ENABLED`, `FCM_*`, `RESEND_API_KEY`, `EMAIL_FROM_ADDRESS` | [push-notifications.md](push-notifications.md) |

The API and the worker both need the billing variables. The worker processes
webhook events and runs the reconciliation sweep.

### 5. App build

```sh
flutter build ipa \
  --dart-define=STUDAFY_TERMS_URL=https://studafy-legal.studafy.workers.dev/terms \
  --dart-define=STUDAFY_PRIVACY_URL=https://studafy-legal.studafy.workers.dev/privacy
```

These are the temporary pages from `ops/legal-site` (launch plan 4.3; see
[legal-site.md](legal-site.md)). Change both when the pages move to our own
domain.

`STUDAFY_ANDROID_PACKAGE` defaults to `com.studafy.light`; set it only if the
Android application id changes. The app's billing environment follows its
runtime environment and must match `PAY071_ENVIRONMENT`.

### 6. List the products

Plus, Max and the two Family+ plans are listed only in `synthetic` and
`development` until you
confirm them in both consoles. Then list them for the environment in a
migration:

```sql
update public.store_products set storefront_listed = true
where feature_key in ('studafy_plus', 'studafy_max', 'family_plus', 'family_plus_large')
  and environment = 'production';
```

And turn on self-purchase for a school if students should be able to ask
their parents (`POST /v1/billing/school-settings/self-purchase`, admin only;
off by default).

## Testing

### Automated (runs in CI)

| What | Where |
| --- | --- |
| Limit → upgrade prompt → Plans (daily limit, monthly allowance, locked feature, top plan) | `test/features/study/upgrade_prompt_test.dart`, `study_screens_test.dart`, `study_assistant_test.dart` |
| Plans screen: renewal date, cancelled/paused/payment problem, pause-first cancel sheet, App Store vs Google Play, parent-paid, web without a store | `test/features/study/study_screens_test.dart` |
| No duplicate subscription: already subscribed, parent-paid, other store, Android upgrade replaces Plus, missing original purchase | `test/data/store_subscription_test.dart` |
| Grace period keeps access, auto-renew-off recorded, events name their own transaction, pause state, v2 acknowledgement | `apps/worker/test/billing.test.ts`, `packages/domain/test/billing.test.ts` |
| Ledger: webhook events claim/finish/dead-letter, old-token expiry cannot end the new plan, unseen tokens, Apple plan change, renewal / payment-problem notices to the payer only, lost-renewal sweep | `supabase/tests/subscription_lifecycle.sql` |
| Google voided purchases: found by token, access ended once whichever of the void and `SUBSCRIPTION_REVOKED` comes first, audit history, unknown token retried, one-time products skipped | `supabase/tests/voided_purchases.sql`, `apps/worker/test/billing.test.ts` |
| The topic `play-billing` and the paths `/webhooks/google` and `/webhooks/apple` in this guide match the code (`packages/config/src/storeWebhooks.ts`) | `packages/config/test/storeWebhooks.test.ts` |
| Contract accepts Plus/Max purchases and approvals | `packages/contracts/test/contracts.test.ts` |

### Sandbox checklist (needs your store accounts)

Run with a sandbox tester (iOS) and a license tester (Android) against an
API with `PAY071_ENVIRONMENT=development`:

- [ ] Free student: ask 10 questions → the 11th shows the prompt → Upgrade →
      Plans shows the store's price.
- [ ] Parent approves → Subscribe → store sheet → the plan becomes active; a
      *Subscription active* notification arrives; the store emails a receipt.
- [ ] Renewal: sandbox renews every few minutes (Apple: 1 month = 5 minutes;
      Google test cards: 5 minutes). Renews-on date advances; *renewed*
      notification.
- [ ] Payment failure: Apple sandbox "billing retry" / Google test card
      "declined". The plan shows *Payment problem* and **Update payment
      method**; access continues during a grace period and stops on hold.
- [ ] Cancel from the sheet: status says *Cancelled, you keep … until …*,
      and access ends at that date.
- [ ] Pause (Android): status *Paused*, access stops at period end and
      returns on resume.
- [ ] Refund (Apple: App Store Connect "refund" in sandbox; Google: Play
      Console order → Refund): access is removed and *ended* is sent.
- [ ] Plus → Max on each store: one subscription remains, prorated.
- [ ] Reinstall / new phone, same Studafy account: the plan is there with no
      purchase; Restore purchases works on iOS.
- [ ] Try buying Plus while on Max: not offered.

### Not testable without your accounts

- Real App Store / Google Play verification, webhooks and store receipts:
  the code paths are covered with the stores' responses stubbed, but the
  first real signed transaction proves the credentials.
- Whether Google Play offers Pause for your base plans (a console setting).
- Apple's upgrade within the subscription group (depends on the group being
  set up as above).
