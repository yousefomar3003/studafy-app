# Where each credential lives, and whether to gather it yet

`instructions.md` §22 is the register of *what* credentials exist. This is the
operational companion: *which file* each one goes in locally, and *whether it
is worth obtaining now*.

The short version: **only Google and Microsoft OAuth are needed today.**
Everything else is either a later phase or actively blocked, and a live
credential sitting unused in a local file is a liability, not preparation.

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

Both files already carry step-by-step instructions inline.

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
| **AI provider API key** | Two independent gates. `allowsAiGrading = false` is a SEC-001 containment guard requiring a reviewed code change, and §22.6 marks the key **blocked until a DPA is signed**. Obtaining one now creates a live credential for a capability the app refuses to use |
| Apple Sign in with Apple (Service ID, Key ID, Team ID, `.p8`) | D1 — Developer organisation account under review |

## Later phases — obtain when that phase starts

The destinations below are **already reserved as commented slots** in
`.env.example`, so each credential has a known home before its phase begins.
They stay commented until the code that reads them exists: an environment
variable with no reader is a live credential guarding nothing.

| Credential | Phase | Why not now |
|---|---|---|
| Cloudflare API token, zone ID, origin certificate | 8 (INFRA-080) | No deploy target exists, and ADR-0005 (data residency) is **Deferred**, which blocks provisioning outright. A Cloudflare token obtained now would sit unused and unrotated for months |
| Managed Redis connection URL + password | 6 (OPS-060) | Local Redis covers development |
| Push: `google-services.json`, APNs key | 6/7 | No notification delivery is implemented |
| Email provider API key + verified domain | 6 | No transactional email is sent |
| Android upload keystore, Play service account | REL-002 | Release builds are blocked by the SEC-001 guard |
| App Store Connect API key (`.p8`) | REL-002 | Blocked on D1; note the `.p8` downloads **once** |
| Store billing (Apple root CAs, Play service account, Pub/Sub) | 7B (PAY-071) | The current verifier stub is being deleted, not configured |
| Error tracking DSN (e.g. Sentry) | 9 (OPS-090) | Must be PII-scrubbed before it handles minors' data |

## Rotation

Any credential that has passed through a chat message, a screenshot, a ticket,
or a shared document should be treated as disclosed and rotated. Rotation is
cheap before a credential is wired to anything; it is disruptive afterwards.

Azure client secrets additionally expire on a schedule you choose at creation
(24 months maximum). Expiry presents as sign-in breaking with no warning and no
code change — record the expiry date when you create the secret.
