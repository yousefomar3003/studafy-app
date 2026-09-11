import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error("Refusing to load a scale fixture outside a local database.");
}

type JsonPlan = {
  "Node Type": string;
  "Relation Name"?: string;
  Plans?: JsonPlan[];
};

type ExplainResult = {
  Plan: JsonPlan;
  "Execution Time": number;
};

type QueryCase = {
  name: string;
  relation: string;
  statement: string;
  parameters: unknown[];
};

function nodes(plan: JsonPlan): JsonPlan[] {
  return [plan, ...(plan.Plans ?? []).flatMap(nodes)];
}

const schoolId = "82000000-0000-4000-8000-000000000001";
const teacherId = "82000000-0000-4000-8000-000000000002";
const termId = "82000000-0000-4000-8000-000000000003";
const firstStudentId = "83000000-0000-4000-8000-000000000001";
const firstStudentUserId = "84000000-0000-4000-8000-000000000001";

const sql = postgres(databaseUrl, { max: 1 });

try {
  await sql.begin(async (tx) => {
    await tx.unsafe("set local statement_timeout = '60s'");

    await tx.unsafe(`
      insert into auth.users (
        id, email, encrypted_password, aud, role, email_confirmed_at,
        created_at, updated_at, instance_id, confirmation_token,
        recovery_token, email_change, email_change_token_new,
        email_change_token_current, phone_change_token,
        raw_app_meta_data, raw_user_meta_data
      ) values (
        '${teacherId}', 'db020.scale.teacher@synthetic.studafy.test',
        'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
        now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
        '', '', '', '{}'::jsonb, '{"full_name":"DB020 Scale Teacher"}'::jsonb
      );

      insert into auth.users (
        id, email, encrypted_password, aud, role, email_confirmed_at,
        created_at, updated_at, instance_id, confirmation_token,
        recovery_token, email_change, email_change_token_new,
        email_change_token_current, phone_change_token,
        raw_app_meta_data, raw_user_meta_data
      )
      select
        ('84000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        'db020.scale.student.' || i || '@synthetic.studafy.test',
        'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
        now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
        '', '', '', '{}'::jsonb,
        jsonb_build_object('full_name', 'DB020 Scale Student ' || i)
      from generate_series(1, 2000) i;

      insert into public.schools (id, name, status)
      values ('${schoolId}', 'DB020 Scale School', 'active');

      insert into public.memberships (school_id, user_id, role, active)
      values ('${schoolId}', '${teacherId}', 'teacher', true);

      insert into public.memberships (school_id, user_id, role, active)
      select '${schoolId}',
        ('84000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        'student', true
      from generate_series(1, 2000) i;

      insert into public.memberships (school_id, user_id, role, active)
      select '${schoolId}',
        ('84000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        'teacher', true
      from generate_series(1, 2000) i;

      insert into public.terms (id, school_id, name, starts_on, ends_on, active)
      values ('${termId}', '${schoolId}', 'DB020 Scale Term', '2026-09-01', '2027-06-30', true);

      insert into public.classrooms (id, school_id, term_id, name, teacher_id)
      select
        ('85000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        '${schoolId}', '${termId}', 'Scale Classroom ' || i, '${teacherId}'
      from generate_series(1, 2000) i;

      insert into public.students (
        id, school_id, user_id, studafy_id, display_name, provisional, created_by
      )
      select
        ('83000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        '${schoolId}',
        ('84000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        'DB020-SCALE-' || i, 'Scale Student ' || i, false, '${teacherId}'
      from generate_series(1, 2000) i;

      insert into public.guardian_links (
        school_id, student_id, guardian_id, status, relationship,
        verified_by, verified_at
      )
      select '${schoolId}',
        ('83000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        ('84000000-0000-4000-8000-' || lpad((1 + (i % 2000))::text, 12, '0'))::uuid,
        'verified', 'synthetic_guardian', '${teacherId}', now()
      from generate_series(1, 2000) i;

      insert into public.enrollments (school_id, classroom_id, student_id, active)
      select '${schoolId}',
        ('85000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        ('83000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        true
      from generate_series(1, 2000) i;

      insert into public.classroom_staff (
        school_id, classroom_id, membership_id, user_id, role, status, starts_at
      )
      select '${schoolId}', c.id, m.id, '${teacherId}', 'lead_teacher', 'active', now()
      from public.classrooms c
      join public.memberships m
        on m.school_id = c.school_id and m.user_id = '${teacherId}'
      where c.school_id = '${schoolId}';

      insert into public.classroom_staff (
        school_id, classroom_id, membership_id, user_id, role, status, starts_at
      )
      select '${schoolId}',
        ('85000000-0000-4000-8000-' || lpad(class_number::text, 12, '0'))::uuid,
        m.id, m.user_id, 'co_teacher', 'active', now()
      from public.memberships m
      cross join lateral (
        values
          (substring(m.user_id::text from 25)::bigint),
          (1 + (substring(m.user_id::text from 25)::bigint % 2000))
      ) assigned(class_number)
      where m.school_id = '${schoolId}'
        and m.role = 'teacher'
        and m.user_id <> '${teacherId}';

      insert into public.assessments (
        id, school_id, classroom_id, title, category, maximum_score,
        state, delivery, created_by, published_at
      )
      select
        ('86000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        '${schoolId}',
        ('85000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        'Scale Assessment ' || i, 'quiz', 100, 'published', 'paper',
        '${teacherId}', now()
      from generate_series(1, 2000) i;

      insert into public.grade_results (
        school_id, assessment_id, student_id, score, state, reviewed_by,
        reviewed_at, published_at, published_by
      )
      select '${schoolId}',
        ('86000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        ('83000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        (i % 101), 'published', '${teacherId}', now(), now(), '${teacherId}'
      from generate_series(1, 2000) i;

      insert into public.lesson_sessions (
        id, school_id, classroom_id, starts_at, ends_at, title
      )
      select
        ('87000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        '${schoolId}',
        ('85000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        '2026-09-11 06:00+00'::timestamptz + i * interval '1 minute',
        '2026-09-11 07:00+00'::timestamptz + i * interval '1 minute',
        'Scale Session ' || i
      from generate_series(1, 2000) i;

      insert into public.attendance_records (
        school_id, session_id, student_id, state, recorded_by, recorded_at
      )
      select '${schoolId}',
        ('87000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        ('83000000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
        case when i % 10 = 0 then 'late'::public.attendance_state else 'present'::public.attendance_state end,
        '${teacherId}', now() - i * interval '1 minute'
      from generate_series(1, 2000) i;

      insert into public.notifications (school_id, user_id, kind, title, body, read_at, created_at)
      select '${schoolId}',
        ('84000000-0000-4000-8000-' || lpad((1 + ((i - 1) % 2000))::text, 12, '0'))::uuid,
        'scale', 'Scale notification', 'Synthetic',
        case when i % 3 = 0 then now() else null end,
        now() - i * interval '1 second'
      from generate_series(1, 10000) i;

      insert into public.notification_outbox (
        school_id, source_event_id, idempotency_key, channel, template_key,
        recipient_id, state, next_attempt_at
      )
      select '${schoolId}', 'scale-event-' || i, 'scale-outbox-' || i,
        'push', 'scale', '${teacherId}',
        case when i <= 100 then 'pending'::public.outbox_state else 'completed'::public.outbox_state end,
        now() + i * interval '1 second'
      from generate_series(1, 5000) i;

      insert into public.file_objects (
        school_id, bucket, object_key, uploader_id, size_bytes,
        declared_media_type, detected_media_type, sha256, scan_state, scanned_at
      )
      select '${schoolId}', 'private-school-files', 'scale/' || i,
        '${teacherId}', i, 'application/pdf', 'application/pdf',
        md5('scale-file-' || i) || md5('scale-file-tail-' || i),
        'clean', now()
      from generate_series(1, 5000) i;

      insert into public.audit_events (school_id, actor_id, action, entity_type, entity_id, created_at)
      select '${schoolId}', '${teacherId}', 'scale.read', 'student',
        ('83000000-0000-4000-8000-' || lpad((1 + ((i - 1) % 2000))::text, 12, '0'))::uuid,
        now() - i * interval '1 second'
      from generate_series(1, 5000) i;

      analyze public.memberships;
      analyze public.guardian_links;
      analyze public.enrollments;
      analyze public.classroom_staff;
      analyze public.classrooms;
      analyze public.grade_results;
      analyze public.attendance_records;
      analyze public.notifications;
      analyze public.notification_outbox;
      analyze public.file_objects;
      analyze public.audit_events;
    `);

    const cases: QueryCase[] = [
      {
        name: "active memberships by user",
        relation: "memberships",
        statement:
          "select school_id, role from public.memberships where user_id = $1 and active limit 20",
        parameters: [firstStudentUserId],
      },
      {
        name: "active enrollment by student",
        relation: "enrollments",
        statement:
          "select classroom_id from public.enrollments where student_id = $1 and active limit 20",
        parameters: [firstStudentId],
      },
      {
        name: "verified links by guardian",
        relation: "guardian_links",
        statement:
          "select student_id from public.guardian_links where guardian_id = $1 and status = 'verified' limit 20",
        parameters: [firstStudentUserId],
      },
      {
        name: "active classroom staff by user",
        relation: "classroom_staff",
        statement:
          "select classroom_id from public.classroom_staff where user_id = $1 and status = 'active' limit 100",
        parameters: [firstStudentUserId],
      },
      {
        name: "active classrooms by school and term",
        relation: "classrooms",
        statement:
          "select id from public.classrooms where school_id = $1 and term_id = $2 and status = 'active' order by id limit 50",
        parameters: [schoolId, termId],
      },
      {
        name: "published grades by student cursor",
        relation: "grade_results",
        statement:
          "select id, score from public.grade_results where student_id = $1 and state = 'published' order by published_at desc, id desc limit 20",
        parameters: [firstStudentId],
      },
      {
        name: "attendance by student timeline",
        relation: "attendance_records",
        statement:
          "select id, state from public.attendance_records where student_id = $1 order by recorded_at desc, id desc limit 20",
        parameters: [firstStudentId],
      },
      {
        name: "unread notifications by user cursor",
        relation: "notifications",
        statement:
          "select id, title from public.notifications where user_id = $1 and read_at is null order by created_at desc, id desc limit 20",
        parameters: [firstStudentUserId],
      },
      {
        name: "ready notification outbox",
        relation: "notification_outbox",
        statement:
          "select id from public.notification_outbox where state in ('pending', 'retry') and next_attempt_at <= $1 order by next_attempt_at, id limit 50",
        parameters: ["2027-01-01T00:00:00Z"],
      },
      {
        name: "clean file deduplication",
        relation: "file_objects",
        statement:
          "select id from public.file_objects where school_id = $1 and sha256 = $2 and size_bytes = $3 and scan_state = 'clean' and deleted_at is null limit 1",
        parameters: [
          schoolId,
          "82dd495c8881481f8b010830101eef23530516df21cdcc62a0105ee78588f744",
          1,
        ],
      },
      {
        name: "tenant audit cursor",
        relation: "audit_events",
        statement:
          "select id, action from public.audit_events where school_id = $1 order by created_at desc, id desc limit 50",
        parameters: [schoolId],
      },
    ];

    const measurements: Array<
      { name: string; median_ms: number; worst_ms: number }
    > = [];

    for (const query of cases) {
      const durations: number[] = [];
      for (let run = 0; run < 3; run += 1) {
        const rows = await tx.unsafe(
          `explain (analyze, buffers, format json) ${query.statement}`,
          query.parameters,
        );
        const report = rows[0]?.["QUERY PLAN"]?.[0] as
          | ExplainResult
          | undefined;
        if (!report) {
          throw new Error(`Missing EXPLAIN output for ${query.name}.`);
        }

        const forbidden = nodes(report.Plan).filter((node) =>
          node["Node Type"] === "Seq Scan" &&
          node["Relation Name"] === query.relation
        );
        if (forbidden.length > 0) {
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
      event: "db020_query_plan_check",
      target: "local_disposable",
      fixture: {
        schools: 1,
        students: 2000,
        classrooms: 2000,
        classroom_staff: 6000,
        guardian_links: 2000,
        enrollments: 2000,
        grades: 2000,
        notifications: 10000,
        files: 5000,
        outbox: 5000,
        audit_events: 5000,
      },
      limits_ms: { median_below: 50, worst_below: 150 },
      measurements,
    }));

    throw new Error("DB020_ROLLBACK_SCALE_FIXTURE");
  }).catch((error) => {
    if (
      error instanceof Error &&
      error.message.includes("DB020_ROLLBACK_SCALE_FIXTURE")
    ) return;
    throw error;
  });
} finally {
  await sql.end({ timeout: 5 });
}
