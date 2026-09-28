# External inputs checklist

Everything that must come from outside this repository: accounts, keys, assets,
URLs and decisions. Gather these ahead of the task that needs them so a run
never stalls waiting on you.

Companion to `prompts.md` (what to run) and `instructions.md` §22 (the full
credential register).

---

## Before you paste anything: what is safe to type into a session

Not everything on this list should be pasted into a chat. Transcripts persist.

| Safety | What | How to supply it |
|---|---|---|
| **Paste freely** | Public identifiers — bundle IDs, project refs, Team ID, Key ID, Issuer ID, URLs, domains, product IDs, package names, region names, D-U-N-S | Type it in the session |
| **Paste, low risk** | Supabase publishable key (`sb_publishable_*`) — public by design; RLS is the control | Type it, or run the config script |
| **DO NOT paste** | Private keys (`.p8`, `.p12`), keystore files or passwords, Supabase **service role** key, database passwords, Play service-account JSON, any provider secret | Put it in the ignored file or CI secret yourself, then tell me *"it's in place"* |

When I need a secret I will tell you **which file or CI secret to put it in**
and then continue. I never need to see the value. If I ever ask you to paste a
private key or service-role key directly, refuse — it means I have made a
mistake.

Ignored locations that already exist:

- `.env` — Bun API/worker local values
- `config/dart-defines.development.json` — Flutter build config
- `android/key.properties` — created at B1; already covered by `.gitignore`
  (`*.jks` and `**/key.properties` are ignored)

---

## Group 1 — Start now (longest lead times)

These gate everything. Weeks, not days.

### 1.1 Apple Developer Program — Organization

| Input | Notes |
|---|---|
| D-U-N-S number | Free via Apple's lookup tool. Up to 5 business days. **Get this first** |
| Legal entity name | Must match the CR **exactly**, character for character |
| Registered address | Must match CR and D-U-N-S |
| Entity website | Must be live |
| Account Holder | Person with authority to bind the entity |
| Corporate payment method | ~$99/yr, renews annually |

Produces later: **Team ID** (paste), distribution certificate, provisioning
profile, App Store Connect API key (`.p8` + Key ID + Issuer ID).

> The App Store Connect API `.p8` is **downloadable exactly once**. Save it to
> your password manager the moment you generate it.

### 1.2 Google Play Console — Organization

| Input | Notes |
|---|---|
| Same entity details as above | Plus identity verification |
| Corporate payment method | $25 one-time |
| Play App Signing | Enrol at first upload — non-negotiable |

Produces later: Play service-account JSON (do not paste — place as CI secret).

### 1.3 Domain and hosted legal documents

| Input | Needed for |
|---|---|
| Domain you control | Bundle ID convention, support email, policy hosting |
| Privacy policy URL (English) | Both consoles, B5 |
| Privacy policy URL (Arabic) | App ships `en` + `ar` |
| Terms of Use URL (en + ar) | B5 |
| Account-deletion web URL | Google Play requires a public one (B6) |
| Support email on that domain | Both listings, publicly visible |

Must be publicly reachable with **no login wall**.

### 1.4 Legal decisions (counsel, not engineering)

| Decision | Blocks |
|---|---|
| Are paid insights on children's education data approved? | A10 product gating, revenue model |
| Age ranges and guardian consent rules | A1, A14, store age rating |
| Data residency — must data stay in Saudi Arabia? | A11 (cannot provision until decided) |
| Retention schedule per data class | A14 |
| Cross-border transfer approval (AI, Calendar, store, CDN) | A14 |

### 1.5 Named people

| Role | Blocks |
|---|---|
| Independent security owner | Closes DB-021 and the Phase 2 gate |
| Moderation and safeguarding owner | SAFE-043; messaging cannot launch without an owned response path |
| Account Holder + backup admin (both stores) | Submission |
| On-call owner | A13 |

---

## Group 2 — Before A1 (auth)

### 2.1 OAuth providers

The app currently offers Google, Microsoft and Apple sign-in and registers the
custom callback `io.studafy.app://login-callback`. AUTH-030 must prefer an owned
HTTPS Universal Link/App Link callback, which additionally needs the domain,
Apple Associated Domains, `apple-app-site-association`, Android
`assetlinks.json`, signing fingerprints and Supabase/provider allowlists.

| Provider | Inputs | Paste? |
|---|---|---|
| Google | OAuth client IDs: iOS, Android (needs SHA-1), Web; client secret | IDs yes; secret → file |
| Microsoft | Azure AD app registration: client ID, tenant, client secret | ID/tenant yes; secret → file |
| Apple | Sign in with Apple: Service ID, Key ID, Team ID, `.p8` | IDs yes; `.p8` → file |

> Apple guideline 4.8 has a current exception for an education/enterprise app
> that requires an existing education or enterprise account. Counsel/product
> must choose a truthful posture: implement Sign in with Apple, or document and
> obtain acceptance of the school-provisioned-account exception. Public social
> signup cannot use that exception.

### 2.2 Supabase project

| Input | Where it goes | Paste? |
|---|---|---|
| Project ref | `config/dart-defines.*.json` | Yes |
| Publishable key (`sb_publishable_*`) | same | Yes |
| Service role key | Server env only — **never** the app | No |
| Database password | `.env` / CI secret | No |

There is a helper that writes the config without echoing values:

```
supabase projects api-keys --project-ref <ref> --output json \
  | bun scripts/write-synthetic-mobile-config.ts --project-ref=<ref>
```

---

## Group 3 — Before A5–A8 (files, Redis, queues)

| Input | For | Paste? |
|---|---|---|
| Local Redis running (`docker-compose.dev.yml`) | A7, A8 — four bun tests currently fail without it | n/a |
| Managed Redis URL + password (production) | A7, A11 | No → `.env`/CI |
| Malware scanning service: licence or API key | A6 | No → CI secret |
| **Decision:** allowed file types, max sizes, retention per purpose | A5 | Yes — tell me |

Recommended default for the file decision if you have no strong view:
restrictive, purpose-specific PDF/JPEG/PNG only to start.

---

## Group 4 — Before A10 (billing)

| Input | Source | Paste? |
|---|---|---|
| App Store Connect API key: Key ID, Issuer ID | App Store Connect | Yes |
| App Store Connect API key `.p8` | same — **one download only** | No → CI secret |
| Apple shared secret | App Store Connect | No |
| App Store Server Notification URL | You choose; set in App Store Connect | Yes |
| Google Play service account JSON | Google Cloud Console | No → CI secret |
| Pub/Sub topic + subscription (RTDN) | Google Cloud | Topic name yes |
| Product ID | Already fixed: `studafy_parent_insights_monthly` | — |
| **Decision:** price per territory | Product/finance | Yes |
| **Decision:** who benefits from a purchase | See `instructions.md` §29 | Yes |

Retire `PURCHASE_VERIFIER_URL` and `PURCHASE_VERIFIER_SECRET` — the current
stub's variables. They are replaced, not reconfigured.

---

## Group 5 — Before A11–A12 (infrastructure, CI/CD)

| Input | For | Paste? |
|---|---|---|
| **Decision:** approved region | Blocks all provisioning (ADR-0005 is Deferred) | Yes |
| Container host (Fly / Railway / Cloud Run) deploy token | A11 | No → CI secret |
| Cloudflare API token + zone ID | A11 | Zone ID yes; token no |
| Cloudflare origin certificate | A11 | No |
| Supabase **production** project ref | A11 | Yes |
| GitHub Actions secrets access | A12 | n/a |

---

## Group 6 — Before A13–A14 (observability, compliance)

| Input | For | Paste? |
|---|---|---|
| Error tracking DSN (e.g. Sentry) — must be PII-scrubbed | A13 | Yes |
| Alerting / on-call provider credentials | A13 | No |
| Push: `google-services.json` (FCM) + APNs key | A13, notifications | Files, not paste |
| Email provider API key + verified sending domain (SPF/DKIM/DMARC) | notifications | Domain yes; key no |
| Penetration test vendor engagement | A14 | n/a |
| Signed DPAs / processor agreements per vendor | A14 | n/a |
| Pilot school agreement | A15 | n/a |
| Moderation/safeguarding owner, escalation contact and response targets | A4c SAFE-043 | Names/policy only; no student content |

**AI provider:** retired. AI-072 removed the AI capability (ADR-0026) because
no signed DPA or extended DPIA exists. Do not obtain an AI key or
`STUDY_COACH_*` credential; nothing would read it. `allowsAiGrading` stays
`false`.

**Google Meet:** `GOOGLE_TOKEN_BROKER_URL` and `GOOGLE_TOKEN_BROKER_SECRET`
exist in the meeting Edge Functions. Deferred until the Workspace decision in
`instructions.md` §29 is made.

---

## Group 7 — Before B1–B3 (native cutover)

| Input | For | Paste? |
|---|---|---|
| Android upload keystore `.jks` | B1 — **you generate it**, see below | No |
| Keystore password, key password, alias | B1 → `android/key.properties` | No |
| Apple Team ID | B2 | Yes |
| Distribution certificate `.p12` + password | B2 | No |
| App Store provisioning profile | B2 | No |
| **App icon: 1024×1024 PNG, no alpha, no transparency** | B3 | File |
| Launch screen artwork | B3 | File |

Generate the keystore yourself — I will not, and will not ask for the passwords:

```
keytool -genkey -v -keystore ~/studafy-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> Back this file up in two places. Without Play App Signing, losing it
> permanently ends your ability to update the app.

Apple rejects a 1024 icon that has an alpha channel. Flatten it before export.

---

## Group 8 — Before C1 (store listings)

| Input | Notes |
|---|---|
| App name | Reserve early; first-come |
| Short + full description (en **and** ar) | Both consoles |
| Screenshots | iPhone 6.7" and 6.5"; Android phone + tablet if supported |
| Feature graphic | Play only, 1024×500 |
| Category | Education |
| Content/age rating answers | Be honest about messaging and user content |
| **Reviewer demo account** | Critical — see below |

> **The reviewer account is the one people forget.** Authorization is
> fail-closed: a reviewer signing in with no school membership sees an empty app
> and rejects it as non-functional. You must supply working credentials for a
> seeded school with a teacher, a parent and a student, plus notes explaining
> role switching and that accounts are school-provisioned.

---

## Quick index: what each prompt will ask for

| Prompt | Needs from you |
|---|---|
| A1 AUTH-030 | OAuth credentials (2.1), Supabase project (2.2) |
| A2–A4 | Nothing external |
| A4b API-042 | School provisioning, guardian-verification and support-access decisions |
| A4c SAFE-043 | Moderation/safeguarding owner, policy, contact and response targets |
| A5 FILE-050 | File type/size/retention decision (Group 3) |
| A6 FILE-051 | Malware scanner key |
| A7–A8 | Local Redis running; managed Redis URL for prod |
| A9 MOB-070 | Offline policy decisions; which slice to start |
| A10 PAY-071 | All of Group 4 |
| A11 INFRA-080 | Region decision, Cloudflare, host, prod Supabase |
| A12 INFRA-081 | Signing credentials as CI secrets |
| A13 OPS-090 | Error tracking DSN, alerting, push, email |
| A14 SEC-091 | Legal outputs, pentest vendor, DPAs |
| A15 LAUNCH-100 | Pilot school agreement |
| A16 SCALE-101 | Nothing external |
| B1 Android | Keystore in place, Play App Signing confirmed |
| B2 iOS | Team ID, certs, App ID registered |
| B3 Icons | 1024×1024 source asset |
| B4 Version | Nothing |
| B5 Privacy | Hosted policy + terms URLs (en + ar) |
| B6 Deletion | Web deletion URL |
| B7 Data API | Nothing |
| C1 Listings | All of Group 8 |
| C2 Audit | Nothing |
| C3 Rollout | Go/no-go thresholds you accept |
| D4 Review pack | Name of the security reviewer |

---

## Fill-in template

Keep this somewhere private and paste values in as you obtain them.

```
ORG
  Legal entity name:
  D-U-N-S:
  Domain:
  Support email:
  Account Holder:
  Security owner:
  Moderation/safeguarding owner:

IDENTITY (already decided)
  Bundle / application ID:  io.studafy.app
  Display name:             Studafy
  Product ID:               studafy_parent_insights_monthly

APPLE
  Team ID:
  App Store Connect Key ID:
  Issuer ID:
  Sign in with Apple Service ID:
  Sign in with Apple Key ID:
  (.p8 files: password manager, not here)

GOOGLE
  Play package name:        io.studafy.app
  Play App Signing enrolled:  yes / no
  OAuth client ID (iOS):
  OAuth client ID (Android):
  OAuth client ID (Web):
  Android SHA-1:
  Pub/Sub topic:

MICROSOFT
  Azure client ID:
  Tenant:

SUPABASE
  Prod project ref:
  Publishable key:
  (service role key + DB password: CI secrets only)

URLS
  OAuth callback domain:
  Privacy (en):
  Privacy (ar):
  Terms (en):
  Terms (ar):
  Account deletion:
  Support:

DECISIONS
  Approved region:
  Paid insights approved?      yes / no / pending
  Allowed file types:
  Age / consent model:
  Subscription price:
```
