begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(30);

\set school_id '11111111-1111-1111-1111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set other_school_user 'eeee0000-0000-4000-8000-000000000005'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'

select is((select count(*) from information_schema.role_table_grants where grantee='studafy_api_runtime'),0::bigint,
  'API-041 leaves the API runtime with zero table grants');
select is((select count(*) from information_schema.column_privileges where grantee='studafy_api_runtime'),0::bigint,
  'API-041 leaves the API runtime with zero column grants');
select is((select count(*) from information_schema.usage_privileges
  where grantee='studafy_api_runtime' and object_type='SEQUENCE'),0::bigint,
  'API-041 leaves the API runtime with zero sequence grants');
select ok(has_function_privilege('studafy_api_runtime','private.api041_query(text,uuid,jsonb)','execute') and
  has_function_privilege('studafy_api_runtime','private.api041_command(text,uuid,jsonb,uuid,bigint)','execute'),
  'runtime can execute only the narrow academic query and command entry points');
select ok(not has_function_privilege('authenticated','private.api041_command(text,uuid,jsonb,uuid,bigint)','execute'),
  'mobile authenticated role cannot invoke the command function directly');

select set_config('request.jwt.claim.sub',:'teacher_user',true);
select set_config('studafy.school_id',:'school_id',true);
select set_config('studafy.request_id','api041-create-assignment',true);
create temporary table api041_results(name text primary key,result jsonb);
insert into api041_results values('create-reservation',private.api_idempotency_reserve(
  :'school_id','v1.createAssignment','api041-create-key-0001',repeat('a',64)));
insert into api041_results values('create',private.api041_command(
  'createAssignment',:'classroom_id',jsonb_build_object('responseStatus',201,'body',jsonb_build_object(
    'classroomId',:'classroom_id','title','Atomic assignment','instructions','Text only',
    'dueAt',(now()+interval '2 days'),'closesAt',(now()+interval '3 days'))),
  ((select result->>'id' from api041_results where name='create-reservation')::uuid),1));

select is((select result->>'outcome' from api041_results where name='create'),'ok','command succeeds through one DB function');
select is((select status from public.idempotency_records where id=((select result->>'id' from api041_results where name='create-reservation')::uuid)),
  'completed','domain mutation and idempotency completion commit together');
select is((select count(*) from public.assignments where title='Atomic assignment'),1::bigint,'one domain row is created');
select is((select count(*) from public.audit_events where request_id='api041-create-assignment'),1::bigint,'one audit row is created');
select is(private.api_idempotency_reserve(:'school_id','v1.createAssignment','api041-create-key-0001',repeat('a',64))->>'outcome',
  'replay','response-loss retry returns the stored response');
select is(private.api_idempotency_reserve(:'school_id','v1.createAssignment','api041-create-key-0001',repeat('b',64))->>'outcome',
  'mismatch','changed payload conflicts for the same key');

select (result->'response'->>'id')::uuid as assignment_id from api041_results where name='create' \gset
select set_config('studafy.request_id','api041-publish-assignment',true);
insert into api041_results values('publish-reservation',private.api_idempotency_reserve(
  :'school_id','v1.publishAssignment','api041-publish-key-01',repeat('c',64)));
insert into api041_results values('publish',private.api041_command(
  'publishAssignment',:'assignment_id',jsonb_build_object('responseStatus',200,'body',jsonb_build_object('expectedVersion',1)),
  ((select result->>'id' from api041_results where name='publish-reservation')::uuid),1));
select is((select result->'response'->>'state' from api041_results where name='publish'),'published','guarded publish transition returns canonical state');
select is((select count(*) from public.notification_outbox where source_event_id=:'assignment_id'),1::bigint,'publication inserts one outbox row');
select is((select count(*) from public.notifications where entity_id=:'assignment_id'),0::bigint,'request never writes notifications directly');

select set_config('studafy.request_id','api041-stale-version',true);
insert into api041_results values('stale-reservation',private.api_idempotency_reserve(
  :'school_id','v1.withdrawAssignment','api041-stale-key-00001',repeat('d',64)));
insert into api041_results values('stale',private.api041_command(
  'withdrawAssignment',:'assignment_id',jsonb_build_object('responseStatus',200,'body',jsonb_build_object('expectedVersion',1)),
  ((select result->>'id' from api041_results where name='stale-reservation')::uuid),1));
select is((select result->>'outcome' from api041_results where name='stale'),'version_conflict','stale optimistic version fails');
select is((select state::text from public.assignments where id=:'assignment_id'),'published','conflict does not mutate the aggregate');

create function pg_temp.reject_api041_audit() returns trigger language plpgsql as $$
begin
  if new.request_id='api041-force-audit' then raise exception 'API041_FORCED_AUDIT'; end if;
  return new;
end $$;
create trigger api041_force_audit before insert on public.audit_events
for each row execute function pg_temp.reject_api041_audit();
select set_config('studafy.request_id','api041-force-audit',true);
insert into api041_results values('audit-reservation',private.api_idempotency_reserve(
  :'school_id','v1.createAssignment','api041-audit-key-0001',repeat('e',64)));
create function pg_temp.api041_audit_failure() returns jsonb language sql as $$
  select private.api041_command('createAssignment','abcd0000-0000-4000-8000-000000000007',
    jsonb_build_object('responseStatus',201,'body',jsonb_build_object(
      'classroomId','abcd0000-0000-4000-8000-000000000007','title','Must roll back audit',
      'instructions',null,'dueAt',(now()+interval '2 days'),'closesAt',(now()+interval '3 days'))),
    ((select result->>'id' from api041_results where name='audit-reservation')::uuid),1)
$$;
select throws_ok('select pg_temp.api041_audit_failure()','API041_FORCED_AUDIT','forced audit failure escapes the command');
select is((select count(*) from public.assignments where title='Must roll back audit'),0::bigint,'audit failure rolls back the domain mutation');
select is((select status from public.idempotency_records where id=((select result->>'id' from api041_results where name='audit-reservation')::uuid)),
  'reserved','audit failure also rolls back idempotency completion');
drop trigger api041_force_audit on public.audit_events;

insert into public.assignments(id,school_id,classroom_id,title,due_at,state,created_by,version)
values('a0410000-0000-4000-8000-000000000041',:'school_id',:'classroom_id','Outbox rollback fixture',now()+interval '2 days','draft',:'teacher_user',1);
create function pg_temp.reject_api041_outbox() returns trigger language plpgsql as $$
begin
  if new.source_event_id='a0410000-0000-4000-8000-000000000041' then raise exception 'API041_FORCED_OUTBOX'; end if;
  return new;
end $$;
create trigger api041_force_outbox before insert on public.notification_outbox
for each row execute function pg_temp.reject_api041_outbox();
select set_config('studafy.request_id','api041-force-outbox',true);
insert into api041_results values('outbox-reservation',private.api_idempotency_reserve(
  :'school_id','v1.publishAssignment','api041-outbox-key-001',repeat('f',64)));
create function pg_temp.api041_outbox_failure() returns jsonb language sql as $$
  select private.api041_command('publishAssignment','a0410000-0000-4000-8000-000000000041',
    '{"responseStatus":200,"body":{"expectedVersion":1}}',
    ((select result->>'id' from api041_results where name='outbox-reservation')::uuid),1)
$$;
select throws_ok('select pg_temp.api041_outbox_failure()','API041_FORCED_OUTBOX','forced outbox failure escapes the command');
select is((select state::text from public.assignments where id='a0410000-0000-4000-8000-000000000041'),'draft','outbox failure rolls back publication');
select is((select count(*) from public.audit_events where request_id='api041-force-outbox'),0::bigint,'outbox failure rolls back the audit row too');

insert into public.assessments(id,school_id,classroom_id,title,category,maximum_score,state,delivery,created_by,version,published_at)
values('a0410000-0000-4000-8000-000000000050',:'school_id',:'classroom_id','Paper parity','quiz',10,'published','paper',:'teacher_user',1,now());
insert into public.assessment_questions(id,school_id,assessment_id,position,prompt,preferred_answer,maximum_score) values
('a0410000-0000-4000-8000-000000000052',:'school_id','a0410000-0000-4000-8000-000000000050',1,'Q1','secret',4),
('a0410000-0000-4000-8000-000000000053',:'school_id','a0410000-0000-4000-8000-000000000050',2,'Q2','secret',6);
insert into public.grade_results(id,school_id,assessment_id,student_id,score,state,version)
values('a0410000-0000-4000-8000-000000000051',:'school_id','a0410000-0000-4000-8000-000000000050','abcf0000-0000-4000-8000-000000000008',null,'draft',1);
select set_config('studafy.request_id','api041-grade-review',true);
insert into api041_results values('review-reservation',private.api_idempotency_reserve(
  :'school_id','v1.reviewGradeResult','api041-review-key-001',repeat('7',64)));
insert into api041_results values('review',private.api041_command(
  'reviewGradeResult','a0410000-0000-4000-8000-000000000051',jsonb_build_object('responseStatus',200,'body',jsonb_build_object(
    'expectedVersion',1,'score',8,'feedback',null)),
  ((select result->>'id' from api041_results where name='review-reservation')::uuid),1));
select is((select result->'response'->>'state' from api041_results where name='review'),'reviewed','paper review reaches reviewed state transactionally');
select is((select score from public.grade_results where id='a0410000-0000-4000-8000-000000000051'),8::numeric,'review score is bounded and stored');
select is((select count(*) from public.grade_result_events where grade_result_id='a0410000-0000-4000-8000-000000000051' and event_type='reviewed'),1::bigint,'grade review writes immutable history');
select set_config('studafy.request_id','api041-grade-publish',true);
insert into api041_results values('grade-publish-reservation',private.api_idempotency_reserve(
  :'school_id','v1.publishGradeResult','api041-grade-pub-key1',repeat('8',64)));
insert into api041_results values('grade-publish',private.api041_command(
  'publishGradeResult','a0410000-0000-4000-8000-000000000051','{"responseStatus":200,"body":{"expectedVersion":2}}',
  ((select result->>'id' from api041_results where name='grade-publish-reservation')::uuid),1));
select is((select result->'response'->>'state' from api041_results where name='grade-publish'),'published','reviewed grade publishes through the replacement command');
select is((select count(*) from public.notification_outbox where source_event_id='a0410000-0000-4000-8000-000000000051'),1::bigint,'grade publish emits exactly one outbox row');
select is((select count(*) from public.notifications where entity_id='a0410000-0000-4000-8000-000000000051'),0::bigint,'grade publish does not call notification storage directly');

select set_config('request.jwt.claim.sub',:'other_school_user',true);
select set_config('studafy.school_id','22222222-2222-2222-2222-222222222222',true);
select is(private.api041_query('getClassroom',:'classroom_id','{}')->>'outcome','not_found','cross-school context is concealed by the query surface');

select set_config('request.jwt.claim.sub',:'student_user',true);
select set_config('studafy.school_id',:'school_id',true);
select set_config('studafy.request_id','api041-answer-safety',true);
select ok(not (private.api041_query('listAssessmentQuestions','abd00000-0000-4000-8000-000000000009',
  '{"pageSize":50}'::jsonb)::text like '%preferred%'),'learner question response never includes preferred answers');

select * from finish();
rollback;
