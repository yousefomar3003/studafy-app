-- What the study helper may read for a student (202609290003): lessons they
-- can see and their own notes - nobody else's - and their own photos.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(6);

insert into public.notebook_entries(school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'student_id', :'student_user', 'My cells note', 'Mitochondria.', 'typed')
returning id as own_note \gset
insert into public.notebook_entries(school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'second_student_id', :'second_student_user', 'Their note', 'Private.', 'typed')
returning id as their_note \gset

select set_config('request.jwt.claim.sub', :'student_user', true);
select set_config('studafy.school_id', :'school_id', true);

create function pg_temp.refs(items jsonb) returns jsonb language sql as $$
  select private.api049_notebooks('references', null, jsonb_build_object('items', items))->'items'
$$;

select is(jsonb_array_length(pg_temp.refs(jsonb_build_array(
    jsonb_build_object('kind', 'note', 'id', :'own_note')))), 1,
  'a student''s own note can be read');
select is(pg_temp.refs(jsonb_build_array(
    jsonb_build_object('kind', 'note', 'id', :'own_note')))->0->>'text', 'Mitochondria.',
  'with its text');
select is(jsonb_array_length(pg_temp.refs(jsonb_build_array(
    jsonb_build_object('kind', 'note', 'id', :'their_note')))), 0,
  'another student''s note is left out');
select is(jsonb_array_length(pg_temp.refs(jsonb_build_array(
    jsonb_build_object('kind', 'lesson', 'id', :'clean_resource_id')))), 1,
  'a published lesson in the student''s class can be read');
select is(jsonb_array_length(pg_temp.refs(jsonb_build_array(
    jsonb_build_object('kind', 'lesson', 'id', gen_random_uuid())))), 0,
  'a lesson that does not exist is left out');
select is(private.api049_notebooks('assistantAttachment', gen_random_uuid(), '{}')->>'outcome',
  'not_found', 'only the student''s own helper photo can be sent');

select * from finish();
rollback;
