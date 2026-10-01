-- Deadlines for handed-in work (202609300003): replace until the deadline,
-- extensions and reopening, and no replacing work already marked.
-- Transactional fixtures: everything below rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(30);

\set work_id 'a0430000-0000-4000-8000-000000000001'
\set kept_file 'a0430000-0000-4000-8000-000000000002'
\set foreign_file 'a0430000-0000-4000-8000-000000000003'
\set outside_student 'a0430000-0000-4000-8000-000000000004'

update public.schools set timezone = 'Asia/Riyadh' where id = :'school_id';
insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, version, published_at)
values (:'work_id', :'school_id', :'classroom_id', 'Essay', now() + interval '1 day', 'published',
  :'teacher_user', 1, now());
insert into public.students (id, school_id, studafy_id, display_name, provisional, created_by)
values (:'outside_student', :'school_id', 'STU-DL-0004', 'Outside', false, :'teacher_user');
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name) values
  (:'kept_file', :'school_id', 'legacy', 'deadline/kept', :'student_user', 10, 'application/pdf', repeat('a', 64),
    'clean', now(), :'student_user', 'assignment_submission', 'Essay draft.pdf'),
  (:'foreign_file', :'school_id', 'legacy', 'deadline/foreign', :'teacher_user', 10, 'application/pdf', repeat('b', 64),
    'clean', now(), :'teacher_user', 'assignment_submission', 'Not yours.pdf');

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'submission-deadlines-test', true);

create function pg_temp.cmd(actor uuid, op text, resource uuid, body jsonb) returns jsonb
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    op, gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api041_command(op, resource,
    jsonb_build_object('responseStatus', 201, 'body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.hand_in(actor uuid, body jsonb) returns jsonb language sql as
  $$ select pg_temp.cmd(actor, 'submitAssignment', 'a0430000-0000-4000-8000-000000000001', body) $$;
create function pg_temp.attempts() returns bigint language sql as $$
  select count(*) from public.submission_attempts sa join public.submissions s on s.id = sa.submission_id
  where s.assignment_id = 'a0430000-0000-4000-8000-000000000001' $$;
create function pg_temp.view(actor uuid) returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api041_query('getAssignment', 'a0430000-0000-4000-8000-000000000001', '{}');
end $$;
create function pg_temp.local_in(days int) returns text language sql as $$
  select to_char((now() at time zone 'Asia/Riyadh') + make_interval(days => days), 'YYYY-MM-DD"T"HH24:MI') $$;

-- Before the deadline: hand in, then replace, keeping a file.
select is(pg_temp.hand_in(:'student_user', '{"answerText":"First go"}')->'response'->>'late', 'false',
  'work handed in before the due time is on time');
insert into public.file_bindings (school_id, file_object_id, submission_attempt_id)
select :'school_id', :'kept_file', s.current_attempt_id from public.submissions s where s.assignment_id = :'work_id';
select is(jsonb_array_length(pg_temp.hand_in(:'student_user', jsonb_build_object(
  'answerText', 'Second go', 'attachmentFileIds', jsonb_build_array(:'kept_file')))->'response'->'attachments'),
  1, 'a replacement keeps a file from the work it replaces without uploading it again');
select is(pg_temp.attempts(), 2::bigint, 'the replacement is a new attempt; the first is kept');
select is((select count(*) from public.file_bindings where file_object_id = :'kept_file'
  and submission_attempt_id is not null), 2::bigint, 'the first attempt still has its file');
select is(pg_temp.hand_in(:'student_user', jsonb_build_object(
  'answerText', 'Third go', 'attachmentFileIds', jsonb_build_array(:'foreign_file')))->>'outcome',
  'forbidden', 'someone else''s file cannot be attached');
select is(pg_temp.attempts(), 2::bigint, 'a refused hand-in leaves no attempt behind');
select is(pg_temp.view(:'student_user')->>'submissionState', 'open', 'the student sees the work is open');
select is(pg_temp.view(:'student_user')->>'timeZone', 'Asia/Riyadh', 'deadlines come with the school''s zone');
select is(pg_temp.view(:'student_user')->>'dueLocal',
  to_char((now() + interval '1 day') at time zone 'Asia/Riyadh', 'YYYY-MM-DD"T"HH24:MI'),
  'and as the school''s wall-clock time');

-- After the deadline: closed until the teacher gives more time.
update public.assignments set due_at = now() - interval '1 hour' where id = :'work_id';
select is(pg_temp.hand_in(:'student_user', '{"answerText":"Too late"}')->>'outcome', 'window_closed',
  'after the deadline work cannot be replaced');
select is(pg_temp.view(:'student_user')->>'submissionState', 'closed', 'and the student is told so');
select is(pg_temp.hand_in(:'guardian_user', jsonb_build_object('answerText', 'For my child',
  'studentId', :'student_id'))->>'outcome', 'window_closed', 'a guardian is held to the same deadline');
select is(pg_temp.cmd(:'student_user', 'grantAssignmentExtension', :'work_id', jsonb_build_object(
  'studentId', :'student_id', 'extendedUntilLocal', pg_temp.local_in(2), 'reason', 'Please'))->>'outcome',
  'forbidden', 'a student cannot extend their own deadline');
select is(pg_temp.cmd(:'teacher_user', 'grantAssignmentExtension', :'work_id', jsonb_build_object(
  'studentId', :'outside_student', 'extendedUntilLocal', pg_temp.local_in(2), 'reason', 'Ill'))->'rows'->0->>'reason',
  'not_enrolled', 'an extension is only for a student in the class');
select is(pg_temp.cmd(:'teacher_user', 'grantAssignmentExtension', :'work_id', jsonb_build_object(
  'studentId', :'student_id', 'extendedUntilLocal', pg_temp.local_in(-1), 'reason', 'Ill'))->>'outcome',
  'invalid', 'an extension into the past is refused');
select is(pg_temp.cmd(:'teacher_user', 'grantAssignmentExtension', :'work_id', jsonb_build_object(
  'studentId', :'student_id', 'extendedUntilLocal', pg_temp.local_in(2), 'reason', 'Was ill'))
  ->'response'->>'extendedUntilLocal', pg_temp.local_in(2), 'the teacher gives one student two more days');
select is(pg_temp.hand_in(:'student_user', '{"answerText":"With more time"}')->'response'->>'late', 'true',
  'with an extension the student hands in, marked late');
select is((pg_temp.view(:'student_user')->'extension'->>'reason'), 'Was ill',
  'the student sees their extension');
select is(pg_temp.cmd(:'teacher_user', 'revokeAssignmentExtension', :'work_id',
  jsonb_build_object('studentId', :'student_id'))->>'outcome', 'ok', 'the teacher withdraws the extension');
select is(pg_temp.hand_in(:'student_user', '{"answerText":"Again"}')->>'outcome', 'window_closed',
  'without it the work is closed again');

-- Reopening for the whole class.
select is(pg_temp.cmd(:'teacher_user', 'reopenAssignment', :'work_id', jsonb_build_object(
  'expectedVersion', (select version from public.assignments where id = :'work_id'),
  'closesAtLocal', pg_temp.local_in(1), 'reason', 'Power cut'))->>'outcome', 'ok',
  'the teacher reopens the work for the class');
select is(pg_temp.hand_in(:'guardian_user', jsonb_build_object('answerText', 'For my child',
  'studentId', :'student_id'))->>'outcome', 'ok', 'a guardian hands in for their child while it is open');
select isnt((select sa.submitted_by_guardian_id from public.submissions s
  join public.submission_attempts sa on sa.id = s.current_attempt_id where s.assignment_id = :'work_id'),
  null, 'and the attempt says a guardian handed it in');

-- Once a mark is published, the work on file is what was marked.
insert into public.assessments (school_id, classroom_id, title, category, maximum_score, state, delivery,
  created_by, published_at, assignment_id)
values (:'school_id', :'classroom_id', 'Essay', 'assignment', 10, 'published', 'online', :'teacher_user',
  now(), :'work_id');
insert into public.grade_results (school_id, assessment_id, student_id, score, state, reviewed_by,
  reviewed_at, published_by, published_at)
select :'school_id', a.id, :'student_id', 8, 'published', :'teacher_user', now(), :'teacher_user', now()
from public.assessments a where a.assignment_id = :'work_id';
select is(pg_temp.hand_in(:'student_user', '{"answerText":"After the mark"}')->>'outcome', 'graded_locked',
  'marked work cannot be replaced');
select is(pg_temp.hand_in(:'guardian_user', jsonb_build_object('answerText', 'x', 'studentId', :'student_id'))
  ->>'outcome', 'graded_locked', 'not by a guardian either');
select is(pg_temp.cmd(:'teacher_user', 'grantAssignmentExtension', :'work_id', jsonb_build_object(
  'studentId', :'student_id', 'extendedUntilLocal', pg_temp.local_in(3), 'reason', 'Resubmit after feedback'))
  ->>'outcome', 'ok', 'the teacher may let the student resubmit');
select is(pg_temp.hand_in(:'student_user', '{"answerText":"Improved"}')->>'outcome', 'ok',
  'an extension granted after the mark reopens the work for that student');

-- Who may change deadlines.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(not (private.authz_authorize('assignment.extend', :'work_id')->>'allowed')::boolean,
  'a parent cannot extend a deadline');
select set_config('request.jwt.claim.sub', :'other_school_user', true);
select ok(not (private.authz_authorize('assignment.reopen', :'work_id')->>'allowed')::boolean,
  'a teacher at another school cannot reopen the work');

-- A due time picked in school time means school time.
select is((pg_temp.cmd(:'teacher_user', 'createAssignment', :'classroom_id', jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Local due', 'instructions', null,
  'dueAt', '2026-10-01T23:59:00+00:00', 'dueLocal', '2026-10-01T23:59', 'closesAt', null))
  ->'response'->>'dueAt')::timestamptz, '2026-10-01T20:59:00+00:00'::timestamptz,
  'a due time picked as 23:59 school time is 23:59 in Riyadh, whatever the device said');

select * from finish();
rollback;
