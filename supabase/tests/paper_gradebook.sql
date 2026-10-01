-- Paper gradebook (202609300001): marks entered for a whole class, private
-- until published, corrected with the value they replaced. Transactional
-- fixtures: everything below rolls back, leaving local data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(47);

\set second_student 'abcf0000-0000-4000-8000-0000000000a2'
\set outside_student 'abcf0000-0000-4000-8000-0000000000a3'
\set assistant_user 'aaaa0000-0000-4000-8000-0000000000a4'
\set admin_user 'aaaa0000-0000-4000-8000-0000000000a5'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values (:'assistant_user', 'gradebook.assistant@synthetic.studafy.test', 'x', 'authenticated',
  'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
  '', '', '', '{}', '{"full_name":"Gradebook Assistant"}'),
  (:'admin_user', 'gradebook.admin@synthetic.studafy.test', 'x', 'authenticated',
  'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '',
  '', '', '', '{}', '{"full_name":"Legacy Admin"}');
-- This release has no school administrator. A school_admin membership left
-- over from older data must not open anyone's gradebook.
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'admin_user', 'school_admin', true);
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'assistant_user', 'teacher', true);
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'classroom_id', m.id, :'assistant_user', 'assistant'
from public.memberships m where m.user_id = :'assistant_user';
insert into public.students (id, school_id, studafy_id, display_name, provisional, created_by) values
  (:'second_student', :'school_id', 'STU-GRADE-0002', 'Second Student', false, :'teacher_user'),
  (:'outside_student', :'school_id', 'STU-GRADE-0003', 'Outside Student', false, :'teacher_user');
insert into public.enrollments (classroom_id, student_id, active) values
  (:'classroom_id', :'second_student', true);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'paper-gradebook-test', true);

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

create function pg_temp.query(actor uuid, op text, resource uuid, input jsonb) returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api041_query(op, resource, input);
end $$;

create function pg_temp.allowed(actor uuid, action text, resource uuid) returns boolean
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return (private.authz_authorize(action, resource)->>'allowed')::boolean;
end $$;

create function pg_temp.gradebook_version(p uuid) returns bigint language sql as
  $$ select gradebook_version from public.assessments where id = p $$;

-- The item: a paper exam in the class, out of 20, weighted at 30%.
create temporary table item as
select (pg_temp.cmd(:'teacher_user', 'createAssessment', :'classroom_id',
  jsonb_build_object('classroomId', :'classroom_id', 'title', 'Midterm (paper)',
    'category', 'paper_exam', 'maximumScore', 20, 'scheduledAt', null,
    'delivery', 'paper', 'questions', '[]'::jsonb, 'weight', 30))->'response') as r;
select (r->>'id') as item_id from item \gset

select is((select (r->>'weight')::numeric from item), 30::numeric, 'a paper item carries its weight');
select is((select delivery from public.assessments where id = :'item_id'), 'paper',
  'the item is paper work');

-- Who may do what.
select ok(pg_temp.allowed(:'teacher_user', 'gradebook.write', :'item_id'),
  'the class teacher may enter marks');
select ok(pg_temp.allowed(:'assistant_user', 'gradebook.read', :'item_id'),
  'a class assistant may read the gradebook');
select ok(not pg_temp.allowed(:'assistant_user', 'gradebook.write', :'item_id'),
  'a class assistant may not enter marks');
select ok(not pg_temp.allowed(:'student_user', 'gradebook.read', :'item_id'),
  'a student may not read the class gradebook');
select ok(not pg_temp.allowed(:'guardian_user', 'gradebook.publish', :'item_id'),
  'a parent may not publish marks');
select ok(not pg_temp.allowed(:'other_school_user', 'gradebook.read', :'item_id'),
  'a teacher at another school may not read it');
select ok(not pg_temp.allowed(:'admin_user', 'gradebook.read', :'item_id'),
  'a school admin has no access to the gradebook');
select ok(not pg_temp.allowed(:'admin_user', 'gradebook.publish', :'item_id'),
  'a school admin cannot publish marks');
select ok(not has_function_privilege('studafy_api_runtime',
  'private.api041_save_grade_drafts(uuid,jsonb,uuid,bigint)', 'execute'),
  'the handler is reachable only through the dispatcher');

-- The sheet lists the class, unmarked.
select is(jsonb_array_length(pg_temp.query(:'teacher_user', 'listGradebook', :'item_id',
  '{"pageSize":100}')->'items'),
  (select count(*)::int from public.enrollments
   where classroom_id = :'classroom_id' and active and status = 'active'),
  'the gradebook lists every enrolled student');
select ok((select bool_and(i->'grade' = 'null'::jsonb) from jsonb_array_elements(
  pg_temp.query(:'teacher_user', 'listGradebook', :'item_id', '{}')->'items') i),
  'nobody has a mark yet - not a zero');
select is(pg_temp.query(:'assistant_user', 'listGradebook', :'item_id', '{}')->>'outcome',
  null, 'an assistant reads the sheet');
select is(pg_temp.query(:'admin_user', 'listGradebook', :'item_id', '{}')->>'outcome',
  'not_found', 'nor can a school admin read the sheet');
select is(pg_temp.query(:'student_user', 'listGradebook', :'item_id', '{}')->>'outcome',
  'not_found', 'a student cannot read the sheet');

-- Refusals write nothing.
select is(pg_temp.cmd(:'assistant_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 10)))
  )->>'outcome', 'forbidden', 'an assistant cannot save marks');
select is(pg_temp.cmd(:'student_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 20)))
  )->>'outcome', 'forbidden', 'a student cannot mark themselves');
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(
    jsonb_build_object('studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 10),
    jsonb_build_object('studentId', :'outside_student', 'expectedVersion', 0, 'mark', 'scored', 'score', 10))))
  ->'rows', jsonb_build_array(jsonb_build_object('studentId', :'outside_student', 'reason', 'not_enrolled')),
  'a student outside the class is refused by name');
select is((select count(*) from public.grade_results where assessment_id = :'item_id'), 0::bigint,
  'one bad row means nothing in the sheet is saved');
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 21))))
  ->'rows'->0->>'reason', 'score_out_of_range', 'a mark above the maximum is refused');
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 0, 'mark', 'absent', 'score', 5))))
  ->'rows'->0->>'reason', 'score_not_allowed', 'an absent student has no score');
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(
    jsonb_build_object('studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 1),
    jsonb_build_object('studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 2))))
  ->>'outcome', 'invalid', 'a student twice in one sheet is refused');

-- A valid sheet: one mark, one absence.
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('expectedGradebookVersion', pg_temp.gradebook_version(:'item_id'),
    'entries', jsonb_build_array(
    jsonb_build_object('studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 17.5,
      'feedback', 'Good work'),
    jsonb_build_object('studentId', :'second_student', 'expectedVersion', 0, 'mark', 'absent'))))
  ->'response'->>'saved', '2', 'the teacher saves the sheet as a draft');
select is((select score from public.grade_results where assessment_id = :'item_id'
  and student_id = :'second_student'), null, 'an absence is stored with no score, not zero');
select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 0, 'mark', 'scored', 'score', 3))))
  ->>'outcome', 'version_conflict', 'a save over someone else''s change conflicts');

-- Drafts are invisible to the student and their family.
select ok(not exists (select 1 from jsonb_array_elements(pg_temp.query(:'student_user',
  'listGradeResults', null, jsonb_build_object('studentId', :'student_id'))->'items') i
  where i->>'assessmentId' = :'item_id'), 'a student does not see a draft mark');
select ok(not exists (select 1 from jsonb_array_elements(pg_temp.query(:'guardian_user',
  'listGradeResults', null, jsonb_build_object('studentId', :'student_id'))->'items') i
  where i->>'assessmentId' = :'item_id'), 'a parent does not see a draft mark');
select set_config('request.jwt.claim.sub', :'student_user', true);
set local role authenticated;
select is((select count(*) from public.grade_results where assessment_id = :'item_id'), 0::bigint,
  'row security hides draft marks from a student reading directly');
reset role;

-- Publication is all or nothing, and only of what the teacher saw.
select is(pg_temp.cmd(:'teacher_user', 'publishGrades', :'item_id',
  jsonb_build_object('expectedGradebookVersion', pg_temp.gradebook_version(:'item_id') - 1))
  ->>'outcome', 'version_conflict', 'publishing a stale sheet is refused');
select is((select count(*) from public.grade_results where assessment_id = :'item_id'
  and state = 'published'), 0::bigint, 'a refused publication publishes nothing');
select is(pg_temp.cmd(:'teacher_user', 'publishGrades', :'item_id',
  jsonb_build_object('expectedGradebookVersion', pg_temp.gradebook_version(:'item_id')))
  ->'response'->>'published', '2', 'the teacher publishes the sheet');
select is((select count(*) from public.notification_outbox where source_event_id = :'item_id'
  and template_key = 'academic.grades_published'), 1::bigint,
  'one release is one outbox row, not one per student');
select is(private.api061_notification_recipients(:'school_id'::uuid, 'academic.grades_published',
    :'item_id', (select audience from public.notification_outbox where source_event_id = :'item_id'
      and template_key = 'academic.grades_published')),
  array[:'student_user', :'guardian_user']::uuid[],
  'the student and their verified guardian are told; the staff and the unverified are not');

-- Published marks reach the student and the parent, labelled as paper work.
select is((select i->>'delivery' || '/' || (i->>'score') from jsonb_array_elements(
  pg_temp.query(:'student_user', 'listGradeResults', null,
    jsonb_build_object('studentId', :'student_id'))->'items') i
  where i->>'assessmentId' = :'item_id'), 'paper/17.50', 'the student sees a paper mark');
select is((select i->>'mark' from jsonb_array_elements(pg_temp.query(:'guardian_user',
  'listGradeResults', null, jsonb_build_object('studentId', :'student_id'))->'items') i
  where i->>'assessmentId' = :'item_id'), 'scored', 'the parent sees the published mark');

-- Corrections.
create temporary table grade_ids as
select student_id, id, version from public.grade_results where assessment_id = :'item_id';
select id as first_grade from grade_ids where student_id = :'student_id' \gset
select id as second_grade from grade_ids where student_id = :'second_student' \gset

select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'item_id',
  jsonb_build_object('entries', jsonb_build_array(jsonb_build_object(
    'studentId', :'student_id', 'expectedVersion', 2, 'mark', 'scored', 'score', 3))))
  ->'rows'->0->>'reason', 'already_published', 'a published mark is changed by correcting it');
select is(pg_temp.cmd(:'teacher_user', 'correctGrades', :'item_id',
  jsonb_build_object('reason', '', 'entries', jsonb_build_array(jsonb_build_object(
    'gradeResultId', :'first_grade', 'expectedVersion', 2, 'mark', 'scored', 'score', 16))))
  ->>'outcome', 'reason_required', 'a correction needs a reason');
select is(pg_temp.cmd(:'teacher_user', 'correctGrades', :'item_id',
  jsonb_build_object('reason', 'Re-added page 3', 'entries', jsonb_build_array(
    jsonb_build_object('gradeResultId', :'first_grade', 'expectedVersion', 2,
      'mark', 'scored', 'score', 19, 'feedback', 'Good work'),
    jsonb_build_object('gradeResultId', :'second_grade', 'expectedVersion', 2,
      'mark', 'absent', 'feedback', 'Sat the exam late; see note'))))
  ->'response'->>'notified', '1', 'only the changed mark is announced; a comment edit is not');
select is((select previous_score::text || '>' || next_score::text || ' ' || reason || ' ' || actor_id::text
  from public.grade_result_events where grade_result_id = :'first_grade' and event_type = 'corrected'),
  '17.50>19.00 Re-added page 3 ' || :'teacher_user',
  'the correction keeps the old value, the new value, the reason and who made it');
select is((select material from public.grade_result_events where grade_result_id = :'second_grade'
  and event_type = 'corrected'), false, 'a comment-only edit is recorded as not material');
select is(private.api061_notification_recipients(:'school_id'::uuid, 'academic.grades_corrected',
    :'item_id', (select audience from public.notification_outbox where source_event_id = :'item_id'
      and template_key = 'academic.grades_corrected')),
  array[:'student_user', :'guardian_user']::uuid[], 'the family of the corrected mark is told');

-- The single-grade route keeps the old value too.
select is(pg_temp.cmd(:'teacher_user', 'correctGradeResult', :'first_grade',
  jsonb_build_object('expectedVersion', 3, 'score', 18, 'feedback', null, 'reason', 'Typo'))
  ->'response'->>'score', '18.00', 'the single correction route still answers the grade');
select is((select previous_score from public.grade_result_events where grade_result_id = :'first_grade'
  and reason = 'Typo'), 19.00::numeric, 'and records the value it replaced');
select is(jsonb_array_length(pg_temp.query(:'teacher_user', 'listGradeHistory', :'first_grade',
  '{}')->'items'), 3, 'the history lists the release and both corrections');
select is(pg_temp.query(:'student_user', 'listGradeHistory', :'first_grade', '{}')->>'outcome',
  'not_found', 'a student cannot read the change history');

-- The item cannot be made impossible for marks already given.
select is(pg_temp.cmd(:'teacher_user', 'updateGradebookItem', :'item_id',
  jsonb_build_object('expectedVersion', (select version from public.assessments where id = :'item_id'),
    'title', 'Midterm', 'category', 'paper_exam', 'maximumScore', 10, 'weight', null,
    'scheduledAt', null))->>'outcome', 'grade_entries_invalid',
  'lowering the maximum below a given mark is refused');

select * from finish();
rollback;
