# Hosted testing configuration and Turnstile

The user authorized storing their supplied credentials locally for development testing. No secret values are included in this report or committed source.

## Destinations

- Ignored, mode-0600 .env.hosted: hosted Supabase server key, Turnstile secret/sitekey, Stripe test keys, public Azure application ID, tunnel ID, Google package name, and separately generated cursor/rate-limit signing keys.
- Ignored, mode-0600 config/dart-defines.development.json: public Supabase URL and publishable key, Studafy API URL, and feature flags only.
- Existing Cloudflare service: retains its token-file configuration. No second connector or service was installed.
- Azure provider secret belongs in hosted Supabase Auth provider settings. The supplied Secret ID is not a secret value, so it was not installed as one.
- Apple sign-in defaults off until APPLE_SIGN_IN_ENABLED is explicitly set after provider setup.
- Stripe test keys have been saved and validated, but the existing subscription feature is native Apple/Google billing. There is no Stripe checkout or webhook integration; saving these keys does not enable a payment flow.

To replace secrets later, edit .env.hosted locally and restart its API. Changing public Flutter defines requires rebuilding the app. Never pass the server env file to Flutter.

## Turnstile implementation

Followed the existing-widget direction from https://developers.cloudflare.com/turnstile/spin/prompt.md: kept the supplied widget, created no replacement, validated the supplied secret directly, and used the existing API rather than deploying another backend. Wrangler is not installed and no Cloudflare management credential was available, so widget metadata, approved hostnames and clearance level could not be read or changed. No secret recovery/getter was attempted because the user already provided the secret.

Protected surface: parent student-ID lookup, action student_lookup.
- GET /auth/bot-check serves a bilingual public widget page with a nonce-based CSP.
- The native WebView loads only the configured API page and Cloudflare challenge frames. It passes a short-lived token back to the caller and carries no Supabase access token.
- POST /v1/students/locate carries optional captchaToken in its typed contract. When the server's TURNSTILE_ENABLED is true, it requires valid siteverify success, exact action, and exact allowlisted hostname before the existing handler runs.
- Missing, malformed, failed, timed-out and reused tokens are rejected. Upstream tokens/responses/secrets are not logged.
- Retry creates a fresh native challenge page; the widget also has reset/error/expiry handling.
- Both server TURNSTILE_ENABLED and the mobile define remain false until the widget hostname and reachable API are configured. Server enforcement does not trust the mobile flag.

The secret probe returned invalid-input-response for a deliberately invalid token, without invalid-input-secret. This verifies secret acceptance, not widget hostname configuration or a successful real challenge. Successful real-widget submission and real Cloudflare replay rejection remain pending.

## Verified external configuration

Read-only probes:
- Hosted Supabase public Auth settings: Google and Azure enabled; Apple disabled.
- Hosted Supabase REST probe with the server key: HTTP 200, limit=0, no user records downloaded.
- Stripe /v1/balance: HTTP 200, livemode=false, no mutations.
- Turnstile siteverify: secret accepted; deliberately invalid token rejected.
- Hosted migration history: 8 entries, latest 202609090004. Repository: 72 migrations. No hosted migration or user record was changed.

## Remaining setup to test real accounts

1. Complete DATABASE_URL in .env.hosted using this project's Supabase Connect connection string and actual database password. The supplied [YOUR-PASSWORD] placeholder cannot authenticate. A Supabase server API key does not replace a PostgreSQL password.
2. Upgrade the hosted schema to the current reviewed migrations; the hosted project currently lacks the API's auth/session and newer feature schema.
3. Start the hosted API with bun run dev:hosted. Its launcher refuses missing, placeholder, local or cross-project database URLs and suppresses automatic root .env loading. Stop any older local API on port 8080 first.
4. Provide the tunnel's published hostname and allow it in the existing Turnstile widget. Route it to HTTP localhost:8080. Set TURNSTILE_HOSTNAMES to that hostname and enable the server flag; point the mobile STUDAFY_API_URL at its HTTPS origin and enable its flag.
5. Test real Google/Microsoft sign-in with the user completing provider credentials/MFA. Backend-authorized roles/memberships are still required; role selection never grants access.
6. Payment, push and meeting provider testing have their own outstanding native-store, APNs/FCM and calendar credentials. They are not activated by the keys supplied here.

## Reusable checks

bun --no-env-file scripts/check-hosted-setup.ts reports only status/booleans; it never prints keys, balances or personal data.
bun test scripts/start-hosted-api.test.ts verifies hosted/local isolation.
The native challenge integration test uses a synthetic page to test WebView-to-Flutter token transport; it is not a live Cloudflare widget test.

The broad backend suite exposed and prompted fixes for student-family read weight classification and concurrent startup/manual meeting batches. Meeting processor callers now await one shared in-flight batch.

## Final validation

- Flutter analysis: no issues.
- Flutter unit/widget suite: 305 passed.
- Backend workspace suite: 584 passed, 1 existing storage integration skipped, 0 failures.
- Hosted launcher isolation: 2 tests passed.
- TypeScript workspace typecheck, generated contracts, TypeScript/Dart boundaries and diff whitespace checks passed.
- Native iPhone 17 Pro challenge bridge integration: passed using synthetic HTML and a synthetic token.
- Google and Azure authorization probes returned HTTP 302 to accounts.google.com and login.microsoftonline.com respectively. No real account credentials or MFA were submitted.
- Supplied server-secret scan across nonignored project files: no matches. Both local credential configuration files have mode 0600.

## Hostname follow-up

The user supplied studafy.com and authorized api.studafy.com. Local server and
mobile configurations now select https://api.studafy.com, allow exactly
api.studafy.com for Turnstile, and enable the Turnstile flags. This supersedes
the disabled-flag status above. Authoritative DNS still returned NXDOMAIN;
remote tunnel routing and widget hostname registration remain pending because
no Cloudflare management credential is available. Exact dashboard fields and
verification steps are in ../deployment/studafy-domain.md.
