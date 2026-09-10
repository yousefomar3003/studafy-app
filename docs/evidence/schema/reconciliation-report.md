# Schema reconciliation report — live vs repo

ARC-001 deliverable. Evidence date: 2026-09-10. Method: read-only `pg_dump`
(schema-only) of the local disposable stack (migrations replayed from zero
with `db reset --local --no-seed`) and of the linked remote synthetic project
`eamewgaptdfqzpmayavx`, then a plain `diff`. No writes, no data copying, no
PII. Approval: decision-log DL-004.

## Evidence files

| File | Content |
|---|---|
| `local-baseline-2026-09-10.sql` | Schema-only dump, local stack, 1,896 lines |
| `remote-synthetic-2026-09-10.sql` | Schema-only dump, remote synthetic project, 1,938 lines |
| `local-vs-remote-diff-2026-09-10.txt` | Full diff, 46 lines |

## Result: reconciled

The replayed repository migrations and the remote synthetic project produce
**structurally identical schemas**. The complete delta is a single
platform-managed object:

- `public.rls_auto_enable()` event-trigger function (with `GRANT ALL` to
  `anon`, `authenticated`, `service_role`) exists on the remote project but
  not in the local stack. This is Supabase platform-created (it auto-enables
  RLS on newly created public tables), not part of the repository migrations.

No table, policy, function, index, enum, or grant from the seven repository
migrations differs between local replay and the remote project. There is no
schema drift to correct.

## Row/cardinality estimates (read-only, no PII)

`supabase inspect db table-stats --linked` (Management API, read-only):
**every public table reports an estimated row count of 0** — consistent with
the SEC-001 deployment record (zero auth users, schools, profiles, storage
objects). Auth/storage schema tables are platform-managed and contain no
application rows.

## Verification commands (reproducible)

```sh
bunx supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,supavisor
bunx supabase db reset --local --no-seed
bunx supabase db lint --local --level error --fail-on error   # No schema errors found
bunx supabase db dump --local -f <local-dump>
bunx supabase db dump --linked -f <remote-dump>               # read-only
diff <local-dump> <remote-dump>
bunx supabase inspect db table-stats --linked
```

## Open items registered from reconciliation (input to DB-020/021)

1. **`rls_auto_enable()` platform object** — the remote-only event trigger and
   its broad EXECUTE grants are platform-created. Requires Supabase-specific
   review before any privilege change; do not drop or re-create it in a repo
   migration. (Also flagged by the SEC-001 advisors.)
2. **Public/anon EXECUTE on 5 SECURITY DEFINER helpers** — `is_school_member`,
   `is_class_teacher`, `can_access_student`, `can_access_classroom`,
   `handle_new_auth_user` are reconciled as deployed but carry unnecessary
   public execute privileges. Removal belongs to a Phase 2 forward migration
   (`DB-021`), not an edit of applied migrations.
3. **Two explicit indexes only** (`meeting_deliveries_recipient_idx`,
   `account_deletion_due_idx`); all RLS relationship paths are unindexed.
   Query-plan evidence: `docs/evidence/baselines/query-plans.md` (DB-020).
4. **`students.school_id` nullable and no composite same-school foreign keys**
   — confirmed present in both environments; forward migration required
   (DB-020).

## Boundary statement

This reconciliation covers the **synthetic** remote project only. No
development, staging, or production environment exists (ADR-0004); when one is
created, this report must be regenerated against it before first use.
