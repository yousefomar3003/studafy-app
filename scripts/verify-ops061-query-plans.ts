import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to load an OPS-061 fixture outside a local database.",
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

const school = "61061000-0000-4000-8000-00000000f001";
const otherSchool = "61061000-0000-4000-8000-00000000f002";
const admin = "61061000-0000-4000-8000-00000000f101";
const otherAdmin = "61061000-0000-4000-8000-00000000f102";

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
        ('${admin}','ops061.plan.admin@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"OPS-061 Admin"}'),
        ('${otherAdmin}','ops061.plan.other@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"OPS-061 Other"}');
      insert into public.schools(id,name,status) values
        ('${school}','OPS-061 Plan School','active'),
        ('${otherSchool}','OPS-061 Other Plan School','active');
      insert into public.memberships(school_id,user_id,role,active,status) values
        ('${school}','${admin}','school_admin',true,'active'),
        ('${otherSchool}','${otherAdmin}','school_admin',true,'active');

      -- 2000 dispatchable rows for the measured school and 18000 for the
      -- untouched school: the claim must index into the ready rows, not scan.
      insert into public.notification_outbox(
        school_id,source_event_id,idempotency_key,channel,template_key,audience,payload,
        state,next_attempt_at
      )
      select '${school}'::uuid,'ops061-plan-'||i,'ops061-plan-'||i,'in_app',
        'school_admin.membership_granted',
        jsonb_build_object('schoolId','${school}'::uuid),'{}'::jsonb,
        case when i <= 100 then 'pending'::public.outbox_state
             else 'completed'::public.outbox_state end,
        now() - interval '1 minute'
      from generate_series(1,2000) i
      union all
      select '${otherSchool}'::uuid,'ops061-plan-b-'||i,'ops061-plan-b-'||i,'in_app',
        'school_admin.membership_granted',
        jsonb_build_object('schoolId','${otherSchool}'::uuid),'{}'::jsonb,
        'pending'::public.outbox_state, now() - interval '1 minute'
      from generate_series(1,18000) i;

      analyze public.notification_outbox;
      analyze public.notification_deliveries;
    `);

    const cases = [
      {
        name: "outbox_dispatch_claim",
        index: "db020_notification_outbox_ready",
        query: `select id from public.notification_outbox
          where recipient_id is null and audience is not null and channel='in_app'
            and state in ('pending','retry') and next_attempt_at <= now()
          order by next_attempt_at, id limit 50`,
        args: [],
      },
      {
        name: "dlq_list",
        index: "ops061_outbox_dlq_idx",
        query: `select id from public.notification_outbox
          where recipient_id is null and audience is not null and state='dead_letter'
          order by id limit 100`,
        args: [],
      },
      {
        name: "audience_resolver",
        index: null,
        query: `select m.user_id from public.memberships m
          join public.profiles p on p.id = m.user_id and p.status = 'active'
          where m.school_id = $1 and m.active and m.status = 'active'
            and m.role in ('school_admin','teacher')`,
        args: [school],
      },
      {
        name: "outbox_backlog",
        index: null,
        query: `select
          (select count(*) from public.notification_outbox
            where recipient_id is null and audience is not null and state='pending') as pending,
          (select coalesce(extract(epoch from now() - min(next_attempt_at))::bigint, 0)
            from public.notification_outbox
            where recipient_id is null and audience is not null
              and state in ('pending','retry')) as oldest`,
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
      const all = nodes(report.Plan);
      const used = testCase.index
        ? all.some((node) => node["Index Name"] === testCase.index)
        : true;
      const serialized = {
        name: testCase.name,
        planningTimeMs: report["Execution Time"],
        indexUsed: used,
        expectedIndex: testCase.index,
      };
      measurements.push(serialized);
      if (!used) {
        throw new Error(
          `${testCase.name} did not use ${testCase.index ?? "an index"}`,
        );
      }
    }

    const outbox = measurements.find((m) => m.name === "outbox_dispatch_claim");
    if (outbox && Number(outbox.planningTimeMs) > 50) {
      throw new Error(
        `outbox_dispatch_claim took ${outbox.planningTimeMs}ms, over the 50ms provisional bound.`,
      );
    }

    console.log(JSON.stringify({ suite: "ops061-query-plans", measurements }));
    // Every dispatchable fixture row would otherwise be real outbox work for
    // a running worker, so the fixture rolls back whole like the other plan
    // scripts.
    throw new Error("OPS061_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) || error.message !== "OPS061_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
