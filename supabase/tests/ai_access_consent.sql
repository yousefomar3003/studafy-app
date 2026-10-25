-- AI study tools: student accounts only - in a class or not since
-- 202610210030 (ADR-0045) - and a separate AI consent that a managed child's
-- parent gives (202610150060, ADR-0043).
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(42);

\set child 'f00d0000-0000-4000-8000-0000000000e1'
\set loner 'f00d0000-0000-4000-8000-0000000000e2'
\set lesson 'f00d0000-0000-4000-8000-0000000000e3'
\set lesson_v1 'f00d0000-0000-4000-8000-0000000000e4'

create function pg_temp.as_user(u uuid, op text, input jsonb default '{}')
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  return private.api057_ai_consent(op, input);
end $$;

create function pg_temp.access(u uuid)
returns text language sql as $$
  select pg_temp.as_user(u, 'status') ->> 'access'
$$;

create function pg_temp.reserve(u uuid)
returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u::text, true);
  return private.api047_ai_usage('reserve', jsonb_build_object(
    'feature', 'ask', 'estimateMicroUsd', 10, 'estimateTokens', 100)) ->> 'outcome';
end $$;

create function pg_temp.give(u uuid, version text default '2026-10-25')
returns text language sql as $$
  select pg_temp.as_user(u, 'give', jsonb_build_object(
    'version', version, 'locale', 'en')) ->> 'outcome'
$$;

-- A student account with no class yet, and a managed child (ADR-0031).
insert into auth.users (id, email, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
values
  (:'loner', 'ai.loner@synthetic.studafy.test', 'authenticated',
   'authenticated', now(), now(), now(),
   '00000000-0000-0000-0000-000000000000', '{}', '{"full_name":"Lone Student"}'),
  (:'child', 'child-e1@managed.studafy.invalid', 'authenticated',
   'authenticated', now(), now(), now(),
   '00000000-0000-0000-0000-000000000000',
   jsonb_build_object('studafy_managed_by', :'guardian_user'),
   '{"full_name":"Layla"}');
update public.profiles set account_kind = 'student' where id = :'loner';
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.api048_managed_accounts('register', jsonb_build_object(
  'childId', :'child', 'policyVersion', '2026-10-14', 'locale', 'en')) ->> 'outcome',
  'ok', 'fixture: the parent registers a managed child account');
insert into public.students (school_id, studafy_id, display_name, created_by, user_id)
values (:'school_id', 'STU-AI-CHILD', 'Layla Khalil', :'child', :'child');
insert into public.enrollments (classroom_id, student_id, active)
select :'classroom_id', st.id, true from public.students st where st.user_id = :'child';

-- 1. Who may use the AI study tools at all.
select is(private.ai_consent_version(), '2026-10-25',
  'the current AI notice is version 2026-10-25');
select is(pg_temp.access(:'teacher_user'), 'not_student', 'a teacher may not');
select is(pg_temp.access(:'guardian_user'), 'not_student', 'a parent may not');
select is(pg_temp.access(:'loner'), 'consent_required',
  'a student with no class may too, once they consent (ADR-0045)');
select is(pg_temp.access(:'student_user'), 'consent_required',
  'a student in a class may, once they consent');
select is(pg_temp.access(:'child'), 'guardian_consent_required',
  'a managed child may, once their parent consents');

-- 2. Nothing is held, so nothing reaches the provider, without both.
select is(pg_temp.reserve(:'teacher_user'), 'not_student',
  'the ledger refuses a teacher');
select is(pg_temp.reserve(:'guardian_user'), 'not_student',
  'the ledger refuses a parent');
select is(pg_temp.reserve(:'loner'), 'consent_required',
  'the ledger refuses a student with no class who has not consented');
select is(pg_temp.reserve(:'student_user'), 'consent_required',
  'the ledger refuses a student who has not consented');
select is((select count(*) from private.ai_usage
  where user_id in (:'teacher_user', :'guardian_user', :'loner', :'student_user')),
  0::bigint, 'and none of those refusals held a token');

-- 3. A student consents to the notice the app showed.
select is(pg_temp.give(:'student_user', '2026-01-01'), 'stale_version',
  'consent to a notice that is not the current one is refused');
select is(pg_temp.give(:'teacher_user'), 'not_student',
  'a teacher cannot consent to tools they cannot use');
select is(pg_temp.give(:'student_user'), 'ok', 'the student consents');
select is(pg_temp.access(:'student_user'), 'ok', 'and may now use the tools');
select results_eq(
  $$select given_by, given_as, policy_id is not null, withdrawn_at is null
    from public.consent_records
    where user_id = 'bbbb0000-0000-4000-8000-000000000002'
      and purpose = 'ai_features'$$,
  $$values ('bbbb0000-0000-4000-8000-000000000002'::uuid, 'self'::text, true, true)$$,
  'the record says who consented, as whom, to which published notice');
select is(pg_temp.reserve(:'student_user'), 'ok',
  'the ledger now holds tokens for them');
select set_config('request.jwt.claim.sub', :'student_user', true);
select is(private.api047_ai_usage('summary', '{}') ->> 'access', 'ok',
  'the plan summary tells the app the student may use the tools');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is(private.api047_ai_usage('summary', '{}') ->> 'access', 'not_student',
  'and tells a parent they may not');

-- 4. Not through the public consent RPC: it knows nothing about parents.
select set_config('request.jwt.claim.sub', :'child', true);
select throws_ok(
  $$select public.record_policy_consent('ai_features', '2026-10-25', 'en')$$,
  '22023', 'Unsupported consent purpose',
  'the AI consent cannot be recorded through record_policy_consent');
select set_config('request.jwt.claim.sub', :'student_user', true);
select lives_ok(
  $$select public.record_policy_consent('terms_and_privacy', '2026-10-14', 'en')$$,
  'the terms still can');

-- 5. Withdrawing turns the tools off, and is kept.
select is(pg_temp.as_user(:'student_user', 'withdraw') ->> 'access',
  'consent_required', 'the student withdraws, and the tools are off');
select is(pg_temp.reserve(:'student_user'), 'consent_required',
  'the ledger refuses them again');
select is((select withdrawn_by from public.consent_records
  where user_id = :'student_user' and purpose = 'ai_features'),
  :'student_user'::uuid, 'the record says who withdrew it');
select is(pg_temp.give(:'student_user'), 'ok', 'the student consents again');
select is((select array_agg(reason_code order by id)
  from public.auth_security_events
  where actor_id = :'student_user' and event_type = 'consent_recorded'),
  array['ai_features_given', 'ai_features_withdrawn', 'ai_features_given'],
  'every consent and withdrawal is in the security log, in order');

-- 6. A managed child: the parent consents, and either may withdraw.
select is(pg_temp.give(:'child'), 'guardian_consent_required',
  'a managed child cannot consent for themselves');
select is(pg_temp.as_user(:'teacher_user', 'child_give', jsonb_build_object(
  'childId', :'child', 'version', '2026-10-25', 'locale', 'en')) ->> 'outcome',
  'not_found', 'nobody but the managing parent can consent for the child');
select is(pg_temp.as_user(:'child', 'child_status', jsonb_build_object(
  'childId', :'child')) ->> 'outcome', 'not_found',
  'a managed account manages nobody');
select is(pg_temp.as_user(:'guardian_user', 'child_give', jsonb_build_object(
  'childId', :'child', 'version', '2026-10-25', 'locale', 'ar')) ->> 'access',
  'ok', 'the managing parent consents for the child');
select results_eq(
  $$select given_by, given_as, locale from public.consent_records
    where user_id = 'f00d0000-0000-4000-8000-0000000000e1'
      and purpose = 'ai_features'$$,
  $$values ('cccc0000-0000-4000-8000-000000000003'::uuid, 'guardian'::text, 'ar'::text)$$,
  'the child''s record says the parent gave it, in the language shown');
select is(pg_temp.access(:'child'), 'ok', 'and the child may use the tools');
select is(pg_temp.as_user(:'child', 'withdraw') ->> 'access',
  'guardian_consent_required', 'the child can turn the tools off themselves');
select is(pg_temp.as_user(:'guardian_user', 'child_status', jsonb_build_object(
  'childId', :'child')) ->> 'access', 'guardian_consent_required',
  'and the parent sees that');

-- 7. The names the API replaces before any model call.
select set_config('request.jwt.claim.sub', :'student_user', true);
select ok((select array_agg(n ->> 'kind' || ':' || (n ->> 'name'))
  from jsonb_array_elements(pg_temp.as_user(:'student_user', 'names') -> 'names') n)
  @> array['classmate:Layla', 'classmate:Layla Khalil', 'parent:Seed Guardian',
    'parent:Seed Unverified Guardian', 'self:Seed Student', 'teacher:Seed Teacher'],
  'a student''s own name, their classmates'', teachers'' and parents''');
select ok(not (pg_temp.as_user(:'student_user', 'names')::text
    like '%Other School%'),
  'and nobody from a class they are not in');

-- 8. Study sets from a lesson: the SQL catalogue says students only too.
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
values (:'lesson', :'school_id', 'Cells', 'lesson_note', 'published', 1, :'teacher_user');
insert into public.resource_versions (id, school_id, resource_id, version, body, created_by)
values (:'lesson_v1', :'school_id', :'lesson', 1, 'The cell is the unit of life.', :'teacher_user');
insert into public.resource_publications (school_id, resource_version_id, classroom_id,
  audience, state, published_at, created_by)
values (:'school_id', :'lesson_v1', :'classroom_id', 'both', 'published', now(), :'teacher_user');
select set_config('request.jwt.claim.sub', :'student_user', true);
select is((private.authz_notebook('study_set.generate', :'lesson') ->> 'allowed')::boolean,
  true, 'a student in the class may make a study set from the lesson');
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is((private.authz_notebook('study_set.generate', :'lesson') ->> 'allowed')::boolean,
  false, 'the teacher who can see the lesson may not');
select set_config('request.jwt.claim.sub', :'guardian_user', true);
select is((private.authz_notebook('study_set.generate', :'lesson') ->> 'allowed')::boolean,
  false, 'nor may a parent who can see it');

-- 9. The export carries the consent; the deletion screen counts it.
select ok(exists (
  select 1 from jsonb_array_elements(
    private.data_export_document(:'student_user') -> 'sections' -> 'consents') c
  where c ->> 'purpose' = 'ai_features' and c ->> 'policyVersion' = '2026-10-25'),
  'the AI consent is in the student''s data export');
select set_config('request.jwt.claim.sub', :'student_user', true);
select is((private.auth_deletion_impact() -> 'deleted_personal_data' ->> 'consents')::int,
  2, 'the deletion screen counts it with the terms consent');

select * from finish();
rollback;
