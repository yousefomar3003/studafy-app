# ADR-0016: AUTH-030 session lifecycle, token verification and Apple 4.8 posture

- Status: Accepted for local/disposable use
- Date: 2026-09-13
- Decision log: DL-032, DL-033, DL-034
- Supersedes: nothing. Extends ADR-0014 (DB-021) without weakening it.

## Context

Before this part, the entire session lifecycle was four methods on
`SupabaseSessionRepository`: an OAuth redirect to a custom URI scheme, a
boolean "is there a session" stream, a profile read, and `signOut()`.

Concretely, that left:

- **No server-side token verification anywhere.** No service checked a
  signature, issuer, audience, or algorithm. The one place that inspected a
  token — `supabase/functions/request-account-deletion` — base64-decoded the
  payload without verifying it at all.
- **A recent-auth check that does not work.** The same function treated an
  `iat` within ten minutes as proof of presence. Supabase reissues `iat` on
  every silent refresh, so a session that last saw a human days ago presents a
  fresh `iat` and passes.
- **Refresh tokens in shared preferences.** The Supabase SDK's default storage
  is a plaintext XML file on Android and a plist on iOS. A refresh token mints
  new access tokens indefinitely.
- **No revocation short of token expiry.** Nothing could end a session on
  another device before its access token expired on its own.
- **No device list, no MFA, and no account-linking policy.**
- **Roles read wherever convenient.** Nothing established that role and tenant
  must come from the database rather than from the token.

## Decision

### The API is the authority; the token is only proof of identity

`apps/api` verifies every bearer token against the project's JWKS before
reading any claim, then resolves roles and tenants from `public.memberships`.
`app_metadata`, `user_metadata`, and any custom claim are read for nothing that
grants authority. The end-to-end verification signs in a user whose provider
token genuinely carries `app_metadata.role = "school_admin"` and asserts that
the API grants it no memberships and no admin policy.

Verification order is fixed: resolve the key by `kid`, verify the signature,
then validate `iss`, `aud`, `exp`, `nbf`, `iat`, and `sub`. The header's `alg`
is never used to select the algorithm — it must agree with the key that `kid`
resolved to. Only ES256 and RS256 are accepted; `alg: none` and every `HS*`
are refused, because with a published public key set a symmetric algorithm is
the classic confusion forgery.

### Revocation takes effect on the next request, not at token expiry

`public.auth_session_revocations` holds a per-user `revoked_before` watermark.
The middleware refuses any verified token whose `iat` precedes it. Signing out
everywhere therefore stops in-flight access tokens immediately rather than
after their remaining lifetime. `AUTH_REVOCATION_BUDGET_SECONDS` can widen that
window deliberately; it defaults to zero.

### Recent auth is an explicit single-use grant, not an `iat` heuristic

`public.auth_reauth_grants` stores only the SHA-256 of an opaque token, bound
to a purpose and a session id, short-lived and consumed atomically on first
use. Privileged commands require one. This replaces the broken `iat` check.

Cancelling a deletion deliberately requires **no** grant: stopping a
destructive action is the safe direction, and friction there would strand a
user who cannot re-authenticate before the grace period ends.

### The API holds no table privileges

`studafy_api_runtime` is activated with `LOGIN` but receives no table, column,
or sequence grant. Its entire database authority is `EXECUTE` on thirteen
`private.auth_*` SECURITY DEFINER functions, each of which derives the acting
user from `auth.uid()` and takes no user identifier as a parameter. The API
sets `request.jwt.claim.sub` from the verified token inside each transaction
using `set_local`, so a pooled connection cannot carry one request's identity
into the next.

This keeps DB-021 intact: the reviewable question is "which functions may the
API call", and the answer is asserted in `supabase/tests/auth030_grants.sql`.

### Every authentication failure looks identical

No credentials, a malformed token, a bad signature, an expired token, a wrong
issuer, an unknown account, a suspended profile, a deleted profile, and a
revoked session all return a byte-identical 401 apart from the request id. The
`V1AuthErrorCode` vocabulary contains no code that distinguishes them, and a
contract test asserts that no such code is ever added. The private reason is
logged for operators.

For a product whose users are schoolchildren, confirming that a given address
belongs to a Studafy user is itself a disclosure.

### Session material lives in the platform keystore

`SecureSessionStorage` and `SecurePkceStorage` route both the session and the
PKCE code verifier through `SecureStore`, backed by the iOS Keychain
(`first_unlock_this_device`, so it is excluded from iCloud Keychain and device
backups) and the Android Keystore.

### Apple guideline 4.8: implement Sign in with Apple

Sign in with Apple is implemented natively — `getAppleIDCredential` with a
hashed nonce, exchanged through `signInWithIdToken` — and shown only on Apple
platforms. The browser redirect is deliberately not used there: it presents a
web view for a credential the system can supply directly, which reviewers treat
as a non-equivalent implementation.

The education/enterprise exception is **not** claimed. It is available only
where an existing education or enterprise account is required to use the app,
and today Google and Microsoft sign-in create the primary Studafy account.
Claiming it would be untrue. If account creation later becomes invitation-only
(API-042), the posture may be revisited in a new ADR.

### The owned HTTPS callback is preferred; the custom scheme is a proven fallback

`https://app.studafy.io/auth/callback` is the primary redirect target, declared
as an Android App Link and an iOS associated domain. Because any app can
register a custom URI scheme, `io.studafy.app://login-callback` stays only as a
fallback until domain verification is possible.

`AuthCallbackGuard` is wired in as the SDK's `detectSessionInUriPredicate`, so
a link is only exchanged when it targets one of the exact claimed callbacks.
The SDK's default accepts any link carrying a `code`, wherever it points.

The guard deliberately does not re-implement `state` and PKCE checking: it
cannot see the generated `state` or the verifier, so a second copy would prove
nothing. That enforcement is GoTrue's and is verified against a real GoTrue.

## Consequences

- A remote build without `STUDAFY_API_URL` refuses to start rather than letting
  the client decide authority for itself.
- Production refuses to start without `SUPABASE_URL`: with no JWKS there is
  nothing to verify tokens against.
- `account_deletion_requests` loses its `unique (user_id, state)` constraint,
  which made a second request impossible after a cancellation. A partial unique
  index now constrains only what needs constraining: one live request per user.
- `auth_security_events` carries no foreign keys. An append-only relation
  cannot participate in `ON DELETE SET NULL`, because that null-out is an
  UPDATE the append-only trigger refuses — which would make the profile
  undeletable and break the very flow this part delivers.
- One DB-021 pgTAP assertion changed: "future runtime roles are inactive" now
  reads "runtime roles never inherit or bypass RLS; only the API role is
  activated". The guarantees that matter are unchanged and the new surface is
  asserted separately.
- Consent can only be recorded against a published, effective policy row, so
  bumping the client's version constant without a matching row fails closed.
- The `account` feature is no longer exempt from the Dart boundary rules.

## Recovery

Each migration is transactional; a failed application rolls back. A defect
after application is corrected with a forward migration. The auth routes are
mounted only when both a database and `SUPABASE_URL` are configured, so
removing either configuration disables the surface without a code change —
`/v1` then answers `NOT_IMPLEMENTED` as before.

## Open

This ADR records an engineering decision, not a closed gate. Real provider
sandbox sign-in, physical-device Sign in with Apple, claimed-link domain
verification, App Review acceptance of the 4.8 posture, and the threat model
and penetration test that §20 lists as 3A's own entry condition all remain
outstanding. See `docs/evidence/phase-3/README.md`.
