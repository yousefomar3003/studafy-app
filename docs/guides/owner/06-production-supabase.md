# 06 · Production Supabase and sign-in providers

Launch plan **C7** (work plan 4.1). Time: 1 to 2 hours.

A new Supabase project holds real children's data, apart from the test
copy. You create it and set up Google and Microsoft sign-in in it. Apple
sign-in is in [guide 07](07-apple.md). Claude then applies every migration
and points production at it.

## Before you start

- **Decision B2:** a new project on the **Pro** plan, and its size (at least
  4 dedicated CPUs; `docs/capacity/2026-10-12.md`).
- **Decision B3 (DL-067):** the domains are on `studafy.com`. Sign-in
  links use `app.studafy.com` (`supabase/config.toml`, the Android manifest
  and the iOS entitlements); the legal pages are on `legal.studafy.com`
  (`docs/deployment/legal-site.md`).
- Google Cloud (the project for Firebase and billing) and a Microsoft Azure
  login.
- The private folder `~/studafy-secrets` ([README](README.md)).

## Exact values

| What | Value |
|---|---|
| Project name | `studafy-production` |
| Region | **Central EU (Frankfurt)**, `eu-central-1` |
| Provider callback (Google, Microsoft) | `https://<project-ref>.supabase.co/auth/v1/callback` |
| Site URL | `https://app.studafy.com/auth/callback` |
| Redirect URLs | `io.studafy.app://login-callback` and `https://app.studafy.com/auth/callback` |

`<project-ref>` is the 20-letter ID in the project's address,
`supabase.com/dashboard/project/<project-ref>`. The app always returns to
`io.studafy.app://login-callback`
(`lib/features/session/data/api_session_repository.dart`).

## Part A: create the project

1. [supabase.com/dashboard](https://supabase.com/dashboard) → your
   organisation → **"Settings"** → **"Billing"**: the plan must be **Pro**.
2. **"New project"**:
   - Name: `studafy-production`;
   - Database password: click **"Generate a password"**, copy it;
   - Region: **"Central EU (Frankfurt)"**;
   - Compute size: from decision B2;
   - Security options: keep the defaults ("Data API" on, schema `public`).
3. Save the password: Apple Passwords ("Studafy production database"), and

   ```sh
   pbpaste > ~/studafy-secrets/supabase-production-db-password.txt
   chmod 600 ~/studafy-secrets/supabase-production-db-password.txt
   ```

4. **"Create new project"**. Wait until it is ready.

## Part B: keys and security settings

1. **"Project Settings"** → **"JWT Keys"** (or "JWT Signing Keys"). The
   "Current key" must be **ECC (P-256)** or **RSA**. If it says **"Legacy
   HS256 (Shared Secret)"**, click **"Migrate JWT secret"**, then
   **"Rotate keys"**. The API accepts only `ES256` or `RS256` tokens
   (`apps/api/src/auth/jwks.ts`).
2. **"Project Settings"** → **"API Keys"**:
   - copy the **Publishable key** (`sb_publishable_…`). It is public; you
     can paste it in chat;
   - under "Secret keys", **"+ New secret key"**, name
     `studafy-production-server`, copy it, and:

     ```sh
     pbpaste > ~/studafy-secrets/supabase-production-secret-key.txt
     chmod 600 ~/studafy-secrets/supabase-production-secret-key.txt
     ```

     This becomes the server's `SUPABASE_SERVICE_ROLE_KEY`. Never put it in
     the app.
3. **"Database"** → **"Settings"** (or "Project Settings" → "Database"):
   - "SSL Configuration": turn on **"Enforce SSL on incoming connections"**;
   - **"Download certificate"** → save it as
     `~/studafy-secrets/supabase-production-ca.crt` (not secret).
4. If decision B2 includes point-in-time recovery: **"Project Settings"** →
   **"Add-ons"** → **"Point in time recovery"** → choose 7 days.

## Part C: URLs and the email provider

1. **"Authentication"** → **"URL Configuration"**:
   - "Site URL": `https://app.studafy.com/auth/callback`;
   - "Redirect URLs" → **"Add URL"**: `io.studafy.app://login-callback`;
   - **"Add URL"**: `https://app.studafy.com/auth/callback`;
   - **"Save"**.
2. **"Authentication"** → **"Sign In / Providers"**:
   - **"Email": keep it enabled.** Parents' managed child accounts sign in
     with a one-time code the server makes
     (`packages/infrastructure/src/managedAccounts.ts`). No email is sent,
     but turning Email off would break them.
   - "Allow new users to sign up": keep **on**. Google, Microsoft and Apple
     sign-in create new users.

## Part D: Google sign-in

1. Supabase → **"Sign In / Providers"** → **"Google"**. Copy the
   **"Callback URL (for OAuth)"** shown there. It is
   `https://<project-ref>.supabase.co/auth/v1/callback`.
2. [console.cloud.google.com](https://console.cloud.google.com) → the
   production project → **"Google Auth Platform"** (older: "APIs &
   Services" → "OAuth consent screen").
3. **"Branding"**:
   - App name: `Studafy`;
   - User support email: `hello@studafy.com`;
   - App logo: leave empty for now (a logo needs Google's brand review,
     which takes days);
   - Application home page: `https://studafy.com`;
   - Privacy policy: `https://legal.studafy.com/privacy`;
   - Terms of service: `https://legal.studafy.com/terms`;
   - Authorized domains: `<project-ref>.supabase.co` (if refused,
     `supabase.co`), `studafy.com`;
   - Developer contact: your email. **"Save"**.
4. **"Audience"**: "External" → **"Publish app"** → "In production".
5. **"Data access"** → **"Add or remove scopes"**: `openid`,
   `.../auth/userinfo.email`, `.../auth/userinfo.profile`. Nothing else.
   **"Save"**.
6. **"Clients"** → **"Create client"**:
   - Application type: **"Web application"**;
   - Name: `Supabase production`;
   - "Authorized redirect URIs" → **"Add URI"**: the callback from step 1;
   - **"Create"**.
7. Copy the **Client ID** (not secret). Copy the **Client secret**, or
   download the JSON (newer consoles show the secret only once). Save it:
   `pbpaste > ~/studafy-secrets/google-oauth-production-secret.txt`.
8. Supabase → **"Google"** → **"Enable Sign in with Google"**:
   - "Client IDs": the Client ID;
   - "Client Secret (for OAuth)": the secret;
   - "Skip nonce checks": off;
   - **"Save"**.

You paste the secret into Supabase yourself. That is fine: it is the
Supabase console, not a chat.

## Part E: Microsoft sign-in

1. [portal.azure.com](https://portal.azure.com) → **"Microsoft Entra ID"** →
   **"App registrations"** → **"New registration"**:
   - Name: `Studafy`;
   - Supported account types: **"Accounts in any organizational directory
     (Any Microsoft Entra ID tenant – Multitenant) and personal Microsoft
     accounts"**;
   - Redirect URI: platform **"Web"**, the Supabase callback from part D;
   - **"Register"**.
2. **"Overview"**: copy the **"Application (client) ID"** (not secret).
3. **"Certificates & secrets"** → **"Client secrets"** → **"New client
   secret"**:
   - Description: `Supabase production`;
   - Expires: **24 months**;
   - **"Add"**. Copy the **"Value"** column at once (not the "Secret ID").
   - `pbpaste > ~/studafy-secrets/azure-production-secret.txt`.
   - **Put the expiry date in your calendar.** When it expires, Microsoft
     sign-in stops with no other warning.
4. **"Token configuration"** → **"Add optional claim"** → token type
   **"ID"** → tick **"email"** (and **"xms_edov"** if it is listed) →
   **"Add"**. If asked, tick "Turn on the Microsoft Graph email
   permission". The app asks Microsoft for `email`; Supabase needs it.
5. Supabase → **"Sign In / Providers"** → **"Azure"** → enable:
   - "Application (client) ID": from step 2;
   - "Secret Value": from step 3;
   - "Azure Tenant URL": **leave empty** (all tenants and personal accounts);
   - **"Save"**.
6. Recommended: **"Branding & properties"** → **publisher verification**.
   It needs a Microsoft AI Cloud Partner Program ID. Many school tenants
   block apps from unverified publishers, so a teacher's school account may
   be refused without it.

## Part F: Apple sign-in

Needs the Apple account. See [guide 07, part D](07-apple.md#part-d-sign-in-with-apple-c13).

## Give Claude

> C7 done. Project ref `…`. Publishable key `sb_publishable_…`. Secret key
> `~/studafy-secrets/supabase-production-secret-key.txt`. Database password
> `~/studafy-secrets/supabase-production-db-password.txt`. CA certificate
> `~/studafy-secrets/supabase-production-ca.crt`. JWT key type `…`. Google
> client ID `…`. Azure client ID `…`, secret expires `…`.

## What Claude does

- Applies every migration to the new project (your "go" first).
- Sets the runtime role passwords for `studafy_api_runtime` and
  `studafy_worker_runtime` (ADR-0041) and puts the connection strings in the
  production Fly secrets.
- Points the production app build (`SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`) and the production API and worker at it.

## How Claude checks it

1. `https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json` lists
   an `ES256` or `RS256` key.
2. The migrations check passes, and the API and worker start in production
   mode (the config check refuses any gap).
3. On a phone built for production: sign in with Google, then Microsoft,
   then Apple (iPhone). Each returns to the app.

## Common mistakes

- **Wrong region.** It cannot be changed later. It must be Frankfurt.
- **A legacy HS256 JWT key.** The API refuses every sign-in.
- **A typo in the redirect URL.** `io.studafy.app://login-callback`
  exactly: no `/` at the end, no `https`.
- **The Azure "Secret ID" instead of the "Value".** Sign-in fails with
  "invalid client secret".
- **The Google consent screen left in "Testing".**
- **Reusing the test project's Google client** without adding the new
  callback. Use a new Web client for production.
- **Turning the Email provider off.** Managed child accounts stop working.
