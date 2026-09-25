-- AI-072 (ADR-0026): the AI surface is removed, not disabled. Every retired
-- relation is unreadable and unwritable, the draft-approval grading branch is
-- unreachable, the Study Coach upload purpose is refused, and neither AI
-- store product can be offered or re-activated.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(20);

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set student_id 'abcf0000-0000-4000-8000-000000000008'

-- 1. Retired relations: no grant, no policy, for any client or service role.
select is((select count(*) from information_schema.role_table_grants
  where table_schema='public'
    and table_name in ('ai_grading_drafts','question_suggestions','practice_sessions')
    and grantee in ('anon','authenticated','service_role','studafy_api_runtime')),
  0::bigint, 'retired AI relations grant nothing to anon, authenticated, service_role or the API runtime');
select is((select count(*) from information_schema.column_privileges
  where table_schema='public'
    and table_name in ('ai_grading_drafts','question_suggestions','practice_sessions')
    and grantee in ('anon','authenticated','service_role','studafy_api_runtime')),
  0::bigint, 'retired AI relations keep no column-level grant either');
select is((select count(*) from pg_policies where schemaname='public'
  and tablename in ('ai_grading_drafts','question_suggestions','practice_sessions')),
  0::bigint, 'retired AI relations have no RLS policy left to widen');

-- Cross-tenant and same-tenant readers are both refused before RLS runs.
set local role authenticated;
select set_config('request.jwt.claim.sub',:'other_school_user',true);
select throws_ok($$ select id, status from public.ai_grading_drafts $$, '42501', null,
  'a teacher from another school cannot read grading drafts');
select set_config('request.jwt.claim.sub',:'student_user',true);
select throws_ok($$ select id, topic from public.practice_sessions $$, '42501', null,
  'a student can no longer read Study Coach practice sessions');
reset role;
set local role service_role;
select throws_ok($$ select id, proposed_score from public.question_suggestions $$, '42501', null,
  'service role cannot read AI suggestions - no Edge Function may sign or send them');
reset role;

-- 2. Unwritable even for the table owner and SECURITY DEFINER code paths.
insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by,version,published_at)
values('a0720000-0000-4000-8000-000000000050',:'school_id',:'classroom_id','AI-072 paper','quiz',10,'published','paper',:'teacher_user',1,now());
insert into public.assessment_questions(id,school_id,assessment_id,position,prompt,preferred_answer,maximum_score) values
('a0720000-0000-4000-8000-000000000052',:'school_id','a0720000-0000-4000-8000-000000000050',1,'Q1','secret',10);
insert into public.grade_results(id,school_id,assessment_id,student_id,score,state,version)
values('a0720000-0000-4000-8000-000000000051',:'school_id','a0720000-0000-4000-8000-000000000050',:'student_id',null,'draft',1);

select throws_like($$
  insert into public.ai_grading_drafts(id,school_id,grade_result_id,private_scan_path,strictness,model_version,status,created_by,version)
  values('a0720000-0000-4000-8000-000000000054','11111111-1111-4111-8111-111111111111','a0720000-0000-4000-8000-000000000051',
    'papers/another-user/private.pdf','balanced','fixture','ready','aaaa0000-0000-4000-8000-000000000001',1)
$$, '%ai072_retired%', 'no grading draft can be created, even with a substituted private path');
select throws_like($$
  insert into public.practice_sessions(student_id,classroom_id,topic,kind,item_count,school_id)
  values('abcf0000-0000-4000-8000-000000000008','abcd0000-0000-4000-8000-000000000007','any','quiz',1,
    '11111111-1111-4111-8111-111111111111')
$$, '%ai072_retired%', 'no practice session can be recorded');

-- 3. The API-041 draft branch is unreachable: a review naming any draft is
--    refused and the grade is untouched. (The /v1 contract also rejects
--    draftId outright; this proves the database agrees.)
select set_config('request.jwt.claim.sub',:'teacher_user',true);
select set_config('studafy.school_id',:'school_id',true);
select set_config('studafy.request_id','ai072-draft-review',true);
create temporary table ai072_results(name text primary key,result jsonb);
insert into ai072_results values('reservation',private.api_idempotency_reserve(
  :'school_id','v1.reviewGradeResult','ai072-review-key-0001',repeat('9',64)));
insert into ai072_results values('review',private.api041_command(
  'reviewGradeResult','a0720000-0000-4000-8000-000000000051',jsonb_build_object('responseStatus',200,'body',jsonb_build_object(
    'expectedVersion',1,'score',10,'feedback',null,'draftId','a0720000-0000-4000-8000-000000000054','questionScores',jsonb_build_array(
      jsonb_build_object('questionId','a0720000-0000-4000-8000-000000000052','score',10,'reason',null)))),
  ((select result->>'id' from ai072_results where name='reservation')::uuid),1));
select is((select result->>'outcome' from ai072_results where name='review'),'invalid_state',
  'a review naming an AI draft is refused');
select is((select state::text||':'||coalesce(score::text,'null')||':'||version
  from public.grade_results where id='a0720000-0000-4000-8000-000000000051'),'draft:null:1',
  'the refused AI-draft review leaves the grade unchanged');

-- 4. The Study Coach upload purpose is retired at both layers.
select is((select enabled from public.file_purpose_policies where purpose='coach_attachment'),false,
  'coach_attachment upload policy is disabled');
select throws_like($$ update public.file_purpose_policies set enabled=true where purpose='coach_attachment' $$,
  '%ai072_coach_attachment_retired%', 'coach_attachment cannot be re-enabled by a data change');
select set_config('request.jwt.claim.sub',:'student_user',true);
select is(private.api050_prepare_intent(jsonb_build_object(
    'schoolId',:'school_id','purpose','coach_attachment','displayName','notes.pdf',
    'expectedSizeBytes',1024,'declaredMediaType','application/pdf','sha256',repeat('a',64),
    'studentId',:'student_id'))->>'outcome','invalid',
  'an authorized student asking for a coach_attachment upload is refused');
select throws_like($$
  insert into public.upload_sessions(school_id,uploader_id,purpose,expected_size_bytes,allowed_media_types,nonce_hash,expires_at,student_id)
  values('11111111-1111-4111-8111-111111111111','bbbb0000-0000-4000-8000-000000000002','coach_attachment',1024,
    array['application/pdf'],repeat('b',64),now()+interval '1 hour','abcf0000-0000-4000-8000-000000000008')
$$, '%ai072_coach_attachment_retired%', 'no upload session can carry the retired purpose');
-- The enabled set by name rather than by count: the point is that AI-072
-- retired exactly one purpose and disturbed no other, which a bare number
-- stops proving the moment a new upload purpose is added.
select set_eq(
  $$ select purpose::text from public.file_purpose_policies where enabled $$,
  $$ values ('profile_image'),('lesson_resource'),('assignment_material'),
            ('assignment_submission'),('paper_scan'),
            ('message_attachment'),('announcement_attachment') $$,
  'every non-AI upload purpose stays enabled and coach_attachment does not');

-- 5. Neither AI product can be offered or re-activated.
select is((select count(*) from public.store_products
  where feature_key in ('student_ai','teacher_ai_grading') and (active or storefront_listed)),0::bigint,
  'no AI store product is active or listed in any environment');
select ok(not exists(select 1 from unnest(array['synthetic','development','staging','production']) env
  cross join lateral jsonb_array_elements(private.billing_catalogue(env)) item
  where item->>'featureKey' in ('student_ai','teacher_ai_grading')),
  'no environment catalogue offers an AI product');
select throws_like($$ update public.store_products set active=true, storefront_listed=true
  where feature_key='student_ai' $$, '%ai072_ai_products_retired%',
  'an AI product cannot be re-activated by a data change');
select throws_like($$ insert into public.store_products(feature_key,platform,environment,store_product_id,active,storefront_listed)
  values('teacher_ai_grading','app_store','production','studafy_teacher_ai_grading_monthly',true,true) $$,
  '%ai072_ai_products_retired%', 'a new AI product cannot be listed');
select ok((select count(*) from public.store_products where feature_key='student_notebook' and active)>0,
  'non-AI products stay active');

select * from finish();
rollback;
