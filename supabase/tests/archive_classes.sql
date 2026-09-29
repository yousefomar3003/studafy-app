-- A teacher deletes (archives) a class; students' notebooks outlive it
-- (202609290001). Transactional fixtures: leaves local data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(9);

select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'archive-test', true);

-- The student's note in the class, written before it is deleted.
insert into public.notebook_entries(school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'student_id', :'student_user', 'Cells', 'Mitochondria.', 'typed');

create function pg_temp.archive(actor uuid, version bigint) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(current_setting('studafy.school_id')::uuid,
    'archiveClassroom', gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api041_command('archiveClassroom',
    'abcd0000-0000-4000-8000-000000000007',
    jsonb_build_object('body', jsonb_build_object('expectedVersion', version)),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;

select is(pg_temp.archive(:'student_user',
    (select version from public.classrooms where id = :'classroom_id'))->>'outcome',
  'forbidden', 'a student cannot delete the class');
select is(pg_temp.archive(:'teacher_user', 999)->>'outcome', 'version_conflict',
  'a stale version is refused');
select is(pg_temp.archive(:'teacher_user',
    (select version from public.classrooms where id = :'classroom_id'))->>'outcome',
  'ok', 'its teacher deletes the class');
select is((select status::text from public.classrooms where id = :'classroom_id'),
  'archived', 'the class is archived, not removed');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select ok(not exists (select 1 from jsonb_array_elements(
    private.api041_query('listClassrooms', :'school_id', '{}')->'items') i
  where i->>'id' = :'classroom_id'), 'it leaves the class list');

select set_config('request.jwt.claim.sub', :'student_user', true);
select is((private.api049_notebooks('myNotebooks', null, '{}')->'classes'->0->>'archived'),
  'true', 'the student still has its notebook, marked as a class that is gone');
select is(jsonb_array_length(private.api049_notebooks('myNotebooks', null, '{}')
  ->'classes'->0->'entries'), 1, 'with every note in it');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(jsonb_array_length(private.api049_notebooks('myNotebooks', null, '{}')->'classes'),
  0, 'nobody else sees a student''s notebook');
select is(pg_temp.archive(:'teacher_user',
    (select version from public.classrooms where id = :'classroom_id'))->>'outcome',
  'invalid_state', 'a deleted class cannot be deleted again');

select * from finish();
rollback;
