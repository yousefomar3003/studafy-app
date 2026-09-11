begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

select ok(
  enum_range(null::public.app_role)::text[] @> array['school_admin', 'guardian'],
  'DB-020 adds school_admin and guardian roles without removing legacy roles'
);

select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and column_name = 'school_id'
      and table_name = any(array[
        'students', 'guardian_links', 'enrollments', 'lesson_sessions',
        'lesson_materials', 'assignments', 'submissions', 'assessments',
        'assessment_questions', 'grade_results', 'attendance_records',
        'wellbeing_events', 'meetings', 'meeting_deliveries',
        'ai_grading_drafts', 'question_suggestions', 'practice_sessions'
      ])
      and is_nullable <> 'NO'
  ),
  0::bigint,
  'every migrated school-owned aggregate has a non-null tenant column'
);

select is(
  (
    select count(*)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = any(array[
        'membership_events', 'classroom_staff', 'class_schedules',
        'file_objects', 'resources', 'resource_versions',
        'resource_publications', 'submission_attempts',
        'grade_result_events', 'conversations', 'conversation_participants',
        'messages', 'file_bindings', 'upload_sessions',
        'notification_outbox', 'notification_deliveries', 'store_products',
        'store_transactions', 'store_events', 'entitlements',
        'consent_policies', 'idempotency_records'
      ])
      and c.relrowsecurity
  ),
  22::bigint,
  'all new public lifecycle tables enable RLS'
);

select is(
  (
    select count(*)
    from pg_policies
    where schemaname = 'public'
      and tablename = any(array[
        'membership_events', 'classroom_staff', 'class_schedules',
        'file_objects', 'resources', 'resource_versions',
        'resource_publications', 'submission_attempts',
        'grade_result_events', 'conversations', 'conversation_participants',
        'messages', 'file_bindings', 'upload_sessions',
        'notification_outbox', 'notification_deliveries', 'store_products',
        'store_transactions', 'store_events', 'entitlements',
        'consent_policies', 'idempotency_records'
      ])
  ),
  0::bigint,
  'Part 2A adds no premature client policies to new tables'
);

select is(
  (
    select count(*)
    from information_schema.role_table_grants
    where table_schema = 'public'
      and grantee in ('anon', 'authenticated')
      and table_name = any(array[
        'membership_events', 'classroom_staff', 'class_schedules',
        'file_objects', 'resources', 'resource_versions',
        'resource_publications', 'submission_attempts',
        'grade_result_events', 'conversations', 'conversation_participants',
        'messages', 'file_bindings', 'upload_sessions',
        'notification_outbox', 'notification_deliveries', 'store_products',
        'store_transactions', 'store_events', 'entitlements',
        'consent_policies', 'idempotency_records'
      ])
  ),
  0::bigint,
  'new lifecycle tables grant no privileges to client roles'
);

select is(
  (
    select count(*)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'set_updated_at', 'sync_membership_lifecycle',
        'sync_term_lifecycle', 'sync_enrollment_lifecycle',
        'sync_classroom_lifecycle', 'sync_submission_lifecycle',
        'sync_grade_publication_actor', 'derive_school_id',
        'validate_grade_result_score', 'validate_assessment_maximum',
        'reject_append_only_mutation'
      ])
      and (
        has_function_privilege('anon', p.oid, 'execute')
        or has_function_privilege('authenticated', p.oid, 'execute')
      )
  ),
  0::bigint,
  'DB-020 trigger helpers are not directly executable by client roles'
);

insert into public.terms (
  id, school_id, name, starts_on, ends_on, active
) values (
  'abce0000-0000-4000-8000-000000000106',
  '22222222-2222-2222-2222-222222222222',
  'Seed Other Term', '2026-09-01', '2026-12-31', true
);

insert into public.classrooms (
  id, school_id, term_id, name, teacher_id
) values (
  'abcd0000-0000-4000-8000-000000000107',
  '22222222-2222-2222-2222-222222222222',
  'abce0000-0000-4000-8000-000000000106',
  'Seed Other Classroom',
  'eeee0000-0000-4000-8000-000000000005'
);

insert into public.students (
  id, school_id, studafy_id, display_name, provisional, created_by
) values (
  'abcf0000-0000-4000-8000-000000000108',
  '22222222-2222-2222-2222-222222222222',
  'STU-SEED-OTHER', 'Seed Other Student', false,
  'eeee0000-0000-4000-8000-000000000005'
);

insert into public.assignments (
  id, classroom_id, title, due_at, state, created_by, published_at
) values (
  'abd40000-0000-4000-8000-000000000109',
  'abcd0000-0000-4000-8000-000000000007',
  'Compatibility Assignment', now() + interval '1 day', 'published',
  'aaaa0000-0000-4000-8000-000000000001', now()
);

select is(
  (
    select school_id from public.assignments
    where id = 'abd40000-0000-4000-8000-000000000109'
  ),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'legacy assignment inserts derive school_id from the classroom'
);

select is(
  (
    select status::text from public.terms
    where id = 'abce0000-0000-4000-8000-000000000006'
  ),
  'active',
  'legacy active term writes synchronize the canonical lifecycle state'
);

select throws_like(
  $$insert into public.classrooms (
      school_id, term_id, name, teacher_id
    ) values (
      '22222222-2222-2222-2222-222222222222',
      'abce0000-0000-4000-8000-000000000006',
      'Cross-school Class', 'eeee0000-0000-4000-8000-000000000005'
    )$$,
  '%foreign key constraint%',
  'a classroom cannot reference another school term'
);

select throws_like(
  $$insert into public.guardian_links (
      school_id, student_id, guardian_id, status
    ) values (
      '22222222-2222-2222-2222-222222222222',
      'abcf0000-0000-4000-8000-000000000008',
      'dddd0000-0000-4000-8000-000000000004', 'pending'
    )$$,
  '%Cross-school or unresolved relationship%',
  'a guardian link cannot substitute another tenant'
);

select throws_like(
  $$insert into public.enrollments (classroom_id, student_id) values (
      'abcd0000-0000-4000-8000-000000000007',
      'abcf0000-0000-4000-8000-000000000108'
    )$$,
  '%Cross-school or unresolved relationship%',
  'an enrollment cannot connect a foreign-school student'
);

select throws_like(
  $$insert into public.submissions (assignment_id, student_id) values (
      'abd40000-0000-4000-8000-000000000109',
      'abcf0000-0000-4000-8000-000000000108'
    )$$,
  '%Cross-school or unresolved relationship%',
  'a submission cannot connect a foreign-school student'
);

select throws_like(
  $$insert into public.grade_results (
      assessment_id, student_id, score
    ) values (
      'abd00000-0000-4000-8000-000000000009',
      'abcf0000-0000-4000-8000-000000000108', 5
    )$$,
  '%Cross-school or unresolved relationship%',
  'a grade cannot connect a foreign-school student'
);

select throws_like(
  $$insert into public.attendance_records (
      session_id, student_id, state, recorded_by
    ) values (
      'abd20000-0000-4000-8000-00000000000b',
      'abcf0000-0000-4000-8000-000000000108', 'present',
      'aaaa0000-0000-4000-8000-000000000001'
    )$$,
  '%Cross-school or unresolved relationship%',
  'attendance cannot connect a foreign-school student'
);

select throws_like(
  $$insert into public.wellbeing_events (
      student_id, classroom_id, kind, title, created_by
    ) values (
      'abcf0000-0000-4000-8000-000000000008',
      'abcd0000-0000-4000-8000-000000000107',
      'note', 'Cross-school note',
      'aaaa0000-0000-4000-8000-000000000001'
    )$$,
  '%Cross-school or unresolved relationship%',
  'wellbeing cannot connect a foreign-school classroom'
);

select throws_like(
  $$insert into public.classroom_staff (
      school_id, classroom_id, membership_id, user_id, role
    ) select
      '11111111-1111-1111-1111-111111111111',
      'abcd0000-0000-4000-8000-000000000007', id, user_id, 'co_teacher'
    from public.memberships
    where school_id = '22222222-2222-2222-2222-222222222222'$$,
  '%foreign key constraint%',
  'classroom staff must use a same-school membership'
);

insert into public.file_objects (
  id, school_id, bucket, object_key, uploader_id, size_bytes, sha256
) values (
  'abd50000-0000-4000-8000-00000000010a',
  '11111111-1111-1111-1111-111111111111',
  'private-school-files', 'quarantine/seed',
  'aaaa0000-0000-4000-8000-000000000001', 10,
  repeat('a', 64)
);

insert into public.resources (
  id, school_id, title, resource_type, created_by
) values (
  'abd60000-0000-4000-8000-00000000010b',
  '11111111-1111-1111-1111-111111111111',
  'Seed Resource', 'lesson',
  'aaaa0000-0000-4000-8000-000000000001'
);

insert into public.resource_versions (
  id, school_id, resource_id, version, body, created_by
) values (
  'abd70000-0000-4000-8000-00000000010c',
  '11111111-1111-1111-1111-111111111111',
  'abd60000-0000-4000-8000-00000000010b', 1, 'Synthetic',
  'aaaa0000-0000-4000-8000-000000000001'
);

select throws_like(
  $$insert into public.resource_publications (
      school_id, resource_version_id, classroom_id, created_by
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'abd70000-0000-4000-8000-00000000010c',
      'abcd0000-0000-4000-8000-000000000107',
      'aaaa0000-0000-4000-8000-000000000001'
    )$$,
  '%foreign key constraint%',
  'a resource publication cannot target another school classroom'
);

select throws_like(
  $$insert into public.file_bindings (
      school_id, file_object_id, resource_version_id
    ) values (
      '22222222-2222-2222-2222-222222222222',
      'abd50000-0000-4000-8000-00000000010a',
      'abd70000-0000-4000-8000-00000000010c'
    )$$,
  '%foreign key constraint%',
  'a file binding cannot substitute another tenant'
);

insert into public.conversations (
  id, school_id, subject, created_by
) values (
  'abd80000-0000-4000-8000-00000000010d',
  '11111111-1111-1111-1111-111111111111', 'Synthetic thread',
  'aaaa0000-0000-4000-8000-000000000001'
);

select throws_like(
  $$insert into public.conversation_participants (
      school_id, conversation_id, user_id
    ) values (
      '22222222-2222-2222-2222-222222222222',
      'abd80000-0000-4000-8000-00000000010d',
      'eeee0000-0000-4000-8000-000000000005'
    )$$,
  '%foreign key constraint%',
  'a conversation participant cannot substitute another tenant'
);

insert into public.notification_outbox (
  school_id, source_event_id, idempotency_key, channel,
  template_key, recipient_id
) values (
  '11111111-1111-1111-1111-111111111111', 'seed:event',
  'seed:outbox', 'in_app', 'seed',
  'aaaa0000-0000-4000-8000-000000000001'
);

select throws_like(
  $$insert into public.notification_deliveries (
      school_id, outbox_id, recipient_id, channel, attempt
    ) select
      '22222222-2222-2222-2222-222222222222', id,
      'eeee0000-0000-4000-8000-000000000005', 'in_app', 1
    from public.notification_outbox where idempotency_key = 'seed:outbox'$$,
  '%foreign key constraint%',
  'an async delivery cannot substitute another tenant'
);

select throws_like(
  $$insert into public.file_objects (
      school_id, bucket, object_key, uploader_id, size_bytes, sha256
    ) values (
      null, 'private-school-files', 'quarantine/no-school',
      'aaaa0000-0000-4000-8000-000000000001', 1, repeat('b', 64)
    )$$,
  '%null value%',
  'file metadata requires a tenant'
);

select throws_like(
  $$insert into public.terms (
      school_id, name, starts_on, ends_on, active
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'Second Active Term', '2026-10-01', '2027-01-31', true
    )$$,
  '%duplicate key%',
  'a school cannot have two active terms'
);

insert into public.classroom_staff (
  school_id, classroom_id, membership_id, user_id, role
)
select school_id, 'abcd0000-0000-4000-8000-000000000007',
  id, user_id, 'lead_teacher'
from public.memberships
where school_id = '11111111-1111-1111-1111-111111111111'
  and user_id = 'aaaa0000-0000-4000-8000-000000000001'
  and role = 'teacher';

select throws_like(
  $$insert into public.classroom_staff (
      school_id, classroom_id, membership_id, user_id, role
    ) select school_id, 'abcd0000-0000-4000-8000-000000000007',
      id, user_id, 'lead_teacher'
    from public.memberships
    where school_id = '11111111-1111-1111-1111-111111111111'
      and user_id = 'aaaa0000-0000-4000-8000-000000000001'
      and role = 'teacher'$$,
  '%duplicate key%',
  'an active classroom staff assignment cannot be duplicated'
);

select throws_like(
  $$insert into public.grade_results (
      assessment_id, student_id, score
    ) values (
      'abd00000-0000-4000-8000-000000000009',
      'abcf0000-0000-4000-8000-000000000008', 11
    ) on conflict (assessment_id, student_id)
      do update set score = excluded.score$$,
  '%outside the assessment maximum%',
  'a grade cannot exceed the assessment maximum'
);

select throws_like(
  $$update public.assessments set maximum_score = 7
    where id = 'abd00000-0000-4000-8000-000000000009'$$,
  '%below an existing grade%',
  'an assessment maximum cannot be lowered below an existing grade'
);

select throws_like(
  $$insert into public.lesson_sessions (
      classroom_id, starts_at, ends_at, title
    ) values (
      'abcd0000-0000-4000-8000-000000000007', now(),
      now() - interval '1 minute', 'Invalid session'
    )$$,
  '%violates check constraint%',
  'lesson session end must follow start'
);

select throws_like(
  $$insert into public.file_bindings (
      school_id, file_object_id
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'abd50000-0000-4000-8000-00000000010a'
    )$$,
  '%violates check constraint%',
  'a file binding requires exactly one typed owner'
);

insert into public.idempotency_records (
  school_id, actor_id, scope, idempotency_key, request_hash,
  status, expires_at
) values (
  '11111111-1111-1111-1111-111111111111',
  'aaaa0000-0000-4000-8000-000000000001',
  'seed', 'same-key', repeat('c', 64), 'reserved', now() + interval '1 hour'
);

select throws_like(
  $$insert into public.idempotency_records (
      school_id, actor_id, scope, idempotency_key, request_hash,
      status, expires_at
    ) values (
      '11111111-1111-1111-1111-111111111111',
      'aaaa0000-0000-4000-8000-000000000001',
      'seed', 'same-key', repeat('d', 64), 'reserved', now() + interval '1 hour'
    )$$,
  '%duplicate key%',
  'idempotency keys are unique within tenant, actor, and scope'
);

insert into public.membership_events (
  school_id, membership_id, actor_id, event_type, idempotency_key
) select school_id, id, user_id, 'granted', 'seed:membership-event'
from public.memberships
where school_id = '11111111-1111-1111-1111-111111111111'
  and user_id = 'aaaa0000-0000-4000-8000-000000000001'
  and role = 'teacher';

select throws_like(
  $$update public.membership_events set reason = 'changed'
    where idempotency_key = 'seed:membership-event'$$,
  '%Append-only relation%',
  'membership history is append-only'
);

select throws_like(
  $$delete from public.resource_versions
    where id = 'abd70000-0000-4000-8000-00000000010c'$$,
  '%Append-only relation%',
  'resource versions are append-only'
);

select throws_like(
  $$update public.audit_events set action = 'changed'
    where action = 'fixture.seed'$$,
  '%Append-only relation%',
  'audit events are append-only'
);

select * from finish();
rollback;
