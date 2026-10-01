import postgres from "postgres";

/**
 * Paper gradebook, attendance history and deadline plans at school scale.
 *
 * Seeds one school with 300 classes of 30 students and eight paper items per
 * class - seven marked for every student (63,000 marks), one left unmarked
 * to save - plus a register, inside one transaction that is rolled back. It
 * then checks that the queries the new handlers run use their indexes, and
 * times the handlers themselves - read a class sheet, save it, publish it,
 * correct a mark - against fixed bounds, so a change that makes them scan
 * the school fails here rather than under a school's morning traffic.
 */
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error("Refusing to load a scale fixture outside a local database.");
}

type Plan = {
  "Node Type": string;
  "Index Name"?: string;
  "Relation Name"?: string;
  Plans?: Plan[];
};
type Explain = { Plan: Plan; "Execution Time": number };

function nodes(plan: Plan): Plan[] {
  return [plan, ...(plan.Plans ?? []).flatMap(nodes)];
}

const school = "c0a00000-0000-4000-8000-000000000001";
const teacher = "c0a00000-0000-4000-8000-000000000002";
const term = "c0a00000-0000-4000-8000-000000000003";
const CLASSES = 300;
const STUDENTS = 30;
const ITEMS = 8;

const uuid = (prefix: string, n: string) =>
  `('${prefix}-0000-4000-8000-'||lpad((${n})::text,12,'0'))::uuid`;

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
      ) values ('${teacher}','coursework.plan@synthetic.studafy.test','synthetic',
        'authenticated','authenticated',now(),now(),now(),
        '00000000-0000-0000-0000-000000000000','','','','','','','{}',
        '{"full_name":"Plan Teacher"}');
      insert into public.schools(id,name,status) values ('${school}','Coursework Plan School','active');
      insert into public.memberships(school_id,user_id,role,active) values ('${school}','${teacher}','teacher',true);
      insert into public.terms(id,school_id,name,starts_on,ends_on,active)
        values ('${term}','${school}','Plan Term',current_date - 60,current_date + 200,true);

      insert into public.classrooms(id,school_id,term_id,name,teacher_id)
      select ${
      uuid("c0a10000", "c")
    },'${school}','${term}','Class '||c,'${teacher}'
      from generate_series(1,${CLASSES}) c;
      insert into public.classroom_staff(school_id,classroom_id,membership_id,user_id,role)
      select '${school}',${
      uuid("c0a10000", "c")
    },m.id,'${teacher}','lead_teacher'
      from generate_series(1,${CLASSES}) c
      cross join public.memberships m where m.user_id='${teacher}';
      insert into public.students(id,school_id,studafy_id,display_name,provisional,created_by)
      select ${
      uuid("c0a20000", "s")
    },'${school}','PLAN-'||s,'Student '||s,false,'${teacher}'
      from generate_series(1,${CLASSES * STUDENTS}) s;
      insert into public.enrollments(classroom_id,student_id,active,starts_on)
      select ${uuid("c0a10000", `(s-1)/${STUDENTS}+1`)},${
      uuid("c0a20000", "s")
    },true,current_date - 60
      from generate_series(1,${CLASSES * STUDENTS}) s;
      insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by,published_at)
      select ${uuid("c0a30000", "i")},'${school}',${
      uuid("c0a10000", `(i-1)/${ITEMS}+1`)
    },
        'Paper '||i,'paper_exam',20,'published','paper','${teacher}',now()
      from generate_series(1,${CLASSES * ITEMS}) i;
      insert into public.grade_results(school_id,assessment_id,student_id,score,mark,state,
        reviewed_by,reviewed_at,published_by,published_at)
      select '${school}',${uuid("c0a30000", "i")},
        ${uuid("c0a20000", `((i-1)/${ITEMS})*${STUDENTS}+s`)},
        10,'scored','published','${teacher}',now(),'${teacher}',now()
      from generate_series(1,${
      CLASSES * ITEMS
    }) i, generate_series(1,${STUDENTS}) s
      where i % ${ITEMS} <> 0;
      insert into public.lesson_sessions(id,school_id,classroom_id,starts_at,ends_at,status)
      select ${uuid("c0a40000", "c")},'${school}',${uuid("c0a10000", "c")},
        now() - interval '2 days',now() - interval '2 days' + interval '45 minutes','completed'
      from generate_series(1,${CLASSES}) c;
      insert into public.attendance_records(school_id,session_id,student_id,state,recorded_by)
      select '${school}',${uuid("c0a40000", `(s-1)/${STUDENTS}+1`)},${
      uuid("c0a20000", "s")
    },'present','${teacher}'
      from generate_series(1,${CLASSES * STUDENTS}) s;
      insert into public.assignments(id,school_id,classroom_id,title,due_at,state,created_by,published_at)
      select ${uuid("c0a50000", "c")},'${school}',${
      uuid("c0a10000", "c")
    },'Essay '||c,
        now() + interval '2 days','published','${teacher}',now()
      from generate_series(1,${CLASSES}) c;
      analyze public.enrollments; analyze public.grade_results; analyze public.assessments;
      analyze public.attendance_records; analyze public.grade_result_events;
      analyze public.attendance_record_revisions; analyze public.assignment_extensions;
    `);

    const classId = `c0a10000-0000-4000-8000-${String(150).padStart(12, "0")}`;
    const itemId = `c0a30000-0000-4000-8000-${
      String(149 * ITEMS + 8).padStart(12, "0")
    }`;
    const markedItem = `c0a30000-0000-4000-8000-${
      String(149 * ITEMS + 1).padStart(12, "0")
    }`;
    const sessionId = `c0a40000-0000-4000-8000-${
      String(150).padStart(12, "0")
    }`;
    const workId = `c0a50000-0000-4000-8000-${String(150).padStart(12, "0")}`;
    const firstStudent = `c0a20000-0000-4000-8000-${
      String(149 * STUDENTS + 1).padStart(12, "0")
    }`;

    // The row queries each handler is built on, with the index each must use.
    const plans = [
      [
        "class enrollments",
        "db020_enrollments_classroom_active",
        `select student_id from public.enrollments
         where classroom_id='${classId}' and active and status='active'`,
      ],
      [
        "an item's marks",
        "grade_results_assessment_id_student_id_key",
        `select * from public.grade_results
         where assessment_id='${markedItem}' and student_id='${firstStudent}'`,
      ],
      [
        "an item's counts",
        "db020_grade_results_assessment_state",
        `select state,count(*) from public.grade_results
         where assessment_id='${markedItem}' group by state`,
      ],
      [
        "a mark's history",
        "db020_grade_result_events_result_time",
        `select * from public.grade_result_events
         where grade_result_id=(select id from public.grade_results
           where assessment_id='${markedItem}' limit 1)
         order by created_at desc limit 50`,
      ],
      [
        "a lesson's changes",
        "attendance_record_revisions_session_idx",
        `select * from public.attendance_record_revisions
         where session_id='${sessionId}' order by id desc limit 50`,
      ],
      [
        "a student's extension",
        "assignment_extensions_live_key",
        `select * from public.assignment_extensions
         where assignment_id='${workId}' and student_id='${firstStudent}'
           and revoked_at is null`,
      ],
    ] as const;

    const measurements: Record<string, unknown>[] = [];
    for (const [name, index, query] of plans) {
      await tx.unsafe("set local enable_seqscan = off");
      const rows = await tx.unsafe(
        `explain (analyze, format json) ${query}`,
      );
      await tx.unsafe("set local enable_seqscan = on");
      const report = rows[0]?.["QUERY PLAN"]?.[0] as Explain | undefined;
      if (!report) throw new Error(`Missing EXPLAIN for ${name}.`);
      const used = nodes(report.Plan).map((node) => node["Index Name"])
        .filter(Boolean);
      if (!used.includes(index)) {
        throw new Error(
          `${name} did not use ${index}; used ${used.join(",")}.`,
        );
      }
      if (report["Execution Time"] >= 50) {
        throw new Error(`${name} exceeded the 50ms bound.`);
      }
      measurements.push({
        name,
        index,
        execution_ms: report["Execution Time"],
      });
    }

    // The handlers, end to end, as the class teacher.
    await tx.unsafe(`
      select set_config('request.jwt.claim.sub','${teacher}',true),
        set_config('studafy.school_id','${school}',true),
        set_config('studafy.request_id','coursework-plan',true)`);
    const timed = async (name: string, bound: number, query: string) => {
      const started = performance.now();
      const rows = await tx.unsafe(query);
      const elapsed = performance.now() - started;
      const result = rows[0]?.["result"] as Record<string, unknown> | undefined;
      if (
        result && typeof result["outcome"] === "string" &&
        result["outcome"] !== "ok"
      ) {
        throw new Error(`${name} answered ${result["outcome"]}.`);
      }
      if (elapsed >= bound) {
        throw new Error(
          `${name} took ${elapsed.toFixed(1)}ms (bound ${bound}ms).`,
        );
      }
      measurements.push({ name, elapsed_ms: Number(elapsed.toFixed(2)) });
    };
    const command = (op: string, resource: string, body: string) => `
      with r as (select private.api_idempotency_reserve('${school}'::uuid,'${op}',
        gen_random_uuid()::text,md5(random()::text)||md5(random()::text),3600,60) as v)
      select private.api041_command('${op}','${resource}'::uuid,
        jsonb_build_object('responseStatus',200,'body',${body}),
        (r.v->>'id')::uuid,(r.v->>'generation')::bigint) as result from r`;

    await timed(
      "read a class grade sheet",
      50,
      `select private.api041_query('listGradebook','${itemId}','{"pageSize":100}') as result`,
    );
    await timed(
      "save a whole class as drafts",
      150,
      command(
        "saveGradeDrafts",
        itemId,
        `jsonb_build_object('entries',(select jsonb_agg(jsonb_build_object(
          'studentId',e.student_id,'expectedVersion',0,'mark','scored','score',12))
          from public.enrollments e where e.classroom_id='${classId}'))`,
      ),
    );
    await timed(
      "publish a whole class",
      150,
      command(
        "publishGrades",
        itemId,
        `jsonb_build_object('expectedGradebookVersion',
          (select gradebook_version from public.assessments where id='${itemId}'))`,
      ),
    );
    await timed(
      "correct one mark",
      100,
      command(
        "correctGrades",
        markedItem,
        `jsonb_build_object('reason','Plan check','entries',jsonb_build_array(
          (select jsonb_build_object('gradeResultId',g.id,'expectedVersion',g.version,
            'mark','scored','score',11) from public.grade_results g
            where g.assessment_id='${markedItem}' limit 1)))`,
      ),
    );
    await timed(
      "read a lesson's register history",
      50,
      `select private.api041_query('listAttendanceHistory','${sessionId}','{}') as result`,
    );
    await timed(
      "read an assignment with its deadline",
      50,
      `select private.api041_query('getAssignment','${workId}','{}') as result`,
    );

    console.log(JSON.stringify({
      event: "coursework_query_plan_check",
      target: "local_disposable",
      classes: CLASSES,
      students: CLASSES * STUDENTS,
      marks: CLASSES * (ITEMS - 1) * STUDENTS,
      measurements,
    }));
    throw new Error("COURSEWORK_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) ||
      error.message !== "COURSEWORK_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
