# Local Edge Function smoke summary

ARC-001 deliverable ("smoke current remote functions with synthetic users").
Evidence date: 2026-09-10. Raw transcripts: `local-functions-raw-2026-09-10.txt`
(all 8 functions, 23 requests) and `remote-synthetic-2026-09-10.txt`
(read-only, 4 requests). Remote results: both deployed functions
(`propose-paper-grade`, `study-coach`) reject missing/garbage authorization
with 401 at the gateway; no valid JWT exists remotely (zero users), so no
authenticated remote path was possible — by design.

## Method (reproducible)

```sh
bunx supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,supavisor
bunx supabase db reset --local --no-seed
bunx supabase test db --local supabase/tests/rls_access_seed.sql   # fixture + GoTrue-compatible users
bunx supabase functions serve            # optionally --env-file with synthetic provider vars
# mint HS256 JWTs with the local stack's default dev JWT secret
# (docker exec supabase_auth_studafy printenv GOTRUE_JWT_SECRET) and the
# fixture user UUIDs; call http://127.0.0.1:54321/functions/v1/<name>
```

## Result matrix (all as expected)

| Function | Case | Expected | Actual |
|---|---|---|---|
| `propose-paper-grade` | OPTIONS preflight | 200 | 200 |
| | no auth | 401 (gateway verify_jwt) | 401 |
| | valid teacher JWT + substituted `papers/other-teacher/scan.pdf` | 503 `AI_GRADING_DISABLED`, path never echoed | 503, no echo |
| `study-coach` | no auth / garbage bearer | 401 | 401 / 401 |
| | unsupported action | 422 | 422 |
| | attachment path (provider unconfigured) | contained 503 before provider config | 503 contained |
| | attachment path (provider configured) | contained 503 before enrollment/provider call | 503 contained |
| | provider unconfigured | 503 not configured | 503 |
| | teacher requests own classroom | 403 not enrolled (server-side enrollment check) | 403 |
| | enrolled student, no filed materials | 409 no authorized material | 409 |
| `create-google-meet` | no auth | 401 | 401 |
| | nonexistent classroom | 403 teacher access required | 403 |
| | real classroom, broker unconfigured | 503 fail-closed | 503 |
| `approve-paper-grade` | no auth | 401 | 401 |
| | nonexistent draft | 403 review access required | 403 |
| `publish-grade-result` | no auth | 401 | 401 |
| | nonexistent grade | 403 teacher access required | 403 |
| | already-published grade | 409 must be reviewed first (state machine) | 409 |
| `verify-store-purchase` | no auth | 401 | 401 |
| | verifier unconfigured | 503 fail-closed | 503 |
| `request-account-deletion` | stale-`iat` token (1 h old) | 401 reauthentication required | 401 |
| | wrong typed confirmation | 422 | 422 |
| | fresh token + `DELETE` | creates grace request + audit (local synthetic) | 200; `account_deletion_requests` row in `grace_period` with `execute_after > now()`, audit row `account_deletion_requested` |

## Observations registered

1. **Wildcard CORS confirmed live**: every response (including the kill
   switch) carries `Access-Control-Allow-Origin: *` — already registered as an
   API-040 finding in the data-flow inventory.
2. **The kill switch holds under authentication**: a valid teacher JWT with a
   substituted cross-teacher private path still receives only the stable 503;
   the body is not read and no path is echoed.
3. **Server-side authorization is real for current DB-touching paths**
   (enrollment, teacher ownership, grade state machine), consistent with the
   RLS matrix — but the known weaknesses (no idempotency, sequential writes,
   `iat`-based recent-auth) remain registered for Phase 3/6.
4. Fixtures must be GoTrue-compatible for function smoke: `instance_id`
   zero-uuid, non-NULL varchar token columns, `updated_at` set. The seed now
   guarantees this (see `rls_access_seed.sql`).
