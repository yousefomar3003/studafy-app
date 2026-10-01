-- Attendance corrections under the school's policy (202609300002).
-- Transactional fixtures: everything below rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(28);

\set co_teacher 'aaaa0000-0000-4000-8000-0000000000b1'
\set left_student 'abcf0000-0000-4000-8000-0000000000b2'
\set stranger_student 'abcf0000-0000-4000-8000-0000000000b3'
\set recent_session 'abd20000-0000-4000-8000-0000000000b4'
\set old_session 'abd20000-0000-4000-8000-0000000000b5'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'co_teacher', 'attendance.co@synthetic.studafy.test', 'x', 'authenticated',
  'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
  '', '', '', '{}', '{"full_name":"Co Teacher"}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'co_teacher', 'teacher', true);
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'classroom_id', m.id, :'co_teacher', 'co_teacher'
from public.memberships m where m.user_id = :'co_teacher';

insert into public.students (id, school_id, studafy_id, display_name, provisional, created_by) values
  (:'left_student', :'school_id', 'STU-ATT-0002', 'Left Student', false, :'teacher_user'),
  (:'stranger_student', :'school_id', 'STU-ATT-0003', 'Stranger Student', false, :'teacher_user');
-- Both enrolled from the start of term; one has since left.
update public.enrollments set starts_on = current_date - 30
where classroom_id = :'classroom_id' and student_id = :'student_id';
insert into public.enrollments (classroom_id, student_id, active, status, starts_on, ends_on)
values (:'classroom_id', :'left_student', false, 'withdrawn', current_date - 30, current_date - 1);

-- Today's lesson on the timetable, one lesson three days ago, one twelve.
insert into public.class_schedules (school_id, classroom_id, weekday, starts_at, ends_at, effective_from)
select :'school_id', :'classroom_id',
  extract(isodow from (now() at time zone 'Asia/Riyadh'))::smallint, '07:00', '07:45',
  current_date - 60;
select ((now() at time zone 'Asia/Riyadh')::date + time '07:00') at time zone 'Asia/Riyadh' as today_start \gset
insert into public.lesson_sessions (id, classroom_id, starts_at, ends_at, status) values
  (:'recent_session', :'classroom_id', now() - interval '3 days', now() - interval '3 days' + interval '45 minutes', 'completed'),
  (:'old_session', :'classroom_id', now() - interval '12 days', now() - interval '12 days' + interval '45 minutes', 'completed');
insert into public.attendance_records (session_id, student_id, state, recorded_by) values
  (:'recent_session', :'student_id', 'present', :'teacher_user'),
  (:'old_session', :'student_id', 'present', :'teacher_user'),
  (:'old_session', :'left_student', 'present', :'teacher_user');

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'attendance-corrections-test', true);

create function pg_temp.cmd(actor uuid, op text, resource uuid, body jsonb) returns jsonb
language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    op, gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api041_command(op, resource,
    jsonb_build_object('responseStatus', 200, 'body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.version(p uuid) returns bigint language sql as
  $$ select version from public.lesson_sessions where id = p $$;
create function pg_temp.mark(p uuid, s uuid) returns text language sql as
  $$ select state::text from public.attendance_records where session_id = p and student_id = s $$;
create function pg_temp.roster_rule(actor uuid, starts timestamptz) returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api041_query('listAttendanceRoster', 'abcd0000-0000-4000-8000-000000000007',
    jsonb_build_object('startsAt', starts))->>'editRule';
end $$;

-- Today: marks change freely, and every change is kept.
select is(pg_temp.cmd(:'teacher_user', 'recordAttendance', :'classroom_id', jsonb_build_object(
  'classroomId', :'classroom_id', 'startsAt', :'today_start',
  'endsAt', (:'today_start'::timestamptz + interval '45 minutes'), 'expectedVersion', 0,
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'present', 'reason', null))))
  ->'response'->>'version', '1', 'today''s register is recorded');
select is(pg_temp.roster_rule(:'teacher_user', :'today_start'), 'open', 'today''s register is open');
select is(pg_temp.cmd(:'co_teacher', 'recordAttendance', :'classroom_id', jsonb_build_object(
  'classroomId', :'classroom_id', 'startsAt', :'today_start',
  'endsAt', (:'today_start'::timestamptz + interval '45 minutes'), 'expectedVersion', 1,
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'late', 'reason', 'Bus'))))
  ->>'outcome', 'ok', 'a co-teacher changes a mark on the day without a reason');
select is((select previous_state::text || '>' || next_state::text || ' by ' || actor_id::text
  from public.attendance_record_revisions r join public.lesson_sessions ls on ls.id = r.session_id
  where ls.starts_at = :'today_start'::timestamptz),
  'present>late by ' || :'co_teacher', 'the change keeps the old mark and who changed it');
select is(pg_temp.cmd(:'co_teacher', 'recordAttendance', :'classroom_id', jsonb_build_object(
  'classroomId', :'classroom_id', 'startsAt', :'today_start',
  'endsAt', (:'today_start'::timestamptz + interval '45 minutes'), 'expectedVersion', 1,
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null))))
  ->>'outcome', 'version_conflict', 'saving over someone else''s save conflicts');

-- Three days ago: a changed mark needs a reason; a new mark does not.
select is(pg_temp.roster_rule(:'co_teacher', now() - interval '3 days'), 'reason_required',
  'a recent lesson needs a reason to change a mark');
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'recent_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'recent_session'), 'reason', '',
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null))))
  ->>'outcome', 'reason_required', 'changing a recent mark without a reason is refused');
select is(pg_temp.mark(:'recent_session', :'student_id'), 'present', 'and changes nothing');
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'recent_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'recent_session'), 'reason', 'Parent called: was sick',
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'excused', 'reason', 'Sick'))))
  ->>'outcome', 'ok', 'with a reason the co-teacher corrects it');
select is((select reason from public.attendance_record_revisions where session_id = :'recent_session'),
  'Parent called: was sick', 'the reason is kept with the change');
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'recent_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'recent_session'),
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'left_student', 'state', 'present', 'reason', null))))
  ->>'outcome', 'ok', 'a mark missed for a student who has since left can still be added');
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'recent_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'recent_session'),
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'stranger_student', 'state', 'present', 'reason', null))))
  ->'rows'->0->>'reason', 'not_enrolled', 'a student never in the class cannot be marked');

-- Twelve days ago: locked, except to the lead teacher with a reason.
select is(pg_temp.roster_rule(:'co_teacher', now() - interval '12 days'), 'locked',
  'an old register is locked to a co-teacher');
select is(pg_temp.roster_rule(:'teacher_user', now() - interval '12 days'), 'locked_override',
  'the lead teacher may override the lock');
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'old_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'old_session'), 'reason', 'Late correction', 'override', true,
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null))))
  ->>'outcome', 'attendance_locked', 'a co-teacher cannot override a lock');
select is(pg_temp.cmd(:'teacher_user', 'correctAttendance', :'old_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'old_session'), 'reason', 'Late correction',
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null))))
  ->>'outcome', 'attendance_locked', 'the lead teacher must ask to override');
select is(pg_temp.cmd(:'teacher_user', 'correctAttendance', :'old_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'old_session'), 'override', true,
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null))))
  ->>'outcome', 'reason_required', 'an override needs a reason');
select is(pg_temp.cmd(:'teacher_user', 'correctAttendance', :'old_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'old_session'), 'override', true, 'reason', 'Register was misread',
  'entries', jsonb_build_array(
    jsonb_build_object('studentId', :'student_id', 'state', 'absent', 'reason', null),
    jsonb_build_object('studentId', :'left_student', 'state', 'late', 'reason', null))))
  ->'response'->>'recorded', '2', 'the lead teacher corrects the whole register, a student who left included');
select is((select count(*) from public.attendance_record_revisions where session_id = :'old_session'
  and override and reason = 'Register was misread'), 2::bigint, 'each overridden change is recorded as such');

-- The timetable changing does not freeze the past.
delete from public.class_schedules where classroom_id = :'classroom_id';
select is(pg_temp.cmd(:'co_teacher', 'correctAttendance', :'recent_session', jsonb_build_object(
  'expectedVersion', pg_temp.version(:'recent_session'), 'reason', 'Rechecked register',
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'state', 'present', 'reason', null))))
  ->>'outcome', 'ok', 'a lesson stays correctable after the timetable changes');

-- A student who has left still shows on the lessons they were marked for.
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is((select i->>'enrolled' from jsonb_array_elements(private.api041_query(
    'listAttendanceRoster', :'classroom_id',
    jsonb_build_object('startsAt', (select starts_at from public.lesson_sessions where id = :'old_session')))
  ->'items') i where i->'student'->>'id' = :'left_student'), 'false',
  'a student who left is on the register of a lesson they were marked for, flagged');
select is((select i->'record'->>'state' from jsonb_array_elements(private.api041_query(
    'listAttendanceRoster', :'classroom_id',
    jsonb_build_object('startsAt', (select starts_at from public.lesson_sessions where id = :'old_session')))
  ->'items') i where i->'student'->>'id' = :'left_student'), 'late',
  'with the mark they were given');

-- Who may do this at all.
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(not (private.authz_authorize('attendance_session.correct', :'recent_session')->>'allowed')::boolean,
  'a parent cannot correct attendance');
select set_config('request.jwt.claim.sub', :'student_user', true);
select ok(not (private.authz_authorize('attendance_session.correct', :'recent_session')->>'allowed')::boolean,
  'a student cannot correct attendance');
select is(private.api041_query('listAttendanceHistory', :'recent_session', '{}')->>'outcome',
  'not_found', 'a student cannot read the correction history');
select set_config('request.jwt.claim.sub', :'other_school_user', true);
select ok(not (private.authz_authorize('attendance_session.correct', :'old_session')->>'allowed')::boolean,
  'a teacher at another school cannot correct it');
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(jsonb_array_length(private.api041_query('listAttendanceHistory', :'recent_session', '{}')->'items'),
  2, 'the class teacher reads every change to an existing mark');
select throws_ok($$update public.attendance_record_revisions set reason = 'rewritten'$$,
  null, 'the history cannot be rewritten');

select * from finish();
rollback;
