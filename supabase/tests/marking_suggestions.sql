-- AI-suggested marks against the teacher's reference (202610210060,
-- ADR-0046): references are the class teacher's, versioned, editable after
-- students answered; suggestions are drafts only - nothing here writes a
-- mark; the plan gates requests; students may opt out; nobody but the
-- class's teachers reads any of it.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(42);
update private.notebook_runtime set environment='synthetic';
select set_config('studafy.request_id', 'marking-test', true);

\set online 'ab900000-0000-4000-8000-000000000001'
\set essay 'ab900000-0000-4000-8000-000000000002'
\set choice 'ab900000-0000-4000-8000-000000000003'
\set attempt 'ab900000-0000-4000-8000-000000000004'
\set assignment 'ab900000-0000-4000-8000-000000000005'
\set paper 'ab900000-0000-4000-8000-000000000006'
\set submission 'ab900000-0000-4000-8000-000000000007'
\set hand_in 'ab900000-0000-4000-8000-000000000008'
\set other_q 'ab900000-0000-4000-8000-000000000009'

-- An online assessment: an essay (5 marks) and a choice question (1 mark),
-- answered by the seed student.
insert into public.assessments (id, school_id, classroom_id, title, category,
  maximum_score, state, delivery, created_by, published_at)
values (:'online', :'school_id', :'classroom_id', 'Photosynthesis check', 'quiz',
  6, 'published', 'online', :'teacher_user', now());
insert into public.assessment_questions (id, school_id, assessment_id, position,
  prompt, maximum_score, kind, preferred_answer, options, answer_key)
values
  (:'essay', :'school_id', :'online', 1, 'Explain photosynthesis.', 5, 'essay',
    'Plants turn light, water and carbon dioxide into glucose and oxygen.', '[]', null),
  (:'choice', :'school_id', :'online', 2, 'Which gas is released?', 1, 'single_choice',
    null, '[{"id":"a","text":"Oxygen"},{"id":"b","text":"Nitrogen"}]', '["a"]');
insert into public.assessment_attempts (id, school_id, assessment_id, student_id,
  operation_id, submitted_at)
values (:'attempt', :'school_id', :'online', :'student_id', gen_random_uuid(), now());
insert into public.assessment_answers (school_id, attempt_id, question_id, answer_text,
  selected, auto_score, awarded_score)
values
  (:'school_id', :'attempt', :'essay', 'Plants use sunlight to make sugar and give off oxygen.', null, null, null),
  (:'school_id', :'attempt', :'choice', '', '["a"]', 1, 1);
-- A question of another assessment, for the wrong-question check.
insert into public.assessment_questions (id, school_id, assessment_id, position,
  prompt, maximum_score, kind)
values (:'other_q', :'school_id', :'published_assessment_id', 99, 'Other', 2, 'essay');

create function pg_temp.cmd(actor uuid, op text, res uuid, body jsonb)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(null, 'marking', gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api059_command(op, res, jsonb_build_object('body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.q(actor uuid, op text, res uuid)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api059_query(op, res, '{}');
end $$;

-- 1. References: the class teacher's, validated, versioned.
select is(pg_temp.cmd(:'teacher_user', 'setReferences', :'online', jsonb_build_object(
    'strictness', 'strict',
    'references', jsonb_build_array(jsonb_build_object('questionId', :'essay',
      'keyPoints', '[{"text":"light energy is used","marks":2},{"text":"glucose and oxygen are made","marks":3}]'::jsonb,
      'acceptedMethods', 'A word equation is enough.',
      'partialCredit', 'One mark per correct product.'))))
    -> 'response' -> 'settings' ->> 'referenceVersion',
  '2', 'the teacher writes key points and strictness; the reference version moves on');
select is(pg_temp.q(:'teacher_user', 'references', :'online') -> 'references' -> 0 -> 'keyPoints' -> 1 ->> 'text',
  'glucose and oxygen are made', 'and reads them back against the right question');
select is(pg_temp.cmd(:'teacher_user', 'setReferences', :'online', jsonb_build_object(
    'references', jsonb_build_array(jsonb_build_object('questionId', :'essay',
      'keyPoints', '[{"text":"too many","marks":9}]'::jsonb))))->>'outcome',
  'invalid', 'key-point marks may not add up to more than the question is worth');
select is(pg_temp.cmd(:'teacher_user', 'setReferences', :'online', jsonb_build_object(
    'references', jsonb_build_array(jsonb_build_object('questionId', :'other_q',
      'acceptedMethods', 'x'))))->>'outcome',
  'invalid', 'a question from another assessment is refused');
select is(pg_temp.cmd(:'teacher_user', 'setReferences', :'online', jsonb_build_object(
    'strictness', 'strict'))->'response'->'settings'->>'referenceVersion',
  '2', 'saving the same thing again does not move the version');
select is(pg_temp.cmd(:'student_user', 'setReferences', :'online', '{}')->>'outcome',
  'not_found', 'a student cannot write references');
select is(pg_temp.q(:'student_user', 'references', :'online')->>'outcome',
  'not_found', 'nor read them');
select is(pg_temp.q(:'guardian_user', 'suggestions', :'online')->>'outcome',
  'not_found', 'a parent reads no suggestions');

-- 2. Asking for suggestions: the plan, then only written answers.
select is(pg_temp.cmd(:'teacher_user', 'requestSuggestions', :'online', '{}')->>'outcome',
  'plan_required', 'without Studafy AI Marking nothing is asked');
insert into private.marking_plan_grants(user_id, reason, ends_at)
  values (:'teacher_user', 'pgTAP marking', now() + interval '1 day');
select is(pg_temp.q(:'teacher_user', 'plan', null)->>'active', 'true', 'the grant is the plan');
select is(pg_temp.cmd(:'teacher_user', 'requestSuggestions', :'online', '{}')->'response'->>'queued',
  '1', 'one suggestion is queued: the essay, not the choice question its key marks');
select is((select reference_version from private.marking_runs where assessment_id = :'online'),
  2, 'the run records the reference version it used');
select ok((select reference_snapshot -> 0 -> 'keyPoints' is not null from private.marking_runs
  where assessment_id = :'online'), 'and a snapshot of the references');

-- 3. The worker: a claim carries the reference, the answer and the names.
create temp table claimed as select private.marking_jobs_claim('w1', 5) as jobs;
select is((select jsonb_array_length(jobs) from claimed), 1, 'the worker claims the job');
select is((select jobs->0->'question'->>'questionId' from claimed), :'essay',
  'with its question''s reference');
select is((select jobs->0->>'answerText' from claimed),
  'Plants use sunlight to make sugar and give off oxygen.', 'and the student''s answer');
select ok((select exists (select 1 from jsonb_array_elements(jobs->0->'names') n
    where n->>'kind' = 'self') from claimed), 'and the names to keep out');
select is(private.marking_job_usage('w1', (select (jobs->0->>'id')::uuid from claimed),
    1, 'reserve', '{"estimateTokens": 5000000}')->>'outcome',
  'allowance_exhausted', 'a call past the month''s allowance is refused');
select is(private.marking_job_usage('w1', (select (jobs->0->>'id')::uuid from claimed),
    1, 'reserve', '{"estimateTokens": 3000, "estimateMicroUsd": 500}')->>'outcome',
  'ok', 'a normal call holds tokens');
select is(private.marking_job_finish('w1', (select (jobs->0->>'id')::uuid from claimed),
    1, 'ready', '{"suggestedScore": 6}')->>'outcome',
  'invalid', 'a suggestion above the question''s maximum is refused');
select is(private.marking_job_finish('w2', (select (jobs->0->>'id')::uuid from claimed),
    1, 'ready', '{"suggestedScore": 4}')->>'outcome',
  'lease_lost', 'only the worker holding the job finishes it');
select is(private.marking_job_finish('w1', (select (jobs->0->>'id')::uuid from claimed),
    1, 'ready', '{"suggestedScore": 4, "met": ["light energy is used"], "missed": [], "rationale": "r", "feedback": "f"}')->>'outcome',
  'ok', 'the worker files a suggestion');

-- 4. A suggestion is a draft: no mark changes.
select is((select awarded_score from public.assessment_answers
  where attempt_id = :'attempt' and question_id = :'essay'), null,
  'the answer''s mark is untouched');
select is((select count(*) from public.grade_results where assessment_id = :'online'),
  0::bigint, 'no grade was made');
select is(pg_temp.q(:'teacher_user', 'suggestions', :'online')->'items'->0->>'suggestedScore',
  '4', 'the teacher reads the suggestion');

-- 5. A changed reference: nothing is re-marked; the teacher is told.
select is(pg_temp.cmd(:'teacher_user', 'setReferences', :'online', jsonb_build_object(
    'references', jsonb_build_array(jsonb_build_object('questionId', :'essay',
      'partialCredit', 'Two marks for each product.'))))->'response'->>'staleSuggestions',
  '1', 'one suggestion was made against an older reference');
select is(pg_temp.q(:'teacher_user', 'suggestions', :'online')->'items'->0->>'stale',
  'true', 'and it is marked as such, not re-run');

-- 6. A student opts out: their work is not sent.
update public.profiles set account_kind = 'student' where id = :'student_user';
select is(pg_temp.cmd(:'student_user', 'setPreference', null, '{"optedOut": true}')->'response'->>'optedOut',
  'true', 'the student opts out');
select is(pg_temp.cmd(:'teacher_user', 'requestSuggestions', :'online', '{"scope":"all"}')->'response'->>'optedOut',
  '1', 'a new run skips them');
select is((select jsonb_array_length(private.marking_jobs_claim('w1', 5))), 0,
  'and the worker is given nothing of theirs');
select is(pg_temp.cmd(:'teacher_user', 'setPreference', null, '{"optedOut": true}')->>'outcome',
  'forbidden', 'a teacher has nothing to opt out');

-- 7. A hand-in: the assignment's linked assessment.
insert into public.assignments (id, school_id, classroom_id, title, instructions,
  due_at, created_by, state, published_at)
values (:'assignment', :'school_id', :'classroom_id', 'Lab report', 'Write up the lab.',
  now() + interval '1 day', :'teacher_user', 'published', now());
insert into public.assessments (id, school_id, classroom_id, title, category,
  maximum_score, state, delivery, created_by, assignment_id, published_at)
values (:'paper', :'school_id', :'classroom_id', 'Lab report', 'homework', 10,
  'published', 'paper', :'teacher_user', :'assignment', now());
insert into public.submissions (id, school_id, assignment_id, student_id, status)
values (:'submission', :'school_id', :'assignment', :'student_id', 'submitted');
insert into public.submission_attempts (id, school_id, submission_id, operation_id,
  answer_text, submitted_at)
values (:'hand_in', :'school_id', :'submission', gen_random_uuid(), 'My lab report.', now());
update public.submissions set current_attempt_id = :'hand_in' where id = :'submission';
select is(pg_temp.cmd(:'student_user', 'setPreference', null, '{"optedOut": false}')->'response'->>'optedOut',
  'false', 'the student opts back in');
select is(pg_temp.cmd(:'teacher_user', 'requestSuggestions', :'paper', '{}')->'response'->>'queued',
  '1', 'a hand-in is queued against the assignment''s reference');

-- 8. Billing: a teacher buys it for themselves; a student cannot.
select is(private.billing_resolve_beneficiary(:'teacher_user', 'studafy_ai_marking', null, false)->>'beneficiaryId',
  :'teacher_user', 'a teacher buys Studafy AI Marking for themselves');
select is(private.billing_resolve_beneficiary(:'student_user', 'studafy_ai_marking', null, false)->>'outcome',
  'not_eligible', 'a student cannot');

-- 9. Export, retention and deletion.
select is(private.data_export_document(:'student_user')->'sections'->'aiMarking'->>'optedOut',
  'false', 'the export says whether the student opted out');
select ok(private.data_export_document(:'teacher_user')->'sections'->'aiMarking'->'usage' is not null
    and private.data_export_document(:'teacher_user')->'sections'->'profile' is not null,
  'the export keeps every earlier section and adds the teacher''s usage');
select is((select count(*)::int from public.store_products
    where feature_key = 'studafy_ai_marking' and environment in ('staging', 'production')
      and storefront_listed), 0, 'not listed for sale in staging or production yet');
update private.marking_suggestions set status = 'ready', updated_at = now() - interval '181 days'
  where assessment_id = :'paper';
select ok((private.marking_purge_expired()->>'suggestions')::int >= 1,
  'suggestions older than 180 days are purged');
select is((select count(*)::int from private.marking_suggestions where assessment_id = :'paper'),
  0, 'and are gone');
select is(pg_temp.cmd(:'teacher_user', 'requestSuggestions', :'paper', '{"scope": "all"}')->'response'->>'queued',
  '1', 'the hand-in is queued again');
update public.profiles set status = 'deleted' where id = :'student_user';
select is((select count(*)::int from private.marking_suggestions
    where student_id = :'student_id'), 0,
  'a deleted student takes every suggestion about their work with them');

select * from finish();
rollback;
