# 05 · Google Play billing (subscriptions)

Launch plan **C6** (work plan 3.9). Time: 1 to 2 hours.

The full design is in
[`docs/deployment/subscriptions.md`](../../deployment/subscriptions.md).
This guide is the click-by-click part.

## Before you start

- **The first build is uploaded** to internal testing
  ([guide 09, part B](09-play-console-listing.md)). Play lets you create
  subscriptions only after it has seen a build that uses Play Billing.
- A **payments profile** (merchant account) for the company, linked to Play
  Console.
- The Google Cloud project you use for Firebase ([guide 03](03-firebase.md)).
- The private folder `~/studafy-secrets` ([README](README.md)).

## Exact values

### The four subscriptions

The product IDs are read by the database (`public.store_products`) and the
app. **A product ID can never be changed or reused.** Type them exactly.

| Product ID | Name | Price | Base plan ID |
|---|---|---|---|
| `studafy_plus_monthly` | Studafy Plus | US$3.99 / month | `monthly` |
| `studafy_max_monthly` | Studafy Max | US$5.99 / month | `monthly` |
| `studafy_family_plus_monthly` | Studafy Family+ (up to 4 children) | US$2.99 / month | `monthly` |
| `studafy_family_plus_8_monthly` | Studafy Family+ (up to 8 children) | US$4.99 / month | `monthly` |

The code does not read the base plan ID, so `monthly` is only a suggestion.
The app picks the offer by its terms: it shows "Start a free month" only
for an offer with a **1 month** free trial
(`lib/data/billing/store_subscription_repository.dart`).

### Server settings (what Claude will set)

| Variable | Value |
|---|---|
| `GOOGLE_PACKAGE_NAME` | `com.studafy.light` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | The Play API service account key (part F), as one line |
| `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL` | The push service account's email (part D) |
| `GOOGLE_PUBSUB_AUDIENCE` | The push endpoint URL, exactly (part E) |

| Place | Push endpoint and audience |
|---|---|
| Test copy | `https://studafy-api-test.fly.dev/webhooks/google` |
| Production (after the domain, C8) | `https://api.studafy.com/webhooks/google` |

The topic name is not in the code. The docs use `play-billing`.

## Part A: payments profile

1. Play Console, all apps view → **"Settings"** → **"Payments profile"**.
2. Create or link the company's payments profile. Use the company's legal
   name and address, exactly as registered.

## Part B: the subscriptions

Do this four times, once per row in the table.

1. Play Console → **Studafy** → **"Monetize with Play"** → **"Products"** →
   **"Subscriptions"** → **"Create subscription"**.
2. "Product ID": from the table. "Name": from the table. **"Create"**.
3. **"Add base plan"**:
   - "Base plan ID": `monthly`.
   - "Type": **"Auto-renewing"**.
   - "Billing period": **"Monthly"**.
   - "Grace period": keep the default (or 7 days).
   - "Account hold": on, keep the default.
   - "Resubscribe": allow.
4. **"Set prices"** → enter the US$ price → let Play convert the other
   countries ("Update exchange rates") → **"Apply prices"** → **"Save"**.
5. **"Activate"** the base plan. A base plan in "Draft" cannot be bought.
6. Fill the listing for the subscription: a description in English, and
   Arabic under "Manage translations". Claude has the text (A4).
7. Optional, a free month: in the base plan → **"Add offer"** → offer ID
   `free-month` → eligibility "New customer acquisition" → phase
   **"Free trial"**, **1 month** → **"Activate"**. Decide this for all four
   or none.
8. Pause: if Play shows a **"Subscription pause"** setting (on the base plan
   or the app's subscription settings), allow it. The app offers "Pause
   instead" before "Cancel" on Android.

## Part C: license testers

License testers can buy without being charged.

1. Play Console, all apps view → **"Settings"** → **"License testing"**.
2. Add the Gmail addresses of you and your testers.
3. "License response": **"RESPOND_NORMALLY"**. **"Save changes"**.
4. The same people must be in the internal testing list (guide 09) and
   must install the app **from Play**.

## Part D: Google Cloud (APIs and the push account)

1. [console.cloud.google.com](https://console.cloud.google.com) → choose the
   Firebase project.
2. **"APIs & Services"** → **"Library"**. Search and **"Enable"**:
   - **"Google Play Android Developer API"**;
   - **"Cloud Pub/Sub API"**.
3. **"IAM & Admin"** → **"Service accounts"** → **"Create service account"**:
   - name: `studafy-pubsub-push`;
   - no roles; **"Done"**.
   - Copy its email:
     `studafy-pubsub-push@<project-id>.iam.gserviceaccount.com`. Not
     secret. This account needs **no key**.

## Part E: Pub/Sub topic and push subscription

1. **"Pub/Sub"** → **"Topics"** → **"Create topic"**:
   - Topic ID: `play-billing`;
   - untick "Add a default subscription";
   - **"Create"**.
2. Open the topic → **"Permissions"** (or "Show info panel") →
   **"Add principal"**:
   - principal: `google-play-developer-notifications@system.gserviceaccount.com`;
   - role: **"Pub/Sub Publisher"**;
   - **"Save"**.
3. **"Pub/Sub"** → **"Subscriptions"** → **"Create subscription"**:
   - Subscription ID: `play-billing-to-test-api`;
   - topic: `play-billing`;
   - Delivery type: **"Push"**;
   - Endpoint URL: `https://studafy-api-test.fly.dev/webhooks/google`;
   - tick **"Enable authentication"**;
   - Service account: `studafy-pubsub-push@…`;
   - **Audience: type the endpoint URL again, exactly**;
   - **"Enable payload unwrapping": OFF**;
   - Acknowledgement deadline: 60 seconds;
   - Retry policy: **"Retry after exponential backoff delay"**;
   - **"Create"**.

Until Claude turns billing on for the test API, the endpoint refuses the
messages. That is fine: Pub/Sub keeps retrying for 7 days.

## Part F: the Play API service account

1. Google Cloud → **"IAM & Admin"** → **"Service accounts"** →
   **"Create service account"**:
   - name: `studafy-play-billing`;
   - no roles; **"Done"**.
2. Open it → **"Keys"** → **"Add key"** → **"Create new key"** → **"JSON"**
   → **"Create"**. Move the file:

   ```sh
   mv ~/Downloads/<project-id>-*.json ~/studafy-secrets/play-billing-service-account.json
   chmod 600 ~/studafy-secrets/play-billing-service-account.json
   ```

3. Play Console, all apps view → **"Users and permissions"** →
   **"Invite new users"**:
   - email: `studafy-play-billing@<project-id>.iam.gserviceaccount.com`;
   - "App permissions" → **"Add app"** → Studafy;
   - tick **"View app information and download bulk reports (read-only)"**,
     **"View financial data, orders, and cancellation survey responses"**
     and **"Manage orders and subscriptions"**;
   - "Account permissions": none;
   - **"Invite user"**.

## Part G: real-time notifications

1. Play Console → Studafy → **"Monetize with Play"** →
   **"Monetization setup"**.
2. **"Real-time developer notifications"**: tick **"Enable real-time
   notifications"**.
3. "Topic name": `projects/<project-id>/topics/play-billing`.
4. "Notification content": choose **subscriptions only** if that option
   exists. **Gap:** the worker handles subscription and test messages only.
   A "voided purchase" message is treated as an error
   (`apps/worker/src/billing/processor.ts`). Refunds still reach the server,
   as a subscription "revoked" message.
5. **"Save changes"**, then **"Send test notification"**.

## Give Claude

> C6 done. Project ID `…`. Play key
> `~/studafy-secrets/play-billing-service-account.json`. Push account
> `studafy-pubsub-push@….iam.gserviceaccount.com`. Audience
> `https://studafy-api-test.fly.dev/webhooks/google`. Products active:
> all four. Free month: yes/no.

## What Claude does

Sets on **both** the test API and the test worker (after your "go"):
`PAY071_BILLING_ENABLED=true`, `PAY071_ENVIRONMENT=development`, and the
four `GOOGLE_*` values above. On the worker also
`PAY071_RECONCILIATION_ENABLED=true`. The products are already listed for
`development` by migration.

## How Claude checks it

1. The API's start-up log shows `pay071.googleConfigured: true`.
2. Your **"Send test notification"** reaches `POST /webhooks/google` and is
   stored (a `403` means the audience or the push account does not match).
3. The sandbox checklist in
   [`subscriptions.md`](../../deployment/subscriptions.md#sandbox-checklist-needs-your-store-accounts):
   buy, renew (every few minutes in test), payment problem, cancel, pause,
   refund, restore, and Plus to Max.

## Common mistakes

- **A typo in a product ID.** It is permanent. Delete nothing; tell Claude.
- **"One-time products" instead of "Subscriptions".** Use Subscriptions.
- **Base plan left as Draft.** Activate it.
- **Audience not exactly the URL** (a missing `https://`, or an extra `/`
  at the end). Every message is then refused with `403`.
- **Payload unwrapping on.** The API expects the normal Pub/Sub message.
- **A tester who is not a license tester** pays real money.
- **Installing the app with a cable** (`adb` or `flutter run`). Play Billing
  works only for an app installed from Play.
- **"Insufficient permissions" in the first day.** New service-account
  permissions can take up to 24 hours. A known trick: edit any
  subscription's description and save it.
- **"Key creation is disabled".** Your Google Cloud organisation blocks
  service-account keys. Tell Claude; the policy has to be relaxed for this
  project.
- **Two push subscriptions at launch.** The test API and production get the
  same messages, because it is the same app. Before real users, delete
  `play-billing-to-test-api` and keep only the production one.
