-- AI output is made once and reused (202609290005): lesson notes per lesson
-- version, and the note already made from a whiteboard photo.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(11);

create temporary table lesson_version(id uuid);
select set_config('request.jwt.claim.sub', :'student_user', true);
insert into lesson_version
  select (private.study_lesson(:'clean_resource_id')->>'versionId')::uuid;

-- 1. Lesson notes: nothing cached, then only a Plus student can store them.
select ok(private.api049_notebooks('lessonForNotes', :'clean_resource_id', '{}')
  ->> 'outcome' = 'plan_required', 'a free student cannot make lesson notes');
select is(private.lesson_notes_cache_put(:'clean_resource_id',
  (select id from lesson_version), '# Notes', 'model'), false,
  'a free student cannot store notes either');

insert into private.study_plan_grants(user_id, plan, reason, ends_at)
  values (:'student_user', 'plus', 'pgTAP notes cache', now() + interval '1 day');
select is(private.api049_notebooks('lessonForNotes', :'clean_resource_id', '{}')
  ->> 'cachedNotes', null, 'no notes are cached for a new lesson version');
select is(private.lesson_notes_cache_put(:'clean_resource_id',
  gen_random_uuid(), '# Wrong', 'model'), false,
  'notes cannot be stored against another version of the lesson');
select is(private.lesson_notes_cache_put(:'clean_resource_id',
  (select id from lesson_version), '# Notes', 'model'), true,
  'a Plus student stores the notes made for this version');
select is(private.api049_notebooks('lessonForNotes', :'clean_resource_id', '{}')
  ->> 'cachedNotes', '# Notes', 'the next request gets them, no AI needed');
select is(private.lesson_notes_cache_put(:'clean_resource_id',
  (select id from lesson_version), '# Later', 'model'), true,
  'a second store for the same version is accepted but ignored');
select is((select body from private.lesson_notes_cache
  where resource_version_id = (select id from lesson_version)), '# Notes',
  'the first notes for a version are the ones kept');

-- 2. Whiteboard: the note already made from a photo, while it exists.
insert into public.file_objects(id, school_id, bucket, object_key, uploader_id,
  size_bytes, sha256)
values ('00000000-0000-4000-8000-00000000abcd', :'school_id', 'private-school-files',
  'pgtap/whiteboard.jpg', :'student_user', 10, repeat('a', 64));
insert into public.notebook_entries(school_id, classroom_id, student_id, owner_id,
  title, body, source, photo_file_id)
values (:'school_id', :'classroom_id', :'student_id', :'student_user',
  'Board', '# Board', 'whiteboard', '00000000-0000-4000-8000-00000000abcd');
select is(private.api049_notebooks('whiteboardEntry',
  '00000000-0000-4000-8000-00000000abcd', '{}') -> 'entry' ->> 'title', 'Board',
  'the same photo returns the note made from it');
update public.notebook_entries set deleted_at = now()
  where photo_file_id = '00000000-0000-4000-8000-00000000abcd';
select is(private.api049_notebooks('whiteboardEntry',
  '00000000-0000-4000-8000-00000000abcd', '{}') -> 'entry', 'null'::jsonb,
  'a deleted note is not kept for reuse');

-- 3. Only the API may store notes; nobody reads the cache directly.
select ok(not has_function_privilege('authenticated',
    'private.lesson_notes_cache_put(uuid,uuid,text,text)', 'execute')
  and has_function_privilege('studafy_api_runtime',
    'private.lesson_notes_cache_put(uuid,uuid,text,text)', 'execute')
  and not has_table_privilege('studafy_api_runtime', 'private.lesson_notes_cache', 'select'),
  'only the API stores notes, through the checked function');

select * from finish();
rollback;
