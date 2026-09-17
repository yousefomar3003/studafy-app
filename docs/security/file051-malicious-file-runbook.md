# FILE-051 malicious-file response runbook

What to do when a file is, or may be, hostile. This covers two situations:
the scanner rejects a file when it is uploaded, and a file that already
passed scanning (and may have been published and downloaded) is found to be
hostile later.

Written for a **local or disposable** environment. No production environment
exists yet (DL-009, DL-024). Before this runbook is used against real accounts
or real children's data, it needs a named, separate on-call owner, an
approval path for containment and release, and the notification contacts
from the legal work in §15.

Owner: repository owner (`@yousefomar3003`), single-owner project.

The procedure is rehearsed end to end by `bun run test:file051:drill`
(`apps/api/scripts/file051-malware-drill.ts`), which must report `passed: true`.

## Vocabulary

| Term | Meaning |
|---|---|
| Quarantined | `file_objects.scan_state` is `quarantined` or `scanning`. Nobody can publish or download the file. |
| Clean | The scan worker recorded a verdict with a scan policy version and a verified stored digest. This is the only state that can be published or delivered. |
| Rejected | The scanner found malware, a malformed or polyglot file, active content, encryption, an embedded file, or a decompression bomb. The state is terminal. |
| Contained | An operator moved the file out of `clean` (`scan_state = 'error'`, `scan_error_code = 'operator_contained'`) and put it under legal hold. |
| Dedupe group | A root object plus every row whose `dedup_source_file_id` points at it. They share one set of physical bytes, so they are always contained, released and deleted together. |
| Grant | One row in `file_delivery_grants`. It allows one download link to be used once, by one recipient, before it expires. The row stores only a hash of the link's nonce. |
| Operator session | A direct, audited `postgres` session on the database. The containment functions are granted to no runtime role. |

## Detection signals

| Signal | Where | Meaning |
|---|---|---|
| `file_scan_rejected` audit event | `public.audit_events` | The upload-time scan rejected the file. `after_value.failureCode` says why. |
| `file_scan_backlog` worker log | worker JSON logs, once a minute | Shows `quarantined`, `oldest_quarantine_seconds`, `scan_dead_letters`, `delete_dead_letters` and `dedupe_bytes_pending`. |
| `file_scan_failed` audit event | `public.audit_events` | The scanner was unavailable ten times in a row. The file is now `error`, never `clean`. |
| Scanner provider advisory | the provider | New signatures may flag a file that was already scanned clean. |
| A user or safeguarding report | SAFE-043 queue | A person reported a file. |
| Reconciliation drift | `bun run test:file051:reconcile` | Bytes exist with no row behind them, or a row exists whose bytes are gone. |

There is no alerting pipeline yet (OPS-090). Until there is, these signals
are found by query and by reading logs, not by being paged.

## 1. Triage

```sql
select id, school_id, owner_id, purpose, display_name, detected_media_type,
       sha256, stored_sha256, scan_state, scan_error_code, scan_policy_version,
       transform_policy_version, dedup_source_file_id, legal_hold, created_at
from public.file_objects where id = :file_id;
```

- **`rejected` or `quarantined`:** nobody has received the bytes. Go to
  step 4 if you need to keep the bytes as evidence. Otherwise the cleanup
  worker is already deleting them.
- **`clean`:** the file may be published and may have been downloaded. Go
  to step 2 immediately. Contain first, investigate second.

## 2. Contain (clean or published files)

```sql
select private.file051_contain_object(:file_id, :operator_user_id, :reason);
```

This single transaction does all of the following for the **whole dedupe
group**:

- moves every member out of `clean`, so every delivery and publication path
  denies at once;
- withdraws every publication of those files, together with its resource;
- expires every outstanding grant, so links already handed out stop working
  immediately;
- puts every member under legal hold, so the cleanup worker cannot delete
  the evidence;
- writes a `file_contained` audit event naming the operator and the reason.

The function returns how many publications it withdrew and how many grants
it expired. The drill measures containment in single-digit milliseconds.

If the pattern is broad (many files, one scanner gap), also turn off the
switches below. Each is a reviewed config change, not a code change.

| Switch | Effect |
|---|---|
| `FILE051_DELIVERY_ENABLED=false` | No new download links are issued, and the delivery endpoint answers `404`. |
| `FILE051_PUBLISH_ENABLED=false` | No new publications. |
| `FILE050_NEW_INTENTS_ENABLED=false` | No new uploads. Uploads already in flight still complete and settle. |

Scanning stays on. Turning it off only lengthens quarantine, and nothing
becomes `clean` without it.

## 3. Scope: who received the bytes

```sql
-- Every delivery of any file in the group.
select e.actor_id, e.entity_id, e.created_at, e.request_id
from public.audit_events e
where e.action = 'file_download_delivered'
  and e.entity_id in (
    select id from public.file_objects
    where id = :root_id or dedup_source_file_id = :root_id)
order by e.created_at;

-- Links issued but never used (already expired by containment).
select recipient_id, state, expires_at, consumed_at
from public.file_delivery_grants
where file_object_id in (
  select id from public.file_objects
  where id = :root_id or dedup_source_file_id = :root_id);

-- Other files with the same content in the same school.
select id, owner_id, purpose, scan_state from public.file_objects
where school_id = :school_id and sha256 = :sha256;
```

Deduplication never crosses schools. A hash match in another school is a
separate object with a separate audit trail, and must be contained with its
own `file051_contain_object` call. Search for it by hash only as an
operator, and never disclose one school's finding to another school.

## 4. Preserve evidence

Contained files are held (`legal_hold = true`). The cleanup claim and the
retention sweep both skip held objects, so the bytes stay exactly where the
scanner found them. To hold a rejected file before its deletion runs:

```sql
update public.file_objects set legal_hold = true where id = :file_id;
```

A rejection that is already held never queues a deletion. If the file is
tied to a SAFE-043 report or a safeguarding concern, coordinate with that
runbook's legal-hold path before releasing anything.

## 5. Notify

Recipients from step 3 and their school's administrators are notified
through the school's safeguarding contact. Whether a DPIA, regulator or
parent notification is required is a legal decision (§15, SEC-091). That
process does not exist yet, so a real incident must be escalated to the
repository owner and legal counsel before anyone else is told.

## 6. Release and eradicate

Only after the evidence has been preserved elsewhere, or is no longer
needed:

```sql
select private.file051_release_contained_object(:file_id, :operator_user_id);
```

This lifts the hold and queues exact-key deletion for every member that
still has bytes. Dependents whose redundant copies were already removed go
straight to `deleted`. The cleanup worker deletes each object by the key
resolved from its own claim, never from a payload. A row becomes `deleted`
only after storage confirms the deletion.

## 7. Verify and record

1. Run `bun run test:file051:reconcile`. Every count must be `0`.
2. Read the audit trail and confirm it is complete:

   ```sql
   select action, actor_id, created_at from public.audit_events
   where entity_id = :root_id order by id;
   ```

   It should show `file_contained` and `file_containment_released`, both
   attributed to the operator.
3. Add a decision-log entry if a switch was turned off or a scan policy
   changed.
4. Turn the switches back on only through the same reviewed change process.

## Rescanning after a policy change

A new scan or transform policy version never marks unknown files clean, and
never re-marks a file clean without a new verdict. To rescan a file under the
new policy, contain it first, then either release it for deletion or ask the
owner to upload it again. An in-place "requeue to clean" path is
deliberately not provided.

If a scan policy change needs to be rolled back, revert the scanner version.
Files scanned under the reverted version stay `clean`, and files that were
rejected stay rejected. Contain individually if in doubt.

## Rolling back the FILE-051 surface

1. Turn off `FILE051_DELIVERY_ENABLED` and `FILE051_PUBLISH_ENABLED`.
   Existing links die at their next use, because the delivery endpoint
   answers `404` while delivery is off.
2. Turn off `FILE051_SCAN_ENABLED` only if the scanner itself is at fault.
   Files then stay quarantined; none are marked clean.
3. Turn off `FILE051_RETENTION_ENABLED` if the retention sweep is suspect.
   No retention schedule is configured yet in any case.
4. The migration is forward-only. Do not drop `file_delivery_grants`: it is
   the record of who was able to download what.
