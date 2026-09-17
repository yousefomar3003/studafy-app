/**
 * FILE-051 storage reconciliation. A database row is not proof of physical
 * deletion, and a stored object is not proof of a row, so this compares the
 * private bucket's object index with the file tables and reports drift:
 *
 *  - orphan_objects: bytes with no upload session at all;
 *  - deleted_rows_with_bytes: rows recorded as physically deleted whose
 *    bytes still exist (including deduplicated dependents);
 *  - settled_sessions_with_bytes: expired/rejected sessions whose deletion
 *    is no longer in flight but whose bytes remain;
 *  - clean_roots_missing_bytes: deliverable objects whose bytes are gone;
 *  - dependents_without_cleanup: deduplicated rows still holding bytes with
 *    no deletion queued.
 *
 * Every count must be zero. Run against the local disposable stack only.
 */
import type { Sql } from "@studafy/database";

export interface ReconciliationReport {
  orphan_objects: number;
  deleted_rows_with_bytes: number;
  settled_sessions_with_bytes: number;
  clean_roots_missing_bytes: number;
  dependents_without_cleanup: number;
}

export async function reconcile(sql: Sql): Promise<ReconciliationReport> {
  const rows = await sql<Record<keyof ReconciliationReport, string>[]>`
    with objects as (
      select o.name as object_key from storage.objects o
      where o.bucket_id = 'private-school-files' and o.name like 'quarantine/v1/%'
    ), in_flight as (
      select j.file_object_id, j.upload_session_id from public.file_job_outbox j
      where j.state in ('pending', 'retry', 'processing')
    )
    select
      (select count(*) from objects o
        where not exists (select 1 from public.upload_sessions u
          where u.bucket = 'private-school-files' and u.object_key = o.object_key)
      ) as orphan_objects,
      (select count(*) from objects o
        join public.file_objects f
          on f.bucket = 'private-school-files' and f.object_key = o.object_key
        where (f.physical_deleted_at is not null or f.scan_state = 'deleted')
          and not exists (select 1 from in_flight i where i.file_object_id = f.id)
      ) as deleted_rows_with_bytes,
      (select count(*) from objects o
        join public.upload_sessions u
          on u.bucket = 'private-school-files' and u.object_key = o.object_key
        where u.state in ('expired', 'rejected', 'cancelled')
          and not exists (select 1 from in_flight i where i.upload_session_id = u.id)
          and not exists (select 1 from public.file_objects f
            where f.id = u.file_object_id and f.legal_hold)
      ) as settled_sessions_with_bytes,
      (select count(*) from public.file_objects f
        where f.policy_version <> 'legacy' and f.scan_state = 'clean'
          and f.deleted_at is null and f.dedup_source_file_id is null
          and not exists (select 1 from objects o where o.object_key = f.object_key)
      ) as clean_roots_missing_bytes,
      (select count(*) from public.file_objects f
        where f.dedup_source_file_id is not null and f.scan_state = 'clean'
          and f.physical_deleted_at is null
          and not exists (select 1 from in_flight i where i.file_object_id = f.id)
      ) as dependents_without_cleanup
  `;
  const row = rows[0]!;
  return {
    orphan_objects: Number(row.orphan_objects),
    deleted_rows_with_bytes: Number(row.deleted_rows_with_bytes),
    settled_sessions_with_bytes: Number(row.settled_sessions_with_bytes),
    clean_roots_missing_bytes: Number(row.clean_roots_missing_bytes),
    dependents_without_cleanup: Number(row.dependents_without_cleanup),
  };
}

export function hasDrift(report: ReconciliationReport): boolean {
  return Object.values(report).some((count) => count > 0);
}

if (import.meta.main) {
  const { createDatabase } = await import("@studafy/database");
  const { localSupabase } = await import("./file051-harness");
  const local = await localSupabase();
  const sql = createDatabase(local.dbUrl, { max: 1 });
  try {
    const report = await reconcile(sql);
    console.log(JSON.stringify({
      event: "file051_storage_reconciliation",
      target: "local_disposable",
      drift: hasDrift(report),
      ...report,
    }));
    process.exitCode = hasDrift(report) ? 1 : 0;
  } finally {
    await sql.end({ timeout: 5 });
  }
}
