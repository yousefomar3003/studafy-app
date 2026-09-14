# Phase 3A / AUTH-030 local evidence

- Evidence date: 2026-09-13
- Target: disposable local Supabase only (`127.0.0.1:54321`, `127.0.0.1:54322`)
- Data: deterministic synthetic fixtures and locally created test users only
- Remote projects modified: none. The repository is linked to
  `eamewgaptdfqzpmayavx`; every command in this part used `--local`, and
  `db push`, `config push`, and `functions deploy` were never run.

**This does not close the Phase 3 gate.** See "Open" below.

## Implemented controls

Six forward migrations add append-only security events, a device registry, a
session-revocation watermark, single-use recent-auth grants, provider identity
links, a corrected deletion lifecycle, policy-backed consent, and a
least-privilege API function surface. Earlier migrations are unchanged.

| Migration | SHA-256 |
|---|---|
| `202609130001_auth030_security_events.sql` | `3457cae68a99f5190ad273ab1beea0b2fc0f7dfd6a1dcc37972331a524f7460c` |
| `202609130002_auth030_devices_sessions.sql` | `941741662814511641f328d572c1636f7f52a703a6594874d1b5a6d90daf93e0` |
| `202609130003_auth030_reauth_grants.sql` | `cb3f114ad613a0073a90e8e2c0a7b0e71b35a89bab9c3ff211690d781bb29774` |
| `202609130004_auth030_deletion_lifecycle.sql` | `5db847d755cecdaa9ec6f2783a1711dee1c8b0f69324087b76ab39b18d225e70` |
| `202609130005_auth030_consent_versioning.sql` | `b34a92e049114ba0be2f68c4a9c6fea9279bd1062d84561267bee0ebab730347` |
| `202609130006_auth030_api_surface.sql` | `23bf21ba55f76d2c2685222bb702cfcce9e944fb18f5821651909d79ff4fb4b9` |

Server: a JWKS verifier, authentication middleware, a session-context
repository, and the `/v1` auth routes in `apps/api/src/auth/`. Client: a
Keychain/Keystore-backed session and PKCE store, an API-backed session
repository over the generated `/v1` client, an explicit session state machine,
native Sign in with Apple, an account-security screen, and a rebuilt in-app
deletion flow.

## What was proven, and how

### End to end against a real provider

`bun run test:auth030:lifecycle` runs the API in process against the live local
GoTrue, using real ES256 tokens verified against the published JWKS, with every
database call going through the least-privilege `studafy_api_runtime` role over
a real connection. Transcript:
[`auth030-lifecycle-2026-09-13.txt`](auth030-lifecycle-2026-09-13.txt).

26/26 checks passed. The ones that matter most:

| Claim | How it was shown |
|---|---|
| Role metadata in a genuine provider token is not trusted | A user was created whose `app_metadata.role` really is `school_admin`; the token was asserted to carry that claim, and the API returned zero memberships and no admin policy |
| Sign-out everywhere beats token expiry | The same access token returned 200, then 401 on the next request after sign-out, while its own `exp` was still in the future |
| Recent-auth grants are single use | A grant authorized one deletion request and was refused on replay |
| Only the digest of a grant is stored | The stored `grant_hash` was compared against the issued grant |
| Authentication failures are indistinguishable | Anonymous and malformed-token responses were byte-compared with the request id removed |
| PKCE is enforced by the provider | Code exchange with a wrong verifier, and with no verifier, both refused |
| Unlisted redirect targets are refused | `/authorize?redirect_to=https://evil.test/steal` did not redirect there |
| Security events store no personal data | Written events carry a 64-hex `account_hash` and no `@` |
| The API's role is least privilege | A direct `select` on `public.profiles` as that role was denied |

### Automated suites

| Suite | Count | Covers |
|---|---:|---|
| `apps/api/test/auth/verify.test.ts` | 38 | Real ES256/RS256 keys and a real JWKS server: valid tokens; expired; not-yet-valid; wrong issuer; issuer-prefix; wrong audience; missing subject; `alg: none` with and without a signature; an HS256 forgery signed with the published public key; a symmetric key in the key set; a same-`kid` foreign key; five malformed shapes; oversized input; `kid` rotation; withdrawn keys; refetch cooldown; `max-age` honoured and expiry |
| `apps/api/test/auth/routes.test.ts` | 34 | Role-metadata distrust; the eight-way anti-enumeration byte comparison; no token in any log line; audit-sink failure still denies; the revocation watermark; recent-auth missing/replayed/wrong-purpose/wrong-session/fabricated/expired; admin MFA including enrolment-is-not-assurance; identity-link collision; cross-user device revocation; deletion idempotency and cancellation |
| `apps/api/test/auth/repository.integration.test.ts` | 10 | The real SQL through postgres.js against Postgres, including claim isolation across pooled transactions and append-only enforcement |
| `supabase/tests/auth030_access.sql` | 36 | Actor scoping of every function, device ownership, the watermark, grant single-use and session binding, identity collision, and request → cancel → re-request |
| `supabase/tests/auth030_grants.sql` | 16 | The API role's exact executable surface; zero table and column grants; no client role reaching an AUTH-030 relation; RLS on every one; append-only enforcement |
| `test/auth030_deep_link_hijack_test.dart` | 27 | Eleven hostile callback targets — lookalike scheme, lookalike domain, wrong path, plaintext downgrade, credentials in the authority, non-default port — plus provider errors and missing codes |
| `test/auth030_secure_storage_test.dart` | 9 | Session and PKCE verifier reachable only through the secure store; sign-out clears both |
| `test/auth030_session_lifecycle_test.dart` | 19 | Refresh failure → `reauthRequired` and never a demo fallback; sign-out scopes; account switching leaves no trace of the previous account |
| `test/auth030_account_deletion_test.dart` | 7 | Server-computed impact rendered; typed confirmation enforced; in-app cancellation reachable |

Whole-suite results on this machine: `bun test apps packages` — 139 passed, 0
failed. `flutter test` — 104 passed, 0 failed. `flutter analyze` — no issues.
`dart run tools/check_dart_bounds.dart` — 47 feature files, **0** legacy-exempt
features, 0 violations. `bunx supabase db lint` — no errors. The full database
suite in CI order (containment, RLS, DB-020, DB-021, AUTH-030) passes.

## Defects found and fixed while doing this

- **`packages/database` timeout units.** `idle_timeout` and `connect_timeout`
  were multiplied by 1000, but postgres.js takes seconds. The effective idle
  timeout was about eight hours and the connect timeout about 83 minutes, so
  pooled connections were never recycled and an unreachable host hung instead
  of failing fast. Found because the integration suite would not exit.
- **`account_deletion_requests` could only be used once.** The
  `unique (user_id, state)` constraint meant a cancelled row permanently
  occupied `(user_id, 'cancelled')`, so a user who cancelled could never
  request deletion again. Replaced with a partial unique index on live rows.
- **Production containment built adapters it never used.** `StudafyApp`
  constructed the composition root even when startup was blocked, so the
  readiness page depended on backend configuration it must never need.

## Discovered, not fixed here

**`public.audit_events` blocks profile deletion.** Its `actor_id` foreign key
is `ON DELETE SET NULL`, and that null-out is an UPDATE the DB-020 append-only
trigger refuses. Any profile with an audit event therefore cannot be deleted.
AUTH-030 delivers deletion *impact, request, and cancel*; the executor that
performs the deletion after the grace period is later work, and it will hit
this. `auth_security_events` avoids the problem by carrying no foreign keys.
Recorded here so the executor's author does not discover it in production.

## Open — the Phase 3 gate is not closed

Blocked on work outside engineering:

| Item | Blocked on |
|---|---|
| Real Google / Microsoft / Apple sandbox sign-in | D1, D2 and the provider consoles. No provider is configured; `[auth.external.*]` is present with env-var references and `enabled = false` |
| Physical-device Sign in with Apple | D1 — the Apple Developer organisation account. The native flow is implemented and iOS-gated but has run on no device |
| Universal Link / App Link verification | D5 (domain) and D1 (Team ID). Templates and the procedure are in `docs/release/auth030-site-association.md`. Until then the custom scheme is the working callback |
| App Review acceptance of the 4.8 posture | Submission |

Blocked on engineering or review still to come:

- §20 lists "threat-model and auth penetration test findings resolved" as 3A's
  own entry condition. Neither exists. That is SEC-091 and an independent
  reviewer.
- AUTH-031 (Part 3B) has not started, so the gate's "authorization catalogue
  coverage" and "API/RLS cross-tenant parity" items are untouched.
- Rate limiting on auth endpoints is OPS-060. The anti-enumeration responses
  are uniform, but nothing yet limits how fast they can be requested.
- Independent DB-021 security review, the Phase 0 human gate, and backup/PITR
  approval remain open from earlier phases and still block remote use.
- MFA is enforced for `school_admin`, but no administrator UI exists in the
  Flutter app; administration is server-side only until API-042.
