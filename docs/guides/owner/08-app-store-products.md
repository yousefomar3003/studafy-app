# 08 · App Store subscriptions

Launch plan **C15** (work plan 5.6). Time: 1 to 2 hours.

The full design is in
[`docs/deployment/subscriptions.md`](../../deployment/subscriptions.md).
This guide is the click-by-click part.

## Before you start

- The App Store Connect record exists ([guide 07, part C](07-apple.md)).
- You are the Account Holder (only the Account Holder can accept the
  agreement).
- The company's bank account and tax details.
- The private folder `~/studafy-secrets` ([README](README.md)).

## Exact values

### Two subscription groups, four products

Plans in the **same group** upgrade into each other. That is how Plus to
Max (and 4 to 8 children) becomes an upgrade, not a second subscription.
**Level 1 is the highest plan.**

| Group | Product ID | Reference name | Level | Price | Duration |
|---|---|---|---|---|---|
| Studafy plans | `studafy_max_monthly` | Studafy Max monthly | 1 | US$5.99 | 1 month |
| Studafy plans | `studafy_plus_monthly` | Studafy Plus monthly | 2 | US$3.99 | 1 month |
| Family+ | `studafy_family_plus_8_monthly` | Family+ 8 children monthly | 1 | US$4.99 | 1 month |
| Family+ | `studafy_family_plus_monthly` | Family+ 4 children monthly | 2 | US$2.99 | 1 month |

**A product ID can never be changed or reused**, even after deletion.

### Server settings (what Claude will set)

| Variable | Value |
|---|---|
| `APPLE_BUNDLE_ID` | `com.studafy.light` |
| `APPLE_ENVIRONMENT` | `Sandbox` (test copy), `Production` (production) |
| `APPLE_APP_APPLE_ID` | The app's Apple ID number ([guide 07, part C](07-apple.md)) |
| `APPLE_ISSUER_ID` | Part C |
| `APPLE_KEY_ID` | Part C |
| `APPLE_PRIVATE_KEY` | The `.p8` file from part C |
| `APPLE_ROOT_CERTIFICATES_BASE64` | Made by Claude from the files in part D |

| Notification URL | Value |
|---|---|
| Sandbox | `https://studafy-api-test.fly.dev/webhooks/apple` |
| Production (after the domain, C8) | `https://api.studafy.com/webhooks/apple` |

## Part A: the Paid Apps agreement

1. App Store Connect → **"Business"** (older: "Agreements, Tax, and
   Banking").
2. **"Paid Apps"** → **"View and Agree to Terms"** → accept.
3. Add the **bank account** and the **tax forms**. For a company outside the
   US this includes the US form **W-8BEN-E**.
4. Wait until the status is **"Active"**. Subscriptions cannot be tested,
   even in sandbox, before that.

## Part B: groups and products

1. App Store Connect → **Studafy** → **"Monetization"** →
   **"Subscriptions"**.
2. Next to "Subscription Groups" click **"+"** (or "Create"). Reference
   name: `Studafy plans`. **"Create"**.
3. In the group, **"Create"** a subscription:
   - Reference name and Product ID: the **Max** row of the table;
   - **"Create"**.
4. On the subscription page:
   - "Subscription Duration": **1 Month**;
   - "Availability": all countries, or at least Jordan and the countries you
     launch in;
   - "Subscription Prices" → **"Add Subscription Price"** → United States,
     **US$5.99** → **"Next"** → keep Apple's prices for other countries →
     **"Confirm"**;
   - "App Store Localization": add **English (U.S.)** and **Arabic**:
     display name and description. Claude has the text (A4);
   - "Review Information": a screenshot of the Plans screen (Claude makes
     it) and a short note;
   - **"Save"**.
5. Repeat step 3–4 for **Plus** (US$3.99) in the same group.
6. In the group's list, check the levels: **Max is level 1**, Plus is level
   2. Drag them if needed.
7. Group page → "App Store Localization" → add the group's display name in
   English and Arabic (for example "Studafy plans").
8. Make a second group, `Family+`, with the two Family+ rows the same way.
   The 8-children plan is **level 1**.
9. **Family Sharing: leave it OFF** for all four. Once on it can never be
   turned off. Family+ is managed by Studafy's server, not by Apple's Family
   Sharing.
10. Optional free month: each subscription → **"Subscription Prices"** →
    **"Create Introductory Offer"** → "Free" → **1 month** → all countries.
    Do the same as on Google Play (guide 05).
11. **"Billing Grace Period"** (on the Subscriptions page) → **"Set Up"** →
    turn it **on** (16 days is a common choice) for all renewals. The server
    keeps access during it.

Do **not** create `studafy_parent_insights_monthly`. It is no longer sold.

## Part C: the In-App Purchase key

The server uses it to ask Apple about purchases (App Store Server API).

1. App Store Connect → **"Users and Access"** → **"Integrations"** →
   **"In-App Purchase"** (left side).
2. **"Generate In-App Purchase Key"** (or "+") → name `Studafy server` →
   **"Generate"**.
3. Copy the **Key ID** (not secret).
4. **"Download"**. The file is `SubscriptionKey_XXXXXXXXXX.p8`. **It
   downloads only once.** Move it to `~/studafy-secrets/` and copy it to the
   USB stick.
5. The **Issuer ID**: it is shown at the top of the **"App Store Connect
   API"** page in the same "Integrations" tab. If you cannot see it, tell
   Claude: Apple may ask you to request API access first.

Use the **In-App Purchase** key type. A "Team key" for the App Store Connect
API is a different thing.

## Part D: Apple's root certificates

1. Open [apple.com/certificateauthority](https://www.apple.com/certificateauthority/).
2. Download **"Apple Root CA - G3 Root"** and **"Apple Root CA - G2 Root"**
   (`.cer` files).
3. Save both in `~/studafy-secrets/apple-root/`. They are public, not
   secret. The code never downloads them itself; it uses only what you give
   it (`packages/config/src/index.ts`).

## Part E: server notifications

1. App Store Connect → Studafy → **"App Information"** → **"App Store Server
   Notifications"**.
2. **"Sandbox Server URL"** → **"Set Up URL"** →
   `https://studafy-api-test.fly.dev/webhooks/apple`, **"Version 2"** →
   **"Save"**.
3. **"Production Server URL"**: leave empty until production is on its
   domain (C8). Then `https://api.studafy.com/webhooks/apple`, Version 2.

## Part F: sandbox testers

1. App Store Connect → **"Users and Access"** → **"Sandbox"** → **"Test
   Accounts"** → **"+"**.
2. Use an email that is **not** an Apple ID yet (for example
   `you+sandbox1@gmail.com`). Country: Jordan. **"Create"**.
3. On the iPhone: **Settings → Developer → "Sandbox Apple Account"** (on
   some iOS versions: Settings → App Store → "Sandbox Account"). Sign in
   there only, never in the normal Apple ID screen.

TestFlight builds use the sandbox automatically, with the tester's own
Apple ID.

## Give Claude

> C15 done. App Apple ID `…`. Key ID `…`. Issuer ID `…`. Key
> `~/studafy-secrets/SubscriptionKey_….p8`. Root certificates
> `~/studafy-secrets/apple-root/`. Groups and four products created, levels
> checked. Sandbox URL set. Free month: yes/no.

## What Claude does

Sets on **both** the test API and the test worker (after your "go"):
`PAY071_BILLING_ENABLED=true`, `PAY071_ENVIRONMENT=development` and the
`APPLE_*` values above, with `APPLE_ENVIRONMENT=Sandbox`. On the worker also
`PAY071_RECONCILIATION_ENABLED=true`.

## How Claude checks it

1. The API's start-up log shows `pay071.appleConfigured: true`.
2. Claude asks Apple for a test notification with your key (App Store
   Server API, "Request a Test Notification"). It must reach
   `POST /webhooks/apple`.
3. The sandbox checklist in
   [`subscriptions.md`](../../deployment/subscriptions.md#sandbox-checklist-needs-your-store-accounts)
   on an iPhone: buy, renew (one month is about 5 minutes in sandbox),
   payment problem, cancel, refund, restore, and Plus to Max.

## Common mistakes

- **Plus and Max in different groups.** A student could then pay for both.
- **Max at level 2.** Apple would treat Plus to Max as a downgrade.
- **Family Sharing turned on.** It cannot be undone.
- **Products stuck in "Missing Metadata".** Each needs a localization, a
  price and a review screenshot.
- **The first subscriptions must be submitted with an app version.** Apple
  reviews new subscriptions together with a build. Add them on the version
  page before you submit (guide 10).
- **Signing in to the sandbox account as a normal Apple ID.** That can
  break the test account.
- **The `.p8` lost.** Revoke the key and make a new one.
