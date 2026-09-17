import postgres from "postgres";

/**
 * FILE-051 query-plan check. Loads a disposable 20k-object fixture inside a
 * transaction that always rolls back, then proves the hot FILE-051 lookups
 * (grant consume, scan claim, dedupe root, dependents, retention and grant
 * expiry sweeps) are index-backed and inside the provisional bound.
 */
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to load a FILE-051 fixture outside a local database.",
  );
}

type Plan = {
  "Node Type": string;
  "Index Name"?: string;
  Plans?: Plan[];
};
type Explain = { Plan: Plan; "Execution Time": number };

function nodes(plan: Plan): Plan[] {
  return [plan, ...(plan.Plans ?? []).flatMap(nodes)];
}

const school = "f0510000-0000-4000-9000-000000000001";
const actor = "f0510000-0000-4000-9000-000000000002";
const membership = "f0510000-0000-4000-9000-000000000003";
const otherSchool = "f0510000-0000-4000-9000-000000000011";
const otherActor = "f0510000-0000-4000-9000-000000000012";
const otherMembership = "f0510000-0000-4000-9000-000000000013";
const hotSha = "c".repeat(64);
const hotNonce = "d".repeat(64);

const sql = postgres(databaseUrl, { max: 1 });
try {
  await sql.begin(async (tx) => {
    await tx.unsafe("set local statement_timeout = '120s'");
    await tx.unsafe(`
      insert into auth.users (
        id,email,encrypted_password,aud,role,email_confirmed_at,created_at,
        updated_at,instance_id,confirmation_token,recovery_token,email_change,
        email_change_token_new,email_change_token_current,phone_change_token,
        raw_app_meta_data,raw_user_meta_data
      ) values
        ('${actor}','file051.plan.owner@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"FILE-051 Owner"}'),
        ('${otherActor}','file051.plan.other@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"FILE-051 Other"}');
      insert into public.schools(id,name,status) values
        ('${school}','FILE-051 Plan School','active'),
        ('${otherSchool}','FILE-051 Other School','active');
      insert into public.memberships(id,school_id,user_id,role,active,status) values
        ('${membership}','${school}','${actor}','teacher',true,'active'),
        ('${otherMembership}','${otherSchool}','${otherActor}','teacher',true,'active');

      insert into public.upload_sessions(
        id,school_id,uploader_id,owner_id,owner_membership_id,purpose,
        expected_size_bytes,allowed_media_types,nonce_hash,state,expires_at,
        bucket,object_key,display_name,declared_media_type,expected_sha256,policy_version,created_at
      )
      select upload_id,school_id,owner_id,owner_id,membership_id,'profile_image',1024,
        array['image/png'],md5(i::text||school_id::text),'initiated',now()+interval '2 hours',
        'private-school-files','quarantine/v1/'||upload_id||'/'||lpad(i::text,22,'a'),
        'fixture-'||i||'.png','image/png',sha,'file050-v1',now()-i*interval '1 minute'
      from (
        select i,md5('file051-a-'||i)::uuid as upload_id,'${school}'::uuid as school_id,
          '${actor}'::uuid as owner_id,'${membership}'::uuid as membership_id,
          case when i % 50 = 0 then '${hotSha}' else md5('a'||i)||md5('b'||i) end as sha
        from generate_series(1,2000) i
        union all
        select i,md5('file051-b-'||i)::uuid,'${otherSchool}'::uuid,
          '${otherActor}'::uuid,'${otherMembership}'::uuid,
          case when i % 50 = 0 then '${hotSha}' else md5('c'||i)||md5('d'||i) end
        from generate_series(1,18000) i
      ) fixture;

      insert into public.file_objects(
        id,school_id,bucket,object_key,uploader_id,owner_id,owner_membership_id,
        purpose,display_name,policy_version,size_bytes,declared_media_type,
        detected_media_type,sha256,scan_state,scanned_at,scan_policy_version,
        stored_sha256,stored_size_bytes,retention_until
      )
      select md5('file-object-'||u.id)::uuid,u.school_id,u.bucket,u.object_key,
        u.owner_id,u.owner_id,u.owner_membership_id,'profile_image',u.display_name,
        'file050-v1',1024,'image/png','image/png',u.expected_sha256,
        (case when right(u.object_key,2) = '01' then 'quarantined' else 'clean' end)::public.file_scan_state,
        now(),'file051-v1',u.expected_sha256,1024,
        case when right(u.object_key,1) = '5' then now() + interval '30 days' end
      from public.upload_sessions u where u.policy_version='file050-v1'
        and u.school_id in ('${school}','${otherSchool}');

      insert into public.file_job_outbox(school_id,upload_session_id,file_object_id,job_type,state,available_at)
      select u.school_id,u.id,f.id,'scan',
        (case when f.scan_state='quarantined' then 'pending' else 'completed' end)::public.outbox_state,
        now()-interval '1 minute'
      from public.upload_sessions u
      join public.file_objects f on f.school_id=u.school_id and f.object_key=u.object_key;

      insert into public.file_delivery_grants(school_id,file_object_id,recipient_id,nonce_hash,expires_at)
      select f.school_id,f.id,f.owner_id,
        case when row_number() over () = 1 then '${hotNonce}' else md5('g'||f.id)||md5('h'||f.id) end,
        now()+interval '5 minutes'
      from public.file_objects f
      where f.scan_state='clean' and f.school_id in ('${school}','${otherSchool}');

      analyze public.upload_sessions;
      analyze public.file_objects;
      analyze public.file_job_outbox;
      analyze public.file_delivery_grants;
    `);

    const root = (await tx<{ id: string }[]>`
      select id from public.file_objects where school_id=${school} limit 1
    `)[0]!.id;

    const cases = [
      {
        name: "grant_consume",
        index: "file_delivery_grants_nonce_hash_key",
        query: `select id from public.file_delivery_grants
          where nonce_hash=$1 and state='available' and expires_at>now()`,
        args: [hotNonce],
      },
      {
        name: "grant_expiry_sweep",
        index: "file051_delivery_grant_expiry_idx",
        query: `select id from public.file_delivery_grants
          where state='available' and expires_at<=$1 order by expires_at,id limit 100`,
        args: [new Date(Date.now() - 60 * 60 * 1000)],
      },
      {
        name: "scan_claim",
        index: "file050_file_job_claim_idx",
        query: `select id from public.file_job_outbox
          where job_type='scan' and state in ('pending','retry') and available_at<=now()
          order by available_at,id limit 10`,
        args: [],
      },
      {
        name: "dedupe_root_lookup",
        index: "file051_file_dedup_root_idx",
        query: `select id from public.file_objects c
          where c.school_id=$1 and c.sha256=$2 and c.purpose='profile_image'
            and c.scan_state='clean' and c.deleted_at is null and c.legal_hold=false
            and c.dedup_source_file_id is null and c.id<>$3
          order by c.created_at,c.id limit 1`,
        args: [school, hotSha, root],
      },
      {
        name: "dedupe_dependents",
        index: "file051_file_dedup_source_idx",
        query:
          `select id from public.file_objects where dedup_source_file_id=$1`,
        args: [root],
      },
      {
        name: "retention_candidates",
        index: "file051_file_retention_idx",
        query: `select id from public.file_objects r
          where r.scan_state='clean' and r.deleted_at is null
            and r.dedup_source_file_id is null
            and r.retention_until is not null and r.retention_until<=$1
          order by r.retention_until,r.id limit 5`,
        args: [new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)],
      },
    ] as const;

    const measurements: Record<string, unknown>[] = [];
    for (const testCase of cases) {
      const rows = await tx.unsafe(
        `explain (analyze, buffers, format json) ${testCase.query}`,
        [...testCase.args],
      );
      const report = rows[0]?.["QUERY PLAN"]?.[0] as Explain | undefined;
      if (!report) throw new Error(`Missing EXPLAIN for ${testCase.name}.`);
      const planNodes = nodes(report.Plan);
      if (!planNodes.some((node) => node["Index Name"] === testCase.index)) {
        throw new Error(
          `${testCase.name} did not use ${testCase.index}; used ${
            planNodes.map((node) => node["Index Name"] ?? node["Node Type"])
              .join(",")
          }.`,
        );
      }
      if (report["Execution Time"] >= 50) {
        throw new Error(
          `${testCase.name} exceeded the provisional 50ms bound.`,
        );
      }
      measurements.push({
        query: testCase.name,
        index: testCase.index,
        execution_ms: report["Execution Time"],
        nodes: planNodes.map((node) => node["Node Type"]),
      });
    }
    console.log(JSON.stringify({
      event: "file051_query_plan_check",
      target: "local_disposable",
      target_tenant_rows: 2000,
      background_rows: 18000,
      measurements,
    }));
    throw new Error("FILE051_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) || error.message !== "FILE051_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
