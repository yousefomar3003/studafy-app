# Where each credential lives, and whether to gather it yet

`instructions.md` §22 is the register of *what* credentials exist. This is the
operational companion: *which file* each one goes in locally, and *whether it
is worth obtaining now*.

The short version (updated 2026-09-19): **Google and Microsoft OAuth, plus
three locally generated keys, are needed today.** Everything else is gathered
when its integration is switched on, and a live credential sitting unused in a
local file is a liability, not preparation.

## Hosted development testing update — 2026-09-22

The user explicitly authorized local storage for hosted testing. The supplied
server credentials are now in ignored, owner-only `.env.hosted`; public mobile
settings remain separate. Use `bun run dev:hosted` to prevent accidental loading
of the local database configuration. See [setup status](../evidence/hosted-credentials-turnstile-2026-09-22.md)
for validated services and the missing database/hostname setup. The local-stack
instructions below remain applicable to local Supabase only.

## The four locations, and why they are separate

| File | Holds | Committed? |
|---|---|---|
| `supabase/.env` | OAuth provider credentials only, read by `supabase start` to fill `env(...)` in `config.toml` | No — `**/.env` |
| `.env` (repo root) | Bun API and worker runtime: database, Redis, auth tuning | No — `.env` |
| `config/dart-defines.development.json` | Flutter **public** config. No secrets — the publishable key is public by design and RLS is the control | No — ignored |
| CI secrets / secret manager | Signing, store, and deploy credentials. Never on a laptop | Never |

Mixing these is the failure mode to avoid. A database URL in `supabase/.env`
does nothing; a service-role key in a dart-define ships it to every device.

## Needed now

| Credential | Goes in | Notes |
|---|---|---|
| Google OAuth client ID + secret | `supabase/.env` | Web application client. Redirect URI `http://127.0.0.1:54321/auth/v1/callback` |
| Microsoft/Azure client ID + secret | `supabase/.env` | Multitenant + personal accounts. Same redirect URI |
| `API_CURSOR_SIGNING_KEY` | `.env` | Generate locally: `openssl rand -hex 32`. The shipped value is a placeholder |
| `RATE_LIMIT_HMAC_SIGNING_KEY` | `.env` | Generate locally. Development mints an ephemeral key without it; production refuses to boot |
| `SUPABASE_SERVICE_ROLE_KEY` | `.env` | The local stack's own key from `supabase status`. API/worker only, never Flutter. Needed to exercise the FILE-050/051 storage path |

Both provider files already carry step-by-step instructions inline. The
provider consoles point at Supabase's `/auth/v1/callback`; Supabase's allowed
redirects then point at the app callback. Do not swap the two.

## Already configured locally — nothing to obtain

| Variable | Value | Why no credential is needed |
|---|---|---|
| `DATABASE_URL` | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` | The disposable local stack's own database |
| `REDIS_URL` | `redis://127.0.0.1:6379` | Started by `docker-compose.dev.yml`, no auth locally |
| `SUPABASE_URL` | `http://127.0.0.1:54321` | The local stack. The API derives the JWT issuer and JWKS URL from it |
| `SUPABASE_PUBLISHABLE_KEY` | from `supabase status` | Public by design (§22.3) |

**BullMQ needs no credential of its own.** It is a library on top of Redis, so
`REDIS_URL` is the whole configuration. There is no BullMQ account or API key
to obtain — a common misconception worth stating once.

## Blocked — do not obtain yet

| Credential | Blocked by |
|---|---|
| **AI provider API key** / `STUDY_COACH_URL`, `STUDY_COACH_KEY` | **Retired, not merely blocked.** AI-072 removed the AI capability (ADR-0026) because no signed DPA and no extended DPIA exist. No code reads any AI credential, so obtaining one creates a live secret for nothing. A future AI capability needs a new ADR, both legal documents and a reviewed code change; `allowsAiGrading = false` is retained as the SEC-001 tripwire |
| Apple Sign in with Apple (`SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID`/`_SECRET`, from Service ID, Key ID, Team ID, `.p8`) | D1 — Developer organisation account under review |

## Later phases — obtain when that phase starts

The destinations below are **already reserved as commented slots** in
`.env.example`, so each credential has a known home before its phase begins.
They stay commented until the code that reads them exists: an environment
variable with no reader is a live credential guarding nothing.

| Credential | Phase | Why not now |
|---|---|---|
| Cloudflare API token, zone ID, origin certificate | 8 (INFRA-080) | No deploy target exists, and ADR-0005 (data residency) is **Deferred**, which blocks provisioning outright. A Cloudflare token obtained now would sit unused and unrotated for months |
| Managed Redis connection URL + password | 6 (OPS-060) | Local Redis covers development; production requires a `rediss://` URL with AUTH (boot-enforced) |
| Rate-limit HMAC signing key (`RATE_LIMIT_HMAC_SIGNING_KEY`) | 6 (OPS-060) | Development mints an ephemeral per-boot key; production refuses to start without a configured, per-environment, rotatable key |
| Android upload keystore, Play service account | REL-002 | Release builds are blocked by the SEC-001 guard |
| App Store Connect API key (`.p8`) | REL-002 | Blocked on D1; note the `.p8` downloads **once** |
| Store billing: `APPLE_BUNDLE_ID`, `APPLE_ENVIRONMENT`, `APPLE_APP_APPLE_ID`, `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_ROOT_CERTIFICATES_BASE64`; `GOOGLE_PACKAGE_NAME`, `GOOGLE_SERVICE_ACCOUNT_JSON`, `GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL`, `GOOGLE_PUBSUB_AUDIENCE` | 7B (PAY-071) | Code reads them. Obtain with sandbox accounts when store certification starts; billing stays off until then. The parental-gate signing key no longer exists (DL-048) |
| File delivery and scanning: `FILE051_DELIVERY_SIGNING_KEY`, `FILE051_DELIVERY_PUBLIC_BASE_URL`, `MALWARE_SCANNER_URL`, `MALWARE_SCANNER_API_KEY` | 5 (FILE-051) | Code reads them. The scanner vendor is not chosen; production refuses to scan without one |
| Error tracking DSN (e.g. Sentry) | 9 (OPS-090) | Must be PII-scrubbed before it handles minors' data |
| Google Calendar: `GOOGLE_CALENDAR_SERVICE_ACCOUNT_JSON`, `GOOGLE_CALENDAR_ORGANIZER_EMAIL` | DL-052 meetings | Code reads them. Needs a Workspace account with domain-wide delegation and Workspace processing terms before attendee emails may leave Studafy |
| Email: `RESEND_API_KEY`, `EMAIL_FROM_ADDRESS` | DL-053 channels | Code reads them. Needs a verified sending domain. Swapping provider means a new adapter, not a URL |
| Push: `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`, plus `google-services.json` and an APNs key in Firebase | DL-053 channels | Server sender is built; the app still needs `firebase_messaging` and the native Firebase files |

## Rotation

Any credential that has passed through a chat message, a screenshot, a ticket,
or a shared document should be treated as disclosed and rotated. Rotation is
cheap before a credential is wired to anything; it is disruptive afterwards.

Azure client secrets additionally expire on a schedule you choose at creation
(24 months maximum). Expiry presents as sign-in breaking with no warning and no
code change — record the expiry date when you create the secret.
