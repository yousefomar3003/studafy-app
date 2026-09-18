import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to load a FILE-050 fixture outside a local database.",
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

const school = "f0510000-0000-4000-8000-000000000001";
const actor = "f0510000-0000-4000-8000-000000000002";
const membership = "f0510000-0000-4000-8000-000000000003";
const otherSchool = "f0520000-0000-4000-8000-000000000001";
const otherActor = "f0520000-0000-4000-8000-000000000002";
const otherMembership = "f0520000-0000-4000-8000-000000000003";

const sql = postgres(databaseUrl, { max: 1 });
try {
  await sql.begin(async (tx) => {
    await tx.unsafe("set local statement_timeout = '60s'");
    await tx.unsafe(`
      insert into auth.users (
        id,email,encrypted_password,aud,role,email_confirmed_at,created_at,
        updated_at,instance_id,confirmation_token,recovery_token,email_change,
        email_change_token_new,email_change_token_current,phone_change_token,
        raw_app_meta_data,raw_user_meta_data
      ) values
        ('${actor}','file050.plan.owner@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"FILE-050 Owner"}'),
        ('${otherActor}','file050.plan.other@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"FILE-050 Other"}');
      insert into public.schools(id,name,status) values
        ('${school}','FILE-050 Plan School','active'),
        ('${otherSchool}','FILE-050 Other School','active');
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
        'fixture-'||i||'.png','image/png',repeat('a',64),'file050-v1',now()-i*interval '1 hour'
      from (
        select i,md5('file050-a-'||i)::uuid as upload_id,'${school}'::uuid as school_id,
          '${actor}'::uuid as owner_id,'${membership}'::uuid as membership_id
        from generate_series(1,2000) i
        union all
        select i,md5('file050-b-'||i)::uuid,'${otherSchool}'::uuid,
          '${otherActor}'::uuid,'${otherMembership}'::uuid
        from generate_series(1,18000) i
      ) fixture;

      insert into public.file_objects(
        id,school_id,bucket,object_key,uploader_id,owner_id,owner_membership_id,
        purpose,display_name,policy_version,size_bytes,declared_media_type,
        detected_media_type,sha256,scan_state
      )
      select md5('file-object-'||u.id)::uuid,u.school_id,u.bucket,u.object_key,
        u.owner_id,u.owner_id,u.owner_membership_id,'profile_image',u.display_name,
        'file050-v1',1024,'image/png','image/png',repeat('a',64),'rejected'
      from public.upload_sessions u where u.policy_version='file050-v1';

      insert into public.file_job_outbox(school_id,upload_session_id,file_object_id,job_type,state,available_at)
      select u.school_id,u.id,f.id,
        case when u.school_id='${school}' then 'delete' else 'scan' end,
        'pending',now()-interval '1 minute'
      from public.upload_sessions u
      join public.file_objects f on f.school_id=u.school_id and f.object_key=u.object_key
      where u.policy_version='file050-v1';

      analyze public.upload_sessions;
      analyze public.file_objects;
      analyze public.file_job_outbox;
    `);

    const cases = [
      {
        name: "owner_status",
        index: "file050_upload_owner_state_idx",
        query: `select id from public.upload_sessions
          where owner_id=$1 and state='initiated' and expires_at>now()
          order by expires_at,id limit 50`,
        args: [actor],
      },
      {
        name: "school_rolling_quota",
        index: "file050_upload_school_created_idx",
        query:
          `select coalesce(sum(expected_size_bytes),0) from public.upload_sessions
          where school_id=$1 and created_at>=now()-interval '24 hours'`,
        args: [school],
      },
      {
        name: "expiry_sweep",
        index: "file050_upload_expiry_active_idx",
        query: `select id from public.upload_sessions
          where state='initiated' and expires_at<=$1 order by expires_at,id limit 50`,
        args: [new Date(Date.now() + 3 * 60 * 60 * 1000)],
      },
      {
        name: "owner_file_status",
        index: "file050_file_owner_created_idx",
        query: `select id from public.file_objects
          where owner_id=$1 order by created_at desc,id desc limit 50`,
        args: [actor],
      },
      {
        name: "cleanup_claim",
        index: "file050_file_job_claim_idx",
        query: `select id from public.file_job_outbox
          where job_type='delete' and state in ('pending','retry') and available_at<=now()
          order by available_at,id limit 50`,
        args: [],
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
            planNodes.map((node) => node["Index Name"]).filter(Boolean).join(
              ",",
            )
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
      event: "file050_query_plan_check",
      target: "local_disposable",
      target_tenant_rows: 2000,
      background_rows: 18000,
      measurements,
    }));
    throw new Error("FILE050_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) || error.message !== "FILE050_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
