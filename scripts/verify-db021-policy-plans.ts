import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to load a policy fixture outside a local database.",
  );
}

type PlanNode = {
  "Node Type": string;
  "Relation Name"?: string;
  Plans?: PlanNode[];
};
type ExplainReport = { Plan: PlanNode; "Execution Time": number };
type PolicyCase = {
  name: string;
  actor: string;
  relation: string;
  statement: string;
  parameters: unknown[];
};

function nodes(plan: PlanNode): PlanNode[] {
  return [plan, ...(plan.Plans ?? []).flatMap(nodes)];
}

const school1 = "91000000-0000-4000-8000-000000000001";
const school2 = "91000000-0000-4000-8000-000000000002";
const school3 = "91000000-0000-4000-8000-000000000003";
const term1 = "93000000-0000-4000-8000-000000000001";
const teacher1 = "92000000-0000-4000-8000-000000000001";
const teacher2 = "92000000-0000-4000-8000-000000000002";
const teacher3 = "92000000-0000-4000-8000-000000000003";
const admin1 = "92000000-0000-4000-8000-000000000004";
const studentUser = "92000000-0000-4000-8000-000000000005";
const guardian1 = "92000000-0000-4000-8000-000000000006";
const firstStudent = "95000000-0000-4000-8000-000000000001";
const firstClassroom = "94000000-0000-4000-8000-000000000001";
const firstAssessment = "96000000-0000-4000-8000-000000000001";

const sql = postgres(databaseUrl, { max: 1 });

try {
  await sql.begin(async (tx) => {
    await tx.unsafe("set local statement_timeout = '90s'");
    await tx.unsafe(`
      insert into auth.users (
        id, email, encrypted_password, aud, role, email_confirmed_at,
        created_at, updated_at, instance_id, confirmation_token,
        recovery_token, email_change, email_change_token_new,
        email_change_token_current, phone_change_token,
        raw_app_meta_data, raw_user_meta_data
      ) values
        ('${teacher1}','db021.teacher1@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Teacher 1"}'::jsonb),
        ('${teacher2}','db021.teacher2@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Teacher 2"}'::jsonb),
        ('${teacher3}','db021.teacher3@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Teacher 3"}'::jsonb),
        ('${admin1}','db021.admin1@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Admin"}'::jsonb),
        ('${studentUser}','db021.student1@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Student"}'::jsonb),
        ('${guardian1}','db021.guardian1@synthetic.studafy.test','synthetic-not-a-secret','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}'::jsonb,'{"full_name":"Policy Guardian"}'::jsonb);

      insert into public.schools (id,name,status) values
        ('${school1}','Policy Scale School 1','active'),
        ('${school2}','Policy Scale School 2','active'),
        ('${school3}','Policy Scale School 3','active');

      insert into public.memberships (school_id,user_id,role,active) values
        ('${school1}','${teacher1}','teacher',true),
        ('${school2}','${teacher2}','teacher',true),
        ('${school3}','${teacher3}','teacher',true),
        ('${school1}','${admin1}','school_admin',true),
        ('${school1}','${studentUser}','student',true),
        ('${school1}','${guardian1}','guardian',true);

      insert into public.terms (id,school_id,name,starts_on,ends_on,active) values
        ('93000000-0000-4000-8000-000000000001','${school1}','Scale Term 1','2026-09-01','2027-06-30',true),
        ('93000000-0000-4000-8000-000000000002','${school2}','Scale Term 2','2026-09-01','2027-06-30',true),
        ('93000000-0000-4000-8000-000000000003','${school3}','Scale Term 3','2026-09-01','2027-06-30',true);

      insert into public.classrooms (id,school_id,term_id,name,teacher_id)
      select
        ('94000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        case ((i-1)%3) when 0 then '${school1}'::uuid when 1 then '${school2}'::uuid else '${school3}'::uuid end,
        ('93000000-0000-4000-8000-' || lpad((((i-1)%3)+1)::text,12,'0'))::uuid,
        'Policy Classroom ' || i,
        case ((i-1)%3) when 0 then '${teacher1}'::uuid when 1 then '${teacher2}'::uuid else '${teacher3}'::uuid end
      from generate_series(1,120) i;

      insert into public.classroom_staff (
        school_id,classroom_id,membership_id,user_id,role
      )
      select c.school_id,c.id,m.id,m.user_id,'lead_teacher'
      from public.classrooms c
      join public.memberships m on m.school_id=c.school_id and m.role='teacher'
      where c.id::text like '94000000-0000-4000-8000-%';

      insert into public.students (
        id,school_id,user_id,studafy_id,display_name,provisional,created_by
      )
      select
        ('95000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        c.school_id,
        case when i=1 then '${studentUser}'::uuid else null end,
        'DB021-SCALE-' || i,
        'Policy Student ' || i,
        false,
        c.teacher_id
      from generate_series(1,1200) i
      join public.classrooms c on c.id=(
        '94000000-0000-4000-8000-' || lpad((1+((i-1)/10))::text,12,'0')
      )::uuid;

      insert into public.enrollments (classroom_id,student_id,active)
      select
        ('94000000-0000-4000-8000-' || lpad((1+((i-1)/10))::text,12,'0'))::uuid,
        ('95000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        true
      from generate_series(1,1200) i;

      insert into public.guardian_links (
        student_id,guardian_id,status,relationship,verified_by,verified_at
      ) values (
        '${firstStudent}','${guardian1}','verified','parent','${teacher1}',now()
      );

      insert into public.assessments (
        id,classroom_id,title,category,maximum_score,state,delivery,
        created_by,published_at
      )
      select
        ('96000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        ('94000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        'Policy Assessment ' || i,'quiz',100,'published','paper',
        case ((i-1)%3) when 0 then '${teacher1}'::uuid when 1 then '${teacher2}'::uuid else '${teacher3}'::uuid end,
        now()
      from generate_series(1,120) i;

      insert into public.grade_results (
        assessment_id,student_id,score,state,reviewed_by,reviewed_at,published_at
      )
      select
        ('96000000-0000-4000-8000-' || lpad((1+((i-1)/10))::text,12,'0'))::uuid,
        ('95000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
        i%101,'published',
        case (((1+((i-1)/10))-1)%3) when 0 then '${teacher1}'::uuid when 1 then '${teacher2}'::uuid else '${teacher3}'::uuid end,
        now(),now()
      from generate_series(1,1200) i;

      insert into public.notifications (
        school_id,user_id,kind,title,body,read_at,created_at
      )
      select '${school1}','${studentUser}','scale','Policy notification','Synthetic',
        case when i%3=0 then now() else null end,
        now()-i*interval '1 second'
      from generate_series(1,6000) i;

      analyze public.profiles;
      analyze public.memberships;
      analyze public.schools;
      analyze public.terms;
      analyze public.classrooms;
      analyze public.classroom_staff;
      analyze public.students;
      analyze public.guardian_links;
      analyze public.enrollments;
      analyze public.assessments;
      analyze public.grade_results;
      analyze public.notifications;
    `);

    const cases: PolicyCase[] = [
      {
        name: "student exact enrollment",
        actor: studentUser,
        relation: "enrollments",
        statement:
          "select classroom_id from public.enrollments where student_id=$1 and active limit 20",
        parameters: [firstStudent],
      },
      {
        name: "student classroom lookup",
        actor: studentUser,
        relation: "classrooms",
        statement: "select id,name from public.classrooms where id=$1 limit 1",
        parameters: [firstClassroom],
      },
      {
        name: "student published grades",
        actor: studentUser,
        relation: "grade_results",
        statement:
          "select id,score from public.grade_results where student_id=$1 and state='published' order by published_at desc,id desc limit 20",
        parameters: [firstStudent],
      },
      {
        name: "guardian linked student",
        actor: guardian1,
        relation: "students",
        statement:
          "select id,display_name from public.students where id=$1 limit 1",
        parameters: [firstStudent],
      },
      {
        name: "teacher assessment grades",
        actor: teacher1,
        relation: "grade_results",
        statement:
          "select id,score from public.grade_results where assessment_id=$1 order by id limit 20",
        parameters: [firstAssessment],
      },
      {
        name: "cross-tenant teacher denial",
        actor: teacher2,
        relation: "grade_results",
        statement:
          "select id from public.grade_results where assessment_id=$1 limit 20",
        parameters: [firstAssessment],
      },
      {
        name: "administrator classroom cursor",
        actor: admin1,
        relation: "classrooms",
        statement:
          "select id,name from public.classrooms where school_id=$1 and term_id=$2 and status='active' order by id limit 50",
        parameters: [school1, term1],
      },
      {
        name: "student unread notifications",
        actor: studentUser,
        relation: "notifications",
        statement:
          "select id,title from public.notifications where user_id=$1 and read_at is null order by created_at desc,id desc limit 20",
        parameters: [studentUser],
      },
    ];

    const measurements: Array<{
      name: string;
      median_ms: number;
      worst_ms: number;
    }> = [];

    await tx.unsafe("set local role authenticated");
    for (const query of cases) {
      await tx.unsafe("select set_config('request.jwt.claim.sub',$1,true)", [
        query.actor,
      ]);
      const durations: number[] = [];
      for (let run = 0; run < 3; run += 1) {
        const rows = await tx.unsafe(
          `explain (analyze, buffers, format json) ${query.statement}`,
          query.parameters,
        );
        const report = rows[0]?.["QUERY PLAN"]?.[0] as
          | ExplainReport
          | undefined;
        if (!report) throw new Error(`Missing EXPLAIN for ${query.name}.`);
        const scans = nodes(report.Plan).filter((node) =>
          node["Node Type"] === "Seq Scan" &&
          node["Relation Name"] === query.relation
        );
        if (scans.length > 0) {
          throw new Error(
            `${query.name} used a sequential scan on ${query.relation}.`,
          );
        }
        durations.push(report["Execution Time"]);
      }
      durations.sort((a, b) => a - b);
      const median = durations[1]!;
      const worst = durations[2]!;
      if (median >= 50 || worst >= 150) {
        throw new Error(
          `${query.name} exceeded the provisional latency bound (${median}/${worst} ms).`,
        );
      }
      measurements.push({
        name: query.name,
        median_ms: median,
        worst_ms: worst,
      });
    }

    console.log(JSON.stringify({
      event: "db021_policy_plan_check",
      target: "local_disposable",
      fixture: {
        schools: 3,
        students: 1200,
        classrooms: 120,
        enrollments: 1200,
        grades: 1200,
        notifications: 6000,
      },
      limits_ms: { median_below: 50, worst_below: 150 },
      measurements,
    }));

    throw new Error("DB021_ROLLBACK_POLICY_FIXTURE");
  }).catch((error) => {
    if (
      error instanceof Error &&
      error.message.includes("DB021_ROLLBACK_POLICY_FIXTURE")
    ) return;
    throw error;
  });
} finally {
  await sql.end({ timeout: 5 });
}
