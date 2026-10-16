# 07 · Apple: App ID, app record and Sign in with Apple

Launch plan **B11** (work plan 5.1, 5.2) and **C13** (5.3). Time: 45
minutes, after Apple approves the Developer account.

## Before you start

- The Apple Developer Program account (Organization) is **approved**.
- You are the Account Holder or an Admin in it.
- For part E: Resend is set up ([guide 04](04-resend.md)).

## Exact values

| What | Value |
|---|---|
| Bundle ID | `com.studafy.light` (explicit, not a wildcard) |
| App name | `Studafy` |
| SKU | `studafy-ios` (any unique text; customers never see it) |
| Capabilities | Associated Domains, Push Notifications, Sign In with Apple |
| Associated domain in the app | `applinks:app.studafy.io` (`ios/Runner/Runner.entitlements`) |
| Sender for Apple's email relay | `no-reply@studafy.com` |

## Part A: your Team ID

1. [developer.apple.com/account](https://developer.apple.com/account) →
   **"Membership details"**.
2. Copy the **Team ID** (10 characters). It is not secret.

## Part B: register the App ID (B11)

1. **"Certificates, Identifiers & Profiles"** → **"Identifiers"** → **"+"**.
2. **"App IDs"** → **"Continue"** → **"App"** → **"Continue"**.
3. "Description": `Studafy`.
4. "Bundle ID": **"Explicit"**, `com.studafy.light`.
5. Under "Capabilities", tick:
   - **"Associated Domains"**;
   - **"Push Notifications"**;
   - **"Sign In with Apple"** (keep "Enable as a primary App ID").

   In-App Purchase is included automatically.
6. **"Continue"** → **"Register"**.

The app's entitlements already ask for all three
(`ios/Runner/Runner.entitlements`). If one is missing on the App ID, the
signed build fails.

## Part C: the App Store Connect record

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) →
   **"Apps"** → **"+"** → **"New App"**.
2. Platforms: **iOS**.
3. Name: `Studafy`. If Apple says the name is taken, try a variant (for
   example `Studafy: School & Study`) and tell Claude.
4. Primary language: English (U.S.). Arabic is added later as a
   localization (guide 10).
5. Bundle ID: choose **`com.studafy.light`** from the list.
6. SKU: `studafy-ios`. User access: **"Full Access"**.
7. **"Create"**.
8. Open **"App Information"** (under "General"). Copy the **"Apple ID"**
   (a number, for example `6741234567`). It is not secret. The server uses
   it as `APPLE_APP_APPLE_ID` ([guide 08](08-app-store-products.md)).

## Part D: Sign in with Apple (C13)

### What the code needs

The app uses Apple's **native** sign-in on iPhone
(`lib/features/session/data/api_session_repository.dart`,
`_signInWithAppleNatively`). It sends Apple's token to Supabase with
`signInWithIdToken`. Apple is **not** offered on Android. So Supabase only
needs to trust the **bundle ID**. A Service ID and a Sign in with Apple key
are needed only for a web sign-in flow, which the app does not use.

### Steps

1. Supabase → the **test** project (`cyrngoqnhqflzovlybbr`) →
   **"Authentication"** → **"Sign In / Providers"** → **"Apple"** →
   **"Enable"**.
2. "Client IDs": `com.studafy.light`.
3. "Secret Key (for OAuth)": **leave empty**.
4. **"Save"**. If Supabase refuses to save without a secret, do part D2,
   then come back.
5. Do the same in the **production** project ([guide 06](06-production-supabase.md))
   when it exists.

### Part D2 (only if Claude asks, or Supabase needs a secret)

1. **"Identifiers"** → **"+"** → **"Services IDs"** → **"Continue"**:
   - Description: `Studafy sign-in`;
   - Identifier: `com.studafy.light.signin`;
   - **"Continue"** → **"Register"**.
2. Open it → tick **"Sign In with Apple"** → **"Configure"**:
   - Primary App ID: `com.studafy.light`;
   - Domains: `<project-ref>.supabase.co`;
   - Return URLs: `https://<project-ref>.supabase.co/auth/v1/callback`;
   - **"Next"** → **"Done"** → **"Save"**.
3. **"Keys"** → **"+"** → name `Studafy Sign in with Apple` → tick
   **"Sign in with Apple"** → **"Configure"** → primary App ID
   `com.studafy.light` → **"Save"** → **"Continue"** → **"Register"** →
   **"Download"** (once only). Save it in `~/studafy-secrets/` and on the USB
   stick. Note its Key ID.
4. Tell Claude the Service ID, Key ID and the `.p8` **path**. Claude makes
   the Supabase secret from it. That secret expires within 6 months and must
   be renewed, so Claude records the date.

### Give Claude (C13)

> C13 done. Apple provider on in the test project with client ID
> `com.studafy.light`. Team ID `…`. App Apple ID `…`.

## Part E: email to "Hide My Email" users

People who sign in with Apple can hide their email address. Apple then gives
an `@privaterelay.appleid.com` address and only forwards mail from senders
you register.

1. **"Certificates, Identifiers & Profiles"** → **"Services"** →
   **"Sign in with Apple for Email Communication"** → **"Configure"**.
2. **"+"** → "Email Sources":
   - Domains: `studafy.com`;
   - Email addresses: `no-reply@studafy.com`.
3. **"Next"** → **"Register"**. Apple checks the domain's SPF. If it shows
   a red mark, tell Claude.

## What Claude does

- Sets the Team ID (`DEVELOPMENT_TEAM`) and signing for the Runner target,
  and removes the SEC-001 iOS release block in a reviewed change (D1).
- Builds with `APPLE_SIGN_IN_ENABLED=true`. Without it the app hides the
  Apple button.

## How Claude checks it

1. `codesign -d --entitlements :- Runner.app` on the signed build shows
   `com.apple.developer.applesignin` and `aps-environment` = `production`.
2. On an iPhone (TestFlight build): sign in with Apple as a new account, sign
   out, sign in again. Try once with "Hide My Email".

## Common mistakes

- **"The identifier is not available".** It may be held by your free
  personal team, from building on your iPhone with Xcode. Do **not** pick a
  new ID: Android already uses `com.studafy.light`. Tell Claude; Apple
  Developer Support can release it.
- **A capability missing on the App ID** (often Associated Domains). The
  build then fails to sign.
- **A wildcard App ID** (`com.studafy.*`). Push and Sign in with Apple need
  an explicit ID.
- **The `.p8` lost.** It downloads once. Revoke it and make a new one.
- **Expecting the name every time.** Apple sends the person's name only the
  first time they sign in.
