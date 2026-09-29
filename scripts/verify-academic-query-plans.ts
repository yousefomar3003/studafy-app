import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to load an API-041 scale fixture outside a local database.",
  );
}

type Plan = {
  "Node Type": string;
  "Relation Name"?: string;
  "Index Name"?: string;
  Plans?: Plan[];
};
type Explain = { Plan: Plan; "Execution Time": number };

function nodes(plan: Plan): Plan[] {
  return [plan, ...(plan.Plans ?? []).flatMap(nodes)];
}

const school = "a4100000-0000-4000-8000-000000000001";
const actor = "a4100000-0000-4000-8000-000000000002";
const student = "a4100000-0000-4000-8000-000000000003";
const studentUser = "a4100000-0000-4000-8000-000000000004";
const term = "a4100000-0000-4000-8000-000000000005";
const classroom = "a4100000-0000-4000-8000-000000000006";
const otherSchool = "a4200000-0000-4000-8000-000000000001";
const otherActor = "a4200000-0000-4000-8000-000000000002";
const otherStudent = "a4200000-0000-4000-8000-000000000003";
const otherStudentUser = "a4200000-0000-4000-8000-000000000004";
const otherTerm = "a4200000-0000-4000-8000-000000000005";
const otherClassroom = "a4200000-0000-4000-8000-000000000006";

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
        ('${actor}','api041.plan.teacher@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"Plan Teacher"}'),
        ('${studentUser}','api041.plan.student@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"Plan Student"}'),
        ('${otherActor}','api041.plan.other.teacher@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"Other Teacher"}'),
        ('${otherStudentUser}','api041.plan.other.student@synthetic.studafy.test','synthetic','authenticated','authenticated',now(),now(),now(),'00000000-0000-0000-0000-000000000000','','','','','','','{}','{"full_name":"Other Student"}');
      insert into public.schools(id,name,status) values
        ('${school}','API-041 Plan School','active'),('${otherSchool}','API-041 Other School','active');
      insert into public.memberships(school_id,user_id,role,active) values
        ('${school}','${actor}','teacher',true),('${school}','${studentUser}','student',true),
        ('${otherSchool}','${otherActor}','teacher',true),('${otherSchool}','${otherStudentUser}','student',true);
      insert into public.terms(id,school_id,name,starts_on,ends_on,active)
        values('${term}','${school}','Plan Term','2026-09-01','2027-06-30',true),
          ('${otherTerm}','${otherSchool}','Other Term','2026-09-01','2027-06-30',true);
      insert into public.classrooms(id,school_id,term_id,name,teacher_id)
        values('${classroom}','${school}','${term}','Plan Base Class','${actor}'),
          ('${otherClassroom}','${otherSchool}','${otherTerm}','Other Base Class','${otherActor}');
      insert into public.students(id,school_id,user_id,studafy_id,display_name,provisional,created_by)
        values('${student}','${school}','${studentUser}','API041-PLAN','Plan Student',false,'${actor}'),
          ('${otherStudent}','${otherSchool}','${otherStudentUser}','API041-OTHER','Other Student',false,'${otherActor}');

      insert into public.classrooms(id,school_id,term_id,name,teacher_id)
      select ('a4110000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','${term}','Plan Class '||i,'${actor}' from generate_series(1,2000) i;
      insert into public.classrooms(id,school_id,term_id,name,teacher_id)
      select ('a4110000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','${otherTerm}','Other Class '||i,'${otherActor}' from generate_series(1,2000) i;
      insert into public.resources(id,school_id,title,resource_type,state,created_by)
      select ('a4120000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','Plan Resource '||i,'lesson_note','draft','${actor}' from generate_series(1,2000) i;
      insert into public.resources(id,school_id,title,resource_type,state,created_by)
      select ('a4120000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','Other Resource '||i,'lesson_note','draft','${otherActor}' from generate_series(1,2000) i;
      insert into public.assignments(id,school_id,classroom_id,title,due_at,state,created_by)
      select ('a4130000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','${classroom}','Plan Assignment '||i,now()+interval '7 days','draft','${actor}' from generate_series(1,2000) i;
      insert into public.assignments(id,school_id,classroom_id,title,due_at,state,created_by)
      select ('a4130000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','${otherClassroom}','Other Assignment '||i,now()+interval '7 days','draft','${otherActor}' from generate_series(1,2000) i;
      insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by)
      select ('a4140000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','${classroom}','Plan Assessment '||i,'quiz',10,'draft','paper','${actor}' from generate_series(1,2000) i;
      insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by)
      select ('a4140000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','${otherClassroom}','Other Assessment '||i,'quiz',10,'draft','paper','${otherActor}' from generate_series(1,2000) i;
      insert into public.grade_results(id,school_id,assessment_id,student_id,score,state)
      select ('a4150000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}',('a4140000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${student}',null,'draft' from generate_series(1,2000) i;
      insert into public.grade_results(id,school_id,assessment_id,student_id,score,state)
      select ('a4150000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}',('a4140000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherStudent}',null,'draft' from generate_series(1,2000) i;
      insert into public.lesson_sessions(id,school_id,classroom_id,starts_at,ends_at,status)
      select ('a4160000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','${classroom}',now()+i*interval '2 hours',now()+i*interval '2 hours'+interval '1 hour','completed'
        from generate_series(1,2000) i;
      insert into public.lesson_sessions(id,school_id,classroom_id,starts_at,ends_at,status)
      select ('a4160000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','${otherClassroom}',now()+i*interval '2 hours',now()+i*interval '2 hours'+interval '1 hour','completed'
        from generate_series(1,2000) i;
      insert into public.attendance_records(id,school_id,session_id,student_id,state,recorded_by)
      select ('a4170000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}',('a4160000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${student}','present','${actor}' from generate_series(1,2000) i;
      insert into public.attendance_records(id,school_id,session_id,student_id,state,recorded_by)
      select ('a4170000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}',('a4160000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherStudent}','present','${otherActor}' from generate_series(1,2000) i;
      insert into public.wellbeing_events(id,school_id,student_id,classroom_id,kind,title,created_by,visibility,severity,status)
      select ('a4180000-0000-4000-8000-'||lpad((i*2)::text,12,'0'))::uuid,
        '${school}','${student}','${classroom}','note','Plan Wellbeing '||i,'${actor}','class_staff','low','open'
        from generate_series(1,2000) i;
      insert into public.wellbeing_events(id,school_id,student_id,classroom_id,kind,title,created_by,visibility,severity,status)
      select ('a4180000-0000-4000-8000-'||lpad((i*2-1)::text,12,'0'))::uuid,
        '${otherSchool}','${otherStudent}','${otherClassroom}','note','Other Wellbeing '||i,'${otherActor}','class_staff','low','open'
        from generate_series(1,2000) i;
      analyze public.classrooms; analyze public.resources; analyze public.assignments;
      analyze public.assessments; analyze public.grade_results;
      analyze public.attendance_records; analyze public.wellbeing_events;
    `);

    const cases = [
      [
        "classrooms",
        "db020_classrooms_school_id_key",
        "archived_at is null",
        "a4110000-0000-4000-8000-000000002000",
      ],
      [
        "resources",
        "db020_resources_school_id_key",
        "deleted_at is null",
        "a4120000-0000-4000-8000-000000002000",
      ],
      [
        "assignments",
        "db020_assignments_school_id_key",
        "deleted_at is null",
        "a4130000-0000-4000-8000-000000002000",
      ],
      [
        "assessments",
        "db020_assessments_school_id_key",
        "deleted_at is null",
        "a4140000-0000-4000-8000-000000002000",
      ],
      [
        "grade_results",
        "db020_grade_results_school_id_key",
        "true",
        "a4150000-0000-4000-8000-000000002000",
      ],
      [
        "attendance_records",
        "db020_attendance_records_school_id_key",
        "true",
        "a4170000-0000-4000-8000-000000002000",
      ],
      [
        "wellbeing_events",
        "db020_wellbeing_events_school_id_key",
        "true",
        "a4180000-0000-4000-8000-000000002000",
      ],
    ] as const;
    const measurements: Record<string, unknown>[] = [];
    for (const [relation, expectedIndex, predicate, cursor] of cases) {
      const rows = await tx.unsafe(
        `explain (analyze, buffers, format json)
         select school_id,id from public.${relation}
         where school_id=$1 and id>$2 and ${predicate}
         order by id limit 50`,
        [school, cursor],
      );
      const report = rows[0]?.["QUERY PLAN"]?.[0] as Explain | undefined;
      if (!report) throw new Error(`Missing EXPLAIN for ${relation}.`);
      const planNodes = nodes(report.Plan);
      if (!planNodes.some((node) => node["Index Name"] === expectedIndex)) {
        throw new Error(
          `${relation} did not use ${expectedIndex}; used ${
            planNodes.map((node) => node["Index Name"]).filter(Boolean).join(
              ",",
            )
          }.`,
        );
      }
      if (report["Execution Time"] >= 50) {
        throw new Error(`${relation} exceeded the provisional 50ms bound.`);
      }
      measurements.push({
        relation,
        index: expectedIndex,
        execution_ms: report["Execution Time"],
        nodes: planNodes.map((node) => node["Node Type"]),
      });
    }
    console.log(JSON.stringify({
      event: "api041_query_plan_check",
      target: "local_disposable",
      rows_per_slice: 2000,
      measurements,
    }));
    throw new Error("API041_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) || error.message !== "API041_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
