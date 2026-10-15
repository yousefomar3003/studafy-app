-- Online assessments, answer release and coursework attachments
-- (202610060001, ADR-0036). Transactional fixtures: everything rolls back.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(63);

\set student2_user 'a0460000-0000-4000-8000-0000000000a1'
\set student2_id 'a0460000-0000-4000-8000-0000000000a2'
\set guardian2_user 'a0460000-0000-4000-8000-0000000000a3'
\set question_file 'a0460000-0000-4000-8000-0000000000f1'
\set shared_file 'a0460000-0000-4000-8000-0000000000f2'
\set own_file 'a0460000-0000-4000-8000-0000000000f3'
\set other_file 'a0460000-0000-4000-8000-0000000000f4'
\set lesson_file 'a0460000-0000-4000-8000-0000000000f5'

-- A second student in the class, and a parent linked only to them.
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
values
  (:'student2_user', 'oa.student2@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
    now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}'),
  (:'guardian2_user', 'oa.guardian2@synthetic.studafy.test', 'x', 'authenticated', 'authenticated',
    now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}');
insert into public.memberships (school_id, user_id, role, active)
values (:'school_id', :'student2_user', 'student', true);
insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'student2_id', :'school_id', :'student2_user', 'STU-OA-0002', 'Second Student', false, :'teacher_user');
insert into public.enrollments (classroom_id, student_id, active) values (:'classroom_id', :'student2_id', true);
insert into public.guardian_links (student_id, guardian_id, status, relationship, verified_by, verified_at)
values (:'student2_id', :'guardian2_user', 'verified', 'parent', :'teacher_user', now());

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'online-assessments-test', true);

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
create function pg_temp.q(actor uuid, op text, resource uuid, input jsonb default '{}') returns jsonb
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api041_query(op, resource, input);
end $$;
create function pg_temp.download(actor uuid, file uuid) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return (private.file051_authorize_download(file)->>'allowed')::boolean;
end $$;
create function pg_temp.allowed(actor uuid, action text, resource uuid) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return (private.authz_authorize(action, resource)->>'allowed')::boolean;
end $$;
create function pg_temp.upload(file uuid, owner uuid, purpose text, class uuid, name text) returns void
language plpgsql as $$
declare v_session uuid := gen_random_uuid();
begin
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
    declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name)
  values (file, current_setting('studafy.school_id')::uuid, 'legacy', 'oa/' || file, owner, 10,
    'application/pdf', encode(extensions.digest(file::text, 'sha256'), 'hex'), 'clean', now(), owner,
    purpose::public.file_purpose, name);
  insert into public.upload_sessions (id, school_id, uploader_id, purpose, expected_size_bytes,
    allowed_media_types, nonce_hash, expires_at, classroom_id)
  values (v_session, current_setting('studafy.school_id')::uuid, owner, purpose::public.file_purpose, 10,
    array['application/pdf'], encode(extensions.digest('nonce' || file::text, 'sha256'), 'hex'),
    now() + interval '1 hour', class);
  insert into public.file_bindings (school_id, file_object_id, upload_session_id)
  values (current_setting('studafy.school_id')::uuid, file, v_session);
end $$;

select pg_temp.upload(:'question_file', :'teacher_user', 'assignment_material', :'classroom_id', 'Diagram.pdf');

-- ---------------------------------------------------------------------------
-- Building it
-- ---------------------------------------------------------------------------

create temporary table oa(name text primary key, value jsonb);
insert into oa values ('questions', jsonb_build_array(
  jsonb_build_object('position', 1, 'kind', 'single_choice', 'prompt', 'Capital of France?',
    'maximumScore', 2, 'options', jsonb_build_array(
      jsonb_build_object('id', 'a', 'text', 'Paris'), jsonb_build_object('id', 'b', 'text', 'Rome')),
    'correctOptionIds', jsonb_build_array('a'), 'preferredAnswer', null,
    'attachmentFileIds', jsonb_build_array(:'question_file'),
    'links', jsonb_build_array(jsonb_build_object('title', 'Map', 'url', 'https://maps.example.org/fr'))),
  jsonb_build_object('position', 2, 'kind', 'multiple_choice', 'prompt', 'Primes?',
    'maximumScore', 3, 'options', jsonb_build_array(
      jsonb_build_object('id', 'a', 'text', '2'), jsonb_build_object('id', 'b', 'text', '4'),
      jsonb_build_object('id', 'c', 'text', '5')),
    'correctOptionIds', jsonb_build_array('a', 'c'), 'preferredAnswer', null),
  jsonb_build_object('position', 3, 'kind', 'true_false', 'prompt', 'Water boils at 100C at sea level.',
    'maximumScore', 1, 'correctChoice', true, 'preferredAnswer', null),
  jsonb_build_object('position', 4, 'kind', 'short_answer', 'prompt', 'Chemical symbol of gold?',
    'maximumScore', 1, 'acceptedAnswers', jsonb_build_array('Au'), 'preferredAnswer', null),
  jsonb_build_object('position', 5, 'kind', 'essay', 'prompt', 'Explain photosynthesis.',
    'maximumScore', 3, 'preferredAnswer', 'Light energy makes sugar from CO2 and water.',
    'markingGuidance', 'One mark each for light, CO2, water.')));

select is(pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Bad key', 'category', 'quiz', 'maximumScore', 2,
  'scheduledAt', null, 'delivery', 'online', 'questions', jsonb_build_array(
    jsonb_build_object('position', 1, 'kind', 'single_choice', 'prompt', 'Two keys?', 'maximumScore', 2,
      'options', jsonb_build_array(jsonb_build_object('id', 'a', 'text', 'x'), jsonb_build_object('id', 'b', 'text', 'y')),
      'correctOptionIds', jsonb_build_array('a', 'b'), 'preferredAnswer', null))))->>'outcome',
  'invalid', 'a single-answer question with two correct answers is refused before anything is created');

insert into oa select 'created', pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Science quiz', 'category', 'quiz', 'maximumScore', 10,
  'scheduledAt', null, 'delivery', 'online', 'questions', (select value from oa where name = 'questions'),
  'opensAt', now() - interval '1 hour', 'closesAt', now() + interval '1 hour', 'maxAttempts', 2,
  'attemptPolicy', 'best', 'answerRelease', 'after_close',
  'links', jsonb_build_array(jsonb_build_object('title', 'Revision notes', 'url', 'https://notes.example.org/sci'))));
select is((select value->>'outcome' from oa where name = 'created'), 'ok', 'a teacher builds a mixed-question quiz');
select (value->'response'->>'id')::uuid as quiz_id from oa where name = 'created' \gset
select is((select value->'response'->>'maximumScore' from oa where name = 'created')::numeric, 10::numeric,
  'its total is the sum of the questions');
select is((select value->'response'->'links'->0->>'title' from oa where name = 'created'), 'Revision notes',
  'its links come back titled');
select is((select count(*) from public.assessment_questions where assessment_id = :'quiz_id' and kind = 'essay'), 1::bigint,
  'each question keeps its kind');

select is(pg_temp.q(:'teacher_user', 'listAssessmentAuthoringQuestions', :'quiz_id')->'items'->0->'correctOptionIds', '["a"]'::jsonb,
  'the teacher authoring view carries the answer key');
select is(jsonb_array_length(pg_temp.q(:'teacher_user', 'listAssessmentAuthoringQuestions', :'quiz_id')->'items'->0->'attachments'),
  1, 'and the question''s file');

select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Bad link', 'instructions', null,
  'dueAt', now() + interval '1 day', 'closesAt', null,
  'links', jsonb_build_array(jsonb_build_object('title', 'x', 'url', 'javascript:alert(1)'))))->>'outcome',
  'attachment_refused', 'a link that is not https is refused');
select is(pg_temp.cmd(:'teacher_user', 'createAssignment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Creds', 'instructions', null,
  'dueAt', now() + interval '1 day', 'closesAt', null,
  'links', jsonb_build_array(jsonb_build_object('title', 'x', 'url', 'https://user:pw@evil.example.com/'))))->>'outcome',
  'attachment_refused', 'so is one carrying credentials');

select is(pg_temp.cmd(:'teacher_user', 'publishAssessment', :'quiz_id',
  jsonb_build_object('expectedVersion', (select version from public.assessments where id = :'quiz_id')))->>'outcome',
  'ok', 'the teacher publishes it');

-- ---------------------------------------------------------------------------
-- Taking it
-- ---------------------------------------------------------------------------

select is(jsonb_array_length(pg_temp.q(:'student_user', 'listAssessmentQuestions', :'quiz_id')->'items'), 5,
  'a student sees the five questions');
select ok(not exists (select 1 from jsonb_array_elements(
    pg_temp.q(:'student_user', 'listAssessmentQuestions', :'quiz_id')->'items') i
  where i ?| array['correctOptionIds', 'correctChoice', 'acceptedAnswers', 'preferredAnswer', 'markingGuidance']),
  'with no key, model answer or marking guidance in any of them');
select is(pg_temp.q(:'other_school_user', 'listAssessmentQuestions', :'quiz_id')->>'outcome', 'not_found',
  'another school sees nothing');
select ok(pg_temp.download(:'student_user', :'question_file'), 'a student opens a question''s file once it is open');
select ok(not pg_temp.download(:'other_school_user', :'question_file'), 'another school cannot');
select ok(not has_column_privilege('authenticated', 'public.assessment_questions', 'answer_key', 'select'),
  'the answer key cannot be read from the table directly');

select (select jsonb_agg(jsonb_build_object('id', q.id, 'kind', q.kind, 'position', q.position) order by q.position)
  from public.assessment_questions q where q.assessment_id = :'quiz_id') as qs \gset
create function pg_temp.answers(single text, multi jsonb, tf boolean, short text, essay text) returns jsonb
language sql as $$
  select jsonb_build_array(
    jsonb_build_object('questionId', q1.id, 'selectedOptionIds', jsonb_build_array(single)),
    jsonb_build_object('questionId', q2.id, 'selectedOptionIds', multi),
    jsonb_build_object('questionId', q3.id, 'choice', tf),
    jsonb_build_object('questionId', q4.id, 'answerText', short),
    jsonb_build_object('questionId', q5.id, 'answerText', essay))
  from public.assessment_questions q1, public.assessment_questions q2, public.assessment_questions q3,
    public.assessment_questions q4, public.assessment_questions q5
  where q1.assessment_id = q2.assessment_id and q1.position = 1 and q2.position = 2 and q3.position = 3
    and q4.position = 4 and q5.position = 5 and q3.assessment_id = q1.assessment_id
    and q4.assessment_id = q1.assessment_id and q5.assessment_id = q1.assessment_id
    and q1.assessment_id = (select id from public.assessments where title = 'Science quiz')
$$;

select is(pg_temp.cmd(:'guardian_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('a', '["a","c"]', true, 'Au', 'x')))->>'outcome',
  'forbidden', 'a parent cannot sit it for their child');
select is(pg_temp.cmd(:'student_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', (select jsonb_agg(x) from jsonb_array_elements(
    pg_temp.answers('a', '["a","c"]', true, 'Au', 'x')) x where x ? 'selectedOptionIds')))->>'outcome',
  'invalid', 'a required question left out is refused');

insert into oa select 'first', pg_temp.cmd(:'student_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('a', '["a"]', true, '  au ', 'Plants use light.')));
select is((select value->>'outcome' from oa where name = 'first'), 'ok', 'the student submits an attempt');
select is((select value->'response'->>'attemptNumber' from oa where name = 'first')::int, 1, 'numbered 1');
select ok(not ((select value->'response' from oa where name = 'first') ?| array['awardedScore', 'answers', 'score']),
  'the confirmation carries no mark');
select (value->'response'->>'id')::uuid as attempt1 from oa where name = 'first' \gset

select is(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->>'answersReleased', 'false',
  'answers are not released while the quiz is open');
select ok(not (pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->'attempts'->0 ? 'answers'),
  'so the student''s attempt carries no answers or marks');
select ok(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->'grade' is null
    or jsonb_typeof(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->'grade') = 'null',
  'and no grade before it is published');

-- Marking.
select is((select t.needs_marking from public.assessment_attempts t where t.id = :'attempt1'), true,
  'the essay waits for the teacher');
select is((select jsonb_agg((x->>'autoScore')::numeric order by (x->'question'->>'position')::int)
  from jsonb_array_elements(pg_temp.q(:'teacher_user', 'getAssessmentAttempt', :'attempt1')->'answers') x),
  '[2, 0, 1, 1, null]'::jsonb,
  'single, true/false and the short answer (any case, any spaces) are marked; a partial multiple choice scores nothing');
select is(pg_temp.q(:'student_user', 'getAssessmentAttempt', :'attempt1')->>'outcome', 'not_found',
  'a student cannot read the teacher''s view of an attempt');
select is(pg_temp.cmd(:'student_user', 'markAssessmentAttempt', :'attempt1', jsonb_build_object(
  'marks', jsonb_build_array(jsonb_build_object('questionId', (select id from public.assessment_questions
    where assessment_id = :'quiz_id' and position = 5), 'score', 3))))->>'outcome',
  'forbidden', 'nor mark one');
select is(pg_temp.cmd(:'teacher_user', 'markAssessmentAttempt', :'attempt1', jsonb_build_object(
  'marks', jsonb_build_array(jsonb_build_object('questionId', (select id from public.assessment_questions
    where assessment_id = :'quiz_id' and position = 5), 'score', 9))))->>'outcome',
  'invalid', 'a mark above the question''s score is refused');
select is(pg_temp.cmd(:'teacher_user', 'markAssessmentAttempt', :'attempt1', jsonb_build_object(
  'feedback', 'Good start.',
  'marks', jsonb_build_array(jsonb_build_object('questionId', (select id from public.assessment_questions
    where assessment_id = :'quiz_id' and position = 5), 'score', 2, 'feedback', 'Mention CO2.'))))->>'outcome',
  'ok', 'the teacher marks the essay');
select is((select g.score from public.grade_results g where g.assessment_id = :'quiz_id' and g.student_id = :'student_id'),
  6::numeric, 'the student''s grade is the marked total');
select is((select g.state::text from public.grade_results g where g.assessment_id = :'quiz_id' and g.student_id = :'student_id'),
  'reviewed', 'ready to publish, not yet published');

-- Attempts.
select is(pg_temp.cmd(:'student_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('a', '["a","c"]', true, 'Au', 'Light, CO2 and water.')))->>'outcome',
  'ok', 'a second attempt is allowed');
select is(pg_temp.cmd(:'student_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('a', '["a","c"]', true, 'Au', 'Again.')))->>'outcome',
  'invalid_state', 'a third is not');

-- Student 2 gets more time.
select is(pg_temp.cmd(:'teacher_user', 'grantAssessmentAccess', :'quiz_id', jsonb_build_object(
  'studentId', :'student2_id', 'closesAt', now() + interval '2 hours', 'extraAttempts', 0))->>'outcome',
  'ok', 'the teacher gives the second student more time');

-- ---------------------------------------------------------------------------
-- Release
-- ---------------------------------------------------------------------------

select is(pg_temp.cmd(:'teacher_user', 'updateAssessmentDesign', :'quiz_id', jsonb_build_object(
  'expectedVersion', (select version from public.assessments where id = :'quiz_id'),
  'answerRelease', 'manual', 'releaseAnswersNow', true))->>'outcome',
  'window_closed', 'answers cannot be released by hand while anyone can still attempt');

update public.assessments set closes_at = now() - interval '1 second' where id = :'quiz_id';
select is(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->>'answersReleased', 'false',
  'closed for the class, but not for the student with more time: still nothing released');
select is(pg_temp.cmd(:'student2_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('b', '["b"]', false, 'Ag', 'Not sure.')))->>'outcome',
  'ok', 'the student with more time can still submit');
select is(pg_temp.cmd(:'student_user', 'submitAssessment', :'quiz_id',
  jsonb_build_object('answers', pg_temp.answers('a', '["a"]', true, 'Au', 'Late.')))->>'outcome',
  'window_closed', 'a student without it cannot');

update public.assessment_access_grants set closes_at = now() - interval '1 second'
where assessment_id = :'quiz_id';
select is(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->>'answersReleased', 'true',
  'closed for everyone: answers are released');
select is(pg_temp.q(:'student_user', 'getAssessmentResults', :'quiz_id')->'attempts'->0->'answers'->0->'question'->'correctOptionIds', '["a"]'::jsonb,
  'now the student''s attempt carries the key');
select is(pg_temp.q(:'guardian_user', 'getAssessmentResults', :'quiz_id',
    jsonb_build_object('studentId', :'student_id'))->>'outcome', 'ok',
  'the linked parent reads their child''s results');
select is(pg_temp.q(:'guardian2_user', 'getAssessmentResults', :'quiz_id',
    jsonb_build_object('studentId', :'student_id'))->>'outcome', 'not_found',
  'a parent of another child cannot');
select is(pg_temp.q(:'student2_user', 'getAssessmentResults', :'quiz_id',
    jsonb_build_object('studentId', :'student_id'))->>'outcome', 'not_found',
  'nor can another student');

-- After grading: also needs every attempt marked and grades published.
select is(pg_temp.cmd(:'teacher_user', 'updateAssessmentDesign', :'quiz_id', jsonb_build_object(
  'expectedVersion', (select version from public.assessments where id = :'quiz_id'),
  'answerRelease', 'after_grading'))->>'outcome', 'ok', 'the teacher delays release until grading');
select is(private.assessment_answers_released(:'quiz_id'), false, 'unmarked attempts hold the answers back');

-- ---------------------------------------------------------------------------
-- Paper grades: shared and individual attachments
-- ---------------------------------------------------------------------------

insert into oa select 'paper', pg_temp.cmd(:'teacher_user', 'createAssessment', null, jsonb_build_object(
  'classroomId', :'classroom_id', 'title', 'Paper test', 'category', 'test', 'maximumScore', 20,
  'scheduledAt', null, 'delivery', 'paper', 'questions', '[]'::jsonb));
select (value->'response'->>'id')::uuid as paper_id from oa where name = 'paper' \gset
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok((private.file050_authorize_target(jsonb_build_object('purpose', 'paper_scan',
  'schoolId', :'school_id', 'classroomId', :'classroom_id'))->>'allowed')::boolean,
  'the class''s teacher may upload a paper scan for the class');
select set_config('request.jwt.claim.sub', :'student_user', true);
select ok(not coalesce((private.file050_authorize_target(jsonb_build_object('purpose', 'paper_scan',
  'schoolId', :'school_id', 'classroomId', :'classroom_id'))->>'allowed')::boolean, false),
  'a student may not');
select pg_temp.upload(:'shared_file', :'teacher_user', 'paper_scan', :'classroom_id', 'Question paper.pdf');
select pg_temp.upload(:'own_file', :'teacher_user', 'paper_scan', :'classroom_id', 'Marked sheet 1.pdf');
select pg_temp.upload(:'other_file', :'teacher_user', 'paper_scan', :'classroom_id', 'Marked sheet 2.pdf');

select is(pg_temp.cmd(:'teacher_user', 'updateGradeAttachments', :'paper_id', jsonb_build_object(
  'attachmentFileIds', jsonb_build_array(:'shared_file'),
  'links', jsonb_build_array(jsonb_build_object('title', 'Mark scheme', 'url', 'https://school.example.org/ms'))))->>'outcome',
  'ok', 'the teacher attaches the question paper for the class');
select is(pg_temp.cmd(:'teacher_user', 'updateGradeAttachments', :'paper_id', jsonb_build_object(
  'studentId', :'student_id', 'attachmentFileIds', jsonb_build_array(:'own_file')))->>'outcome',
  'ok', 'and a marked sheet for one student');
select is(pg_temp.cmd(:'teacher_user', 'updateGradeAttachments', :'paper_id', jsonb_build_object(
  'studentId', :'student2_id', 'attachmentFileIds', jsonb_build_array(:'other_file')))->>'outcome',
  'ok', 'and another for the second student');
select is(jsonb_array_length(pg_temp.q(:'teacher_user', 'listGradebook', :'paper_id')->'item'->'sharedAttachments'), 1,
  'the gradebook shows the shared attachment apart');
select ok(not pg_temp.download(:'student_user', :'shared_file') and not pg_temp.download(:'student_user', :'own_file'),
  'before publishing, the student opens neither');
select is(jsonb_array_length((select private.api041_assessment_json(:'paper_id'))->'attachments'), 0,
  'shared results are not listed as the assessment''s material');

select is(pg_temp.cmd(:'teacher_user', 'saveGradeDrafts', :'paper_id', jsonb_build_object(
  'entries', jsonb_build_array(jsonb_build_object('studentId', :'student_id', 'expectedVersion',
    (select coalesce(version, 0) from public.grade_results where assessment_id = :'paper_id' and student_id = :'student_id'),
    'mark', 'scored', 'score', 15))))->>'outcome', 'ok', 'the teacher marks the first student');
select is(pg_temp.cmd(:'teacher_user', 'publishGrades', :'paper_id', jsonb_build_object(
  'expectedGradebookVersion', (select gradebook_version from public.assessments where id = :'paper_id')))->>'outcome',
  'ok', 'and publishes');
select ok(pg_temp.download(:'student_user', :'shared_file') and pg_temp.download(:'student_user', :'own_file'),
  'the student now opens the question paper and their own sheet');
select ok(not pg_temp.download(:'student_user', :'other_file'), 'never another student''s sheet');
select ok(not pg_temp.download(:'student2_user', :'shared_file'),
  'the second student, whose grade is not published, opens nothing yet');
select ok(pg_temp.download(:'guardian_user', :'own_file') and not pg_temp.download(:'guardian_user', :'other_file'),
  'a parent opens their own child''s sheet only');
select ok(not pg_temp.download(:'guardian2_user', :'own_file'), 'an unrelated parent opens nothing');

-- ---------------------------------------------------------------------------
-- A lesson with files and links, kept through an edit
-- ---------------------------------------------------------------------------

select pg_temp.upload(:'lesson_file', :'teacher_user', 'lesson_resource', :'classroom_id', 'Slides.pdf');
insert into oa select 'lesson', pg_temp.cmd(:'teacher_user', 'createResource', null, jsonb_build_object(
  'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Cells', 'resourceType', 'lesson_note',
  'body', 'Notes', 'audience', 'both', 'attachmentFileIds', jsonb_build_array(:'lesson_file'),
  'links', jsonb_build_array(jsonb_build_object('title', 'Video', 'url', 'https://video.example.org/cells'))));
select is((select jsonb_array_length(value->'response'->'attachments') + jsonb_array_length(value->'response'->'links')
  from oa where name = 'lesson'), 2, 'a lesson carries its file and its link');
select (value->'response'->>'id')::uuid as lesson_id from oa where name = 'lesson' \gset
select is((select jsonb_array_length(pg_temp.cmd(:'teacher_user', 'editResource', :'lesson_id', jsonb_build_object(
  'expectedVersion', (select version from public.resources where id = :'lesson_id'), 'body', 'Edited notes'))
  ->'response'->'attachments')), 1, 'an edit keeps the lesson''s file');

select * from finish();
rollback;
