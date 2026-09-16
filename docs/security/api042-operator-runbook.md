# API-042 school operations operator runbook

Covers school provisioning, invitation abuse response, support-access
approval, and reviewer-tenant refresh. Every command here is written for a
**local or disposable** environment. No production environment exists yet
(DL-009, DL-024); when one does, these procedures need a named, separated
on-call owner and an approval path before they are used against real
accounts.

Owner: repository owner (`@yousefomar3003`), single-owner project. Production
use requires re-recording with named, separated owners.

## Vocabulary

| Term | Meaning |
|---|---|
| Platform operator | `public.platform_operators` row. Never granted through any API — a deliberate, out-of-band, service-role-only SQL operation |
| AAL2 (support access) | The session must have actually presented a second factor *this request* — not merely be MFA-enrolled. Checked unconditionally, not by role policy |
| Two-person approval | A `support_access_grants` row can only be approved by a platform operator who is not its own requester (`private.is_second_approver`) |
| `school_admin_privileged` | The recent-auth purpose school closure/suspension consumes. Minted via `POST /v1/auth/reauth/challenge` |

## Provisioning a school

1. The requesting identity must already be a platform operator. There is no
   self-service or API path to grant this — insert it directly, having
   verified the request out of band:

   ```sql
   insert into public.platform_operators (user_id, note)
   values (:operator_user_id, 'why, and who approved it');
   ```

2. Have that operator authenticate normally and call
   `POST /v1/schools` with `initialAdminUserId` set to the profile that
   should own the school. The target must already have a `profiles` row
   (created automatically on signup) — `provisionSchool` returns `invalid`
   otherwise, not a stack trace.
3. The new school has no term and no classroom. The school's own admin (not
   the platform operator) calls `POST /v1/schools/{schoolId}/terms` and then
   `POST /v1/classrooms` before any class-level work is possible — see
   "Roster prerequisite" in `docs/api/v1-school-operations-contract.md` for
   why this is a separate, required step rather than something
   `provisionSchool` does for you.

## Suspending or closing a school

Both require a fresh recent-auth grant (`x-studafy-reauth`, purpose
`school_admin_privileged`) in addition to being a platform operator or that
school's own active admin — see `docs/api/v1-school-operations-contract.md`
for why suspension does not additionally require a standing second factor.

```
POST /v1/auth/reauth/challenge   {"purpose": "school_admin_privileged"}
POST /v1/schools/{schoolId}/suspend   (x-studafy-reauth: <grant>)  {"expectedVersion": N}
```

**A school's own admin loses standing the moment it is suspended.**
`is_school_admin()` requires `schools.status = 'active'` (DB-021); a
suspended school's admin cannot re-suspend, close, or reactivate it — only a
platform operator can act on it from that point. This is not a bug to route
around; verify the operator has platform-operator standing before assuming a
"closure is stuck" report is anything else.

## Invitation abuse response

Symptoms and where to look:

| Symptom | Likely cause / check |
|---|---|
| An email reports invitations they never asked for | Check `public.invitations` for the school/inviter; `revokeInvitation` immediately, then review the inviting admin's recent `audit_events` |
| An invitation link is being brute-forced | Tokens are 32-byte opaque, hashed at rest; `attempt_count` on the row bounds guesses per invitation. A sustained pattern across many invitations is an application-layer rate-limit gap (Redis-backed enforcement is Phase 6 — today's budget is the DB-backed per-row counter only) |
| A revoked/expired invitation is still being accepted | Should not happen — `acceptInvitation` checks hash, expiry and status atomically. If it does, treat as a real defect, not a config issue, and stop trusting that migration's `acceptInvitation` case until reviewed |
| An invited role doesn't match who accepted | Expected by design: `acceptInvitation` is token-bound, not email-bound (`profiles` carries no email to match). The token is the entire credential — treat any leaked token as equivalent to a leaked password for that one-time grant |

To audit who issued what:

```sql
select id, email, role, status, invited_by, expires_at, attempt_count
from public.invitations where school_id = :school_id order by created_at desc;
```

## Support-access approval

1. The requester calls `POST /internal/support-access` as a platform
   operator with a verified second factor this session (`aal2`), a reason
   (8–2000 chars) and a ticket reference. `requiresSecondApprover` defaults
   to `true`.
2. A **different** platform operator — verified out of band as usual —
   reviews the reason/ticket and calls
   `POST /internal/support-access/{id}/approve`, also with `aal2` true this
   session. `private.is_second_approver` refuses the original requester
   outright; there is no override.
3. Only the original requester can start the session
   (`POST /internal/support-access/{id}/start`) once approved.
4. Either a platform operator or the affected school's own admin can revoke
   at any point (`POST /internal/support-access/{id}/revoke`).
5. Grants expire on their own (`expiresAt`, 1–480 minutes, requested at
   creation) but only lazily — `private.lazily_expire_support_access` runs
   the next time that school's grants are touched by any of the commands
   above, not on a schedule. There is no OPS-061 scheduler yet. If a grant
   needs to be confirmed dead *right now* rather than at the next touch,
   revoke it explicitly rather than waiting.

To audit a school's grant history:

```sql
select id, requested_by, approved_by, status, reason, ticket_ref, expires_at,
       started_at, ended_at
from public.support_access_grants where school_id = :school_id
order by created_at desc;
```

## Reviewer-tenant refresh

`scripts/seed-reviewer-tenant.ts` provisions one deterministic school with
one account per role, entirely through the real commands — see the script's
own docstring and `docs/evidence/phase-4/api042-verification.md` for what it
proves by succeeding.

```
bunx supabase start
bun scripts/seed-reviewer-tenant.ts --local            # idempotent: leaves an existing tenant alone
bun scripts/seed-reviewer-tenant.ts --local --reset     # wipe and reprovision fresh
```

- Refuses outright if `ENVIRONMENT=production`. Do not attempt to run this
  against a production project by unsetting or overriding that check.
- Credentials are fixed and printed at the end (`reviewer.<role>@synthetic.
  studafy.test`, one shared password) — not a secret, since the tenant only
  ever exists in a non-production environment. The `reviewer.seed-operator@…`
  identity is provisioning-only; never hand it to a reviewer.
- If the script fails partway through, prefer `--reset` over manual cleanup:
  it removes the tenant's rows in dependency order (guardian links →
  students → enrollments → classroom staff → classrooms → terms →
  invitations → idempotency/outbox rows → membership/audit events →
  memberships → the school itself) inside one transaction.
- Today's mode is `--local` only. A remote/staging non-production project
  needs the same wiring pointed at `DATABASE_URL`/`SUPABASE_URL`/
  `SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_PUBLISHABLE_KEY` by hand; this is not
  implemented as a script flag yet.

## Rolling back the API-042 surface

Every module mounts behind its own `API042_<NAME>_ENABLED` flag
(`packages/config/src/index.ts`); flipping one to `false` and restarting the
API returns `SERVICE_UNAVAILABLE` for that module's routes only, with every
other module (and AUTH-030/API-040/API-041) unaffected. This is the fastest
way to stop unsafe traffic in one area without a deploy. It does not repair
already-written data — do that with a forward migration or an explicit
correction command, never by editing an applied migration or granting the
runtime a table/column grant to patch around it.
