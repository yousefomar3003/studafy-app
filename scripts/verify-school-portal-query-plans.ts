import postgres from "postgres";

/**
 * The School Portal at school scale (docs/operations/capacity.md).
 *
 * Seeds one teacher's workspace with 200 classes of 25 students - ten
 * registers, four marked items and eight pieces of work each, half handed
 * in - linked with one school's page, plus 200 other schools' pages with
 * ten announcements each, inside one transaction that is rolled back. It
 * then checks that the portal's reads by class use their indexes, and times
 * the reads an administrator, a student and a teacher make against fixed
 * bounds, so a change that makes them scan every class, or every school's
 * announcements, fails here rather than in a school's morning.
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

const school = "c0b00000-0000-4000-8000-000000000001";
const teacher = "c0b00000-0000-4000-8000-000000000002";
const term = "c0b00000-0000-4000-8000-000000000003";
const admin = "c0b00000-0000-4000-8000-000000000004";
const pupil = "c0b00000-0000-4000-8000-000000000005";
const org = "c0b00000-0000-4000-8000-000000000006";
const CLASSES = 200;
const STUDENTS = 25;
const SESSIONS = 10;
const ITEMS = 4;
const WORK = 8;
const OTHER_ORGS = 200;

const uuid = (prefix: string, n: string) =>
  `('${prefix}-0000-4000-8000-'||lpad((${n})::text,12,'0'))::uuid`;
const id = (prefix: string, n: number) =>
  `${prefix}-0000-4000-8000-${String(n).padStart(12, "0")}`;

const sql = postgres(databaseUrl, { max: 1 });
try {
  await sql.begin(async (tx) => {
    await tx.unsafe("set local statement_timeout = '180s'");
    await tx.unsafe(`
      insert into auth.users (
        id,email,encrypted_password,aud,role,email_confirmed_at,created_at,
        updated_at,instance_id,confirmation_token,recovery_token,email_change,
        email_change_token_new,email_change_token_current,phone_change_token,
        raw_app_meta_data,raw_user_meta_data
      ) select v.id::uuid, v.email,'synthetic','authenticated','authenticated',now(),now(),now(),
        '00000000-0000-0000-0000-000000000000','','','','','','','{}',
        jsonb_build_object('full_name',v.name)
      from (values ('${teacher}','portal.plan.teacher@synthetic.studafy.test','Plan Teacher'),
        ('${admin}','portal.plan.admin@synthetic.studafy.test','Plan Principal'),
        ('${pupil}','portal.plan.pupil@synthetic.studafy.test','Plan Pupil')) v(id,email,name);
      update public.profiles set account_kind = 'adult' where id = '${admin}';
      insert into public.schools(id,name,status) values ('${school}','Portal Plan School','active');
      insert into public.memberships(school_id,user_id,role,active) values ('${school}','${teacher}','teacher',true);
      insert into public.terms(id,school_id,name,starts_on,ends_on,active)
        values ('${term}','${school}','Plan Term',current_date - 60,current_date + 200,true);

      insert into public.classrooms(id,school_id,term_id,name,teacher_id)
      select ${
      uuid("c0b10000", "c")
    },'${school}','${term}','Class '||c,'${teacher}'
      from generate_series(1,${CLASSES}) c;
      insert into public.classroom_staff(school_id,classroom_id,membership_id,user_id,role)
      select '${school}',${
      uuid("c0b10000", "c")
    },m.id,'${teacher}','lead_teacher'
      from generate_series(1,${CLASSES}) c
      cross join public.memberships m where m.user_id='${teacher}';
      insert into public.students(id,school_id,user_id,studafy_id,display_name,provisional,created_by)
      select ${uuid("c0b20000", "s")},'${school}',
        case when s = 1 then '${pupil}'::uuid end,'PORTAL-'||s,'Student '||s,false,'${teacher}'
      from generate_series(1,${CLASSES * STUDENTS}) s;
      insert into public.enrollments(classroom_id,student_id,active,starts_on)
      select ${uuid("c0b10000", `(s-1)/${STUDENTS}+1`)},${
      uuid("c0b20000", "s")
    },
        true,current_date - 60
      from generate_series(1,${CLASSES * STUDENTS}) s;

      insert into public.lesson_sessions(id,school_id,classroom_id,starts_at,ends_at,status)
      select ${uuid("c0b30000", "i")},'${school}',
        ${uuid("c0b10000", `(i-1)/${SESSIONS}+1`)},
        now() - (((i-1) % ${SESSIONS}) * 2 + 1 || ' days')::interval,
        now() - (((i-1) % ${SESSIONS}) * 2 + 1 || ' days')::interval + interval '45 minutes',
        'completed'
      from generate_series(1,${CLASSES * SESSIONS}) i;
      insert into public.attendance_records(school_id,session_id,student_id,state,recorded_by)
      select '${school}',${uuid("c0b30000", "i")},
        ${uuid("c0b20000", `((i-1)/${SESSIONS})*${STUDENTS}+s`)},
        case when s % 9 = 0 then 'absent' else 'present' end::public.attendance_state,
        '${teacher}'
      from generate_series(1,${
      CLASSES * SESSIONS
    }) i, generate_series(1,${STUDENTS}) s;

      insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by,published_at)
      select ${uuid("c0b40000", "i")},'${school}',${
      uuid("c0b10000", `(i-1)/${ITEMS}+1`)
    },
        'Paper '||i,'paper_exam',20,'published','paper','${teacher}',now()
      from generate_series(1,${CLASSES * ITEMS}) i;
      insert into public.grade_results(school_id,assessment_id,student_id,score,mark,state,
        reviewed_by,reviewed_at,published_by,published_at)
      select '${school}',${uuid("c0b40000", "i")},
        ${uuid("c0b20000", `((i-1)/${ITEMS})*${STUDENTS}+s`)},
        8 + s % 12,'scored','published','${teacher}',now(),'${teacher}',now()
      from generate_series(1,${
      CLASSES * ITEMS
    }) i, generate_series(1,${STUDENTS}) s;

      insert into public.assignments(id,school_id,classroom_id,title,due_at,state,created_by,published_at)
      select ${uuid("c0b50000", "i")},'${school}',${
      uuid("c0b10000", `(i-1)/${WORK}+1`)
    },
        'Essay '||i,now() + ((((i-1) % ${WORK}) - 4) || ' days')::interval,
        'published','${teacher}',now() - interval '10 days'
      from generate_series(1,${CLASSES * WORK}) i;
      insert into public.submissions(school_id,assignment_id,student_id,status,submitted_at)
      select '${school}',${uuid("c0b50000", "i")},
        ${
      uuid("c0b20000", `((i-1)/${WORK})*${STUDENTS}+s`)
    },'submitted',now() - interval '1 day'
      from generate_series(1,${
      CLASSES * WORK
    }) i, generate_series(1,${STUDENTS}) s
      where s % 2 = 0;

      insert into private.school_portal_orgs(id,name,country,city,kind,created_by)
      values ('${org}','Portal Plan School','Jordan','Amman','private','${admin}');
      insert into private.school_portal_admins(org_id,user_id,job_title,agreement_version)
      values ('${org}','${admin}','Principal',private.school_portal_agreement_version());
      insert into private.school_portal_teacher_links(org_id,teacher_id,requested_by,status,decided_at)
      values ('${org}','${teacher}','${admin}','linked',now());
      insert into private.school_portal_announcements(org_id,author_id,title,body,audience,recipient_count)
      values ('${org}','${admin}','Sports day','Friday from 9.','students',${
      CLASSES * STUDENTS
    });
      -- Other schools' announcements, which no one here should pay to read.
      insert into private.school_portal_orgs(id,name,country,city,kind)
      select ${
      uuid("c0b60000", "o")
    },'Other School '||o,'Jordan','Amman','public'
      from generate_series(1,${OTHER_ORGS}) o;
      insert into private.school_portal_announcements(org_id,title,body,audience,created_at)
      select ${
      uuid("c0b60000", "o")
    },'Notice '||k,'Closed on Thursday.','students_and_parents',
        now() - (k || ' days')::interval
      from generate_series(1,${OTHER_ORGS}) o, generate_series(1,10) k;
      insert into private.school_portal_groups(id,org_id,name,code_hash,derivation_salt,created_by)
      values (${uuid("c0b70000", "1")},'${org}','Grade 7',
        encode(extensions.digest('portal-plan-group','sha256'),'hex'),
        'portalplansaltportalplan','${admin}');
      insert into private.school_portal_group_classes(group_id,classroom_id,status,requested_by,decided_at)
      select ${uuid("c0b70000", "1")},${
      uuid("c0b10000", "c")
    },'approved','${admin}',now()
      from generate_series(1,30) c;
      analyze public.enrollments; analyze public.grade_results; analyze public.assessments;
      analyze public.attendance_records; analyze public.lesson_sessions;
      analyze public.assignments; analyze public.submissions; analyze public.classroom_staff;
      analyze public.announcements; analyze public.wellbeing_events;
      analyze private.school_portal_teacher_links; analyze private.school_portal_announcements;
    `);

    const classId = id("c0b10000", 150);

    // The row queries the portal reads a class by, with the index each must use.
    const plans = [
      [
        "a class's work, drafts included",
        "school_portal_assignments_classroom_idx",
        `select max(published_at) from public.assignments
         where classroom_id='${classId}' and deleted_at is null`,
      ],
      [
        "a class's announcements",
        "school_portal_announcements_classroom_idx",
        `select max(published_at) from public.announcements
         where classroom_id='${classId}' and deleted_at is null
           and state::text = 'published'`,
      ],
      [
        "a class's wellbeing notes",
        "school_portal_wellbeing_classroom_idx",
        `select * from public.wellbeing_events
         where classroom_id='${classId}' order by created_at desc`,
      ],
      [
        // The lookup inside school_portal_class_visible, run once per row
        // of the classes list, the groups page and the announcements read.
        "whether a school sees a class",
        "school_portal_teacher_links_one_school_idx",
        `select 1 from public.classroom_staff cs
         join private.school_portal_teacher_links l
           on l.teacher_id = cs.user_id and l.org_id = '${org}' and l.status = 'linked'
         where cs.classroom_id = '${classId}' and cs.status = 'active'
           and cs.role in ('lead_teacher', 'co_teacher')`,
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

    // The reads themselves, as the API makes them, each with its bound.
    const timed = async (
      name: string,
      bound: number,
      actor: string,
      operation: string,
      resource: string | null,
      input: Record<string, unknown> = {},
    ) => {
      await tx.unsafe(`
        select set_config('request.jwt.claim.sub','${actor}',true),
          set_config('studafy.request_id','portal-plan',true)`);
      const started = performance.now();
      const rows = await tx.unsafe(
        `select private.api062_query($1,$2::uuid,$3::jsonb) as result`,
        [operation, resource, tx.json(input as never)],
      );
      const elapsed = performance.now() - started;
      const result = rows[0]?.["result"] as Record<string, unknown> | undefined;
      if (result?.["outcome"] !== "ok") {
        throw new Error(`${name} answered ${String(result?.["outcome"])}.`);
      }
      if (elapsed >= bound) {
        throw new Error(
          `${name} took ${elapsed.toFixed(1)}ms (bound ${bound}ms).`,
        );
      }
      measurements.push({ name, elapsed_ms: Number(elapsed.toFixed(2)) });
      return result;
    };
    const inOrg = { orgId: org };

    // Bounds are about three times what a laptop measures at this size.
    await timed("dashboard", 150, admin, "dashboard", org);
    await timed("overview", 1000, admin, "overview", org);
    const classes = await timed("classes", 800, admin, "classes", org);
    if ((classes["classes"] as unknown[]).length !== CLASSES) {
      throw new Error("The classes list did not list every class.");
    }
    await timed("reports", 1000, admin, "reports", org);
    await timed("groups", 200, admin, "groups", org);
    await timed("announcements", 50, admin, "announcements", org);
    await timed("teachers", 100, admin, "teachers", org);
    await timed("class overview", 60, admin, "classOverview", classId, inOrg);
    await timed("class roster", 60, admin, "roster", classId, inOrg);
    await timed("class marks", 60, admin, "marks", classId, inOrg);
    await timed("class attendance", 60, admin, "attendance", classId, inOrg);
    await timed(
      "a student's page",
      150,
      admin,
      "student",
      id("c0b20000", 1),
      inOrg,
    );
    await timed("a teacher's page", 300, admin, "teacher", teacher, inOrg);
    const mine = await timed(
      "a student's announcements",
      60,
      pupil,
      "myAnnouncements",
      null,
    );
    if ((mine["announcements"] as unknown[]).length !== 1) {
      throw new Error("The student did not get exactly their school's one.");
    }
    await timed(
      "a teacher's announcements",
      60,
      teacher,
      "myAnnouncements",
      null,
    );
    await timed(
      "a teacher's group requests",
      100,
      teacher,
      "myGroupClasses",
      null,
    );

    console.log(JSON.stringify({
      event: "school_portal_query_plan_check",
      target: "local_disposable",
      classes: CLASSES,
      students: CLASSES * STUDENTS,
      attendance: CLASSES * SESSIONS * STUDENTS,
      other_announcements: OTHER_ORGS * 10,
      measurements,
    }));
    throw new Error("SCHOOL_PORTAL_ROLLBACK_FIXTURE");
  }).catch((error) => {
    if (
      !(error instanceof Error) ||
      error.message !== "SCHOOL_PORTAL_ROLLBACK_FIXTURE"
    ) {
      throw error;
    }
  });
} finally {
  await sql.end({ timeout: 5 });
}
