# AUTH-030 authentication operator runbook

Covers the session lifecycle delivered by AUTH-030. Every command here is
written for a **local or disposable** environment. No production environment
exists yet (DL-009, DL-024); when one does, these procedures need an on-call
owner and an approval path before they are used against real accounts.

Owner: repository owner (`@yousefomar3003`), single-owner project. Production
use requires re-recording with named, separated owners.

## Vocabulary

| Term | Meaning |
|---|---|
| Watermark | `public.auth_session_revocations.revoked_before`. The API refuses any verified token issued before it |
| Recent-auth grant | Single-use opaque token, stored only as a SHA-256 digest, required by privileged commands |
| aal2 | A session that actually presented a second factor. Enrolment alone leaves a session at aal1 |

## A user is locked out

Work down this list; each step is cheap and rules out the one below.

1. **Is the account suspended or deleted?** The API returns the same 401 for
   both, so the answer is in the database, not the response:

   ```sql
   select status, deleted_at from public.profiles where id = :user_id;
   ```

2. **Is there a live deletion request?** A profile inside its grace period is
   still usable; one that has moved to `executing` is not.

   ```sql
   select state, execute_after from public.account_deletion_requests
   where user_id = :user_id order by requested_at desc limit 1;
   ```

   To stop it, the user should cancel in the app. That path needs no
   recent-auth grant precisely so a locked-out user is not stranded.

3. **Is a watermark refusing their token?** If `revoked_before` is in the
   future relative to their token's `iat`, every request fails until they sign
   in again. Signing in again is the fix — do **not** delete the row to
   "unblock" someone, because that also unblocks any token an attacker holds.

   ```sql
   select revoked_before, reason, created_at
   from public.auth_session_revocations where user_id = :user_id;
   ```

4. **Do they have an active membership?** A user with none authenticates fine
   and sees an empty app. This is the fail-closed behaviour that a store
   reviewer mistakes for a broken app (§23.1).

   ```sql
   select m.role, m.active, m.status, m.valid_until, s.name, s.status
   from public.memberships m join public.schools s on s.id = m.school_id
   where m.user_id = :user_id;
   ```

5. **Check the security events.** The reason code says which check failed:

   ```sql
   select created_at, event_type, outcome, reason_code, user_agent_family
   from public.auth_security_events
   where actor_id = :user_id order by created_at desc limit 20;
   ```

   `account_hash` is a keyed digest and cannot be reversed. To find events for
   an account you can only name by email, compute the digest with the same key:

   ```sql
   select * from public.auth_security_events
   where account_hash = private.auth_normalized_hash('account', :email)
   order by created_at desc limit 50;
   ```

## Suspected account compromise

1. Revoke everything for that user immediately. This sets the watermark and
   revokes every device, so in-flight access tokens stop on their next request:

   ```sql
   select set_config('request.jwt.claim.sub', :user_id, false);
   select private.auth_sign_out_all('suspected_compromise');
   ```

2. Confirm it took effect — `revoked_before` should be now, and no device row
   should have a null `revoked_at`.

3. Look at what the session did, using the append-only log. It cannot have been
   edited: `auth_security_events` refuses UPDATE and DELETE.

4. If a provider identity is implicated, unlink it. Note that a profile's last
   identity cannot be unlinked (`last_identity`), because that would leave an
   account nobody can sign in to; link a replacement first.

5. Record the incident under `docs/evidence/` and, if any real data was
   involved, follow the SEC-001 disclosure procedure in
   `docs/security/sec-001-containment.md`.

## MFA reset for a school administrator

Administrators cannot perform privileged actions at aal1, so a lost
authenticator is a hard block by design.

There is deliberately **no** self-service reset: an unauthenticated MFA reset
is a full bypass of the control. The reset must be performed by an operator who
has verified the person out of band, using the Supabase admin API to delete the
factor, after which the administrator re-enrols in the app under
Account security.

Record who verified the identity, how, and when. A reset with no such record is
indistinguishable from an attacker's reset.

## Provider misconfiguration

Symptoms and where to look:

| Symptom | Likely cause |
|---|---|
| Every token rejected after a provider change | The issuer no longer matches. The API derives it from `SUPABASE_URL`; a project change requires the env var to change with it |
| Rejections begin at a key rotation and clear within a minute | Expected. The JWKS refetch cooldown is 30 seconds; Supabase publishes the new key before issuing tokens signed with it |
| Rejections persist after a rotation | The JWKS endpoint is unreachable. Check `auth_denied` log lines with `reason: jwks_unavailable` |
| The callback opens a browser and returns nothing | The redirect target is not in `additional_redirect_urls`, or the App Link is unverified and the OS chose the browser |
| A callback is ignored entirely | `AuthCallbackGuard` refused it. It only accepts the exact claimed targets — check for a lookalike host, an extra path segment, or `http` |

The provider blocks in `supabase/config.toml` reference environment variable
names only and are `enabled = false` until a console registration exists
(D1/D2). Turning one on without the corresponding credentials fails closed.

## Rolling back the auth surface

The routes mount only when both a database and `SUPABASE_URL` are configured.
Removing `SUPABASE_URL` from a non-production environment disables the whole
authenticated surface without a code change — `/v1` returns `NOT_IMPLEMENTED`
as it did before this part. In production the API refuses to start instead,
which is the intended fail-closed behaviour.

Do **not** roll back by granting the API broader database privileges or by
restoring direct client grants. Both would undo DB-021.

## Verifying the controls still hold

```
bunx supabase start
bun run test:auth030:lifecycle          # 26 end-to-end checks
bunx supabase test db --local supabase/tests/auth030_grants.sql
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  bun test apps/api/test/auth
flutter test test/auth030_deep_link_hijack_test.dart
```

The lifecycle script provisions a throwaway password for
`studafy_api_runtime`, uses it, and clears it again. It refuses to run against
anything but a loopback Supabase URL.
