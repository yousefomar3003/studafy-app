-- Students without a class (202610210030, ADR-0045): a personal notebook
-- that belongs to no class and only its owner sees, editing one's own notes,
-- and practice from them on Studafy Max.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(29);

\set loner 'f00d0000-0000-4000-8000-0000000000f1'

select set_config('studafy.request_id', 'independent-students-test', true);

-- A student who signed up and joined no class.
insert into auth.users (id, email, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
values (:'loner', 'indep.loner@synthetic.studafy.test', 'authenticated',
  'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '{}', '{"full_name":"Lone Student"}');
update public.profiles set account_kind = 'student' where id = :'loner';

create function pg_temp.command(actor uuid, op text, entry uuid, body jsonb)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(null, 'personalNotebook',
    gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api058_command(op, entry, jsonb_build_object('body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;

create function pg_temp.query(actor uuid, op text, input jsonb default '{}')
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api058_query(op, input);
end $$;

create function pg_temp.mine(actor uuid) returns integer language sql as $$
  select jsonb_array_length(pg_temp.query(actor, 'listPersonal') -> 'items')
$$;

-- 1. Writing in the personal notebook: student accounts only.
select is(pg_temp.command(:'loner', 'createPersonal', null,
    '{"title":"Photosynthesis","body":"Light + water -> sugar","source":"typed"}')
  ->> 'outcome', 'ok', 'a student with no class writes a personal note');
select ok(exists (select 1 from public.notebook_entries n
    where n.owner_id = :'loner' and n.school_id is null and n.classroom_id is null
      and n.student_id is null and n.source = 'typed'),
  'the note belongs to no school, class or student record - only its owner');
select is(pg_temp.command(:'guardian_user', 'createPersonal', null,
    '{"title":"x","body":"y"}') ->> 'outcome', 'forbidden',
  'a parent account has no personal notebook');
select is(pg_temp.command(:'teacher_user', 'createPersonal', null,
    '{"title":"x","body":"y"}') ->> 'outcome', 'forbidden',
  'nor does a teacher account');
select is(pg_temp.command(:'loner', 'createPersonal', null,
    '{"title":"x","body":"y","source":"lesson"}') ->> 'outcome', 'invalid',
  'a personal note cannot claim to come from a lesson');
select is(pg_temp.command(:'loner', 'createPersonal', null,
    '{"title":"","body":"y"}') ->> 'outcome', 'invalid',
  'a note needs a title');
select is(pg_temp.command(:'student_user', 'createPersonal', null,
    '{"title":"Mine too","body":"A student in a class has one as well"}')
  ->> 'outcome', 'ok', 'a student in a class has a personal notebook too');

-- 2. Only its owner sees it.
select is(pg_temp.mine(:'loner'), 1, 'the owner lists their personal note');
select is(pg_temp.query(:'loner', 'listPersonal') -> 'items' -> 0 ->> 'classroomId',
  null, 'and it says it is in no class');
select is(pg_temp.mine(:'student_user'), 1,
  'another student lists only their own');
select is(pg_temp.mine(:'teacher_user'), 0, 'a teacher sees none of them');
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(jsonb_array_length(private.api049_notebooks('myNotebooks', null, '{}')
    -> 'classes'), 0, 'nor does any class notebook list show them');

-- 3. Editing and renaming one's own notes.
create temp table loner_note as
  select n.id from public.notebook_entries n where n.owner_id = :'loner';
select is(pg_temp.command(:'loner', 'updateEntry', (select id from loner_note),
    '{"title":"Photosynthesis basics"}') -> 'response' ->> 'title',
  'Photosynthesis basics', 'the owner renames their note');
select is((select body from public.notebook_entries where id = (select id from loner_note)),
  'Light + water -> sugar', 'and renaming leaves its text alone');
select is(pg_temp.command(:'loner', 'updateEntry', (select id from loner_note),
    '{}') ->> 'outcome', 'invalid', 'an edit that changes nothing is refused');
select is(pg_temp.command(:'student_user', 'updateEntry', (select id from loner_note),
    '{"title":"Hijacked"}') ->> 'outcome', 'not_found',
  'nobody else can edit it');
select is(pg_temp.command(:'student_user', 'deleteEntry', (select id from loner_note),
    '{}') ->> 'outcome', 'not_found', 'nobody else can delete it');

-- A note in a class can be corrected by its owner too, and stays in its class.
insert into public.notebook_entries(school_id, classroom_id, student_id,
  owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'student_id', :'student_user',
  'Cells', 'Mitochondria.', 'typed');
select is(pg_temp.command(:'student_user', 'updateEntry',
    (select id from public.notebook_entries where owner_id = :'student_user'
       and classroom_id is not null),
    '{"body":"Mitochondria make energy."}') -> 'response' ->> 'classroomId',
  :'classroom_id', 'a class note is edited where it is');

-- 4. The table holds the line: in a class, or personal - never half of each.
select throws_ok(
  $$insert into public.notebook_entries(school_id, owner_id, title, body, source)
    values ('aaaa0000-0000-4000-8000-000000000001',
      'f00d0000-0000-4000-8000-0000000000f1', 'x', 'y', 'typed')$$,
  '23514', null, 'a note with a school but no class is refused');

-- 5. Practice from one's own notes: Studafy Max, after the AI consent.
select is(pg_temp.query(:'loner', 'notesForPractice',
    jsonb_build_object('entryIds', jsonb_build_array((select id from loner_note))))
  ->> 'outcome', 'forbidden', 'not before the student agrees to the AI notice');
insert into public.consent_records (user_id, purpose, policy_version, locale,
  policy_id, given_by, given_as)
select :'loner', 'ai_features', p.policy_version, 'en', p.id, :'loner', 'self'
from public.consent_policies p
where p.purpose = 'ai_features' and p.locale = 'en'
order by p.effective_at desc, p.policy_version desc limit 1;
select is(private.ai_access(:'loner'), 'ok',
  'a student with no class may use the AI tools once they consent');
select is(pg_temp.query(:'loner', 'notesForPractice',
    jsonb_build_object('entryIds', jsonb_build_array((select id from loner_note))))
  ->> 'outcome', 'plan_required', 'a free student cannot practise from notes');
insert into private.study_plan_grants(user_id, plan, reason, ends_at)
  values (:'loner', 'max', 'pgTAP independent students', now() + interval '1 day');
select is(pg_temp.query(:'loner', 'notesForPractice',
    jsonb_build_object('entryIds', jsonb_build_array((select id from loner_note))))
  -> 'items' -> 0 ->> 'text', 'Light + water -> sugar',
  'on Max, the text of their own note is read');
select is(pg_temp.query(:'loner', 'notesForPractice',
    jsonb_build_object('entryIds', jsonb_build_array(
      (select id from public.notebook_entries where owner_id = :'student_user'
         and classroom_id is not null))))
  ->> 'outcome', 'not_found', 'never someone else''s note');
select is(pg_temp.query(:'loner', 'notesForPractice', '{"entryIds":[]}')
  ->> 'outcome', 'invalid', 'and never nothing');

-- 6. Deleting one's own note.
select is(pg_temp.command(:'loner', 'deleteEntry', (select id from loner_note), '{}')
  -> 'response' ->> 'deleted', 'true', 'the owner deletes their note');
select is(pg_temp.mine(:'loner'), 0, 'and it leaves their notebook');
select is(pg_temp.command(:'loner', 'deleteEntry', (select id from loner_note), '{}')
  ->> 'outcome', 'not_found', 'a deleted note cannot be deleted again');
select ok(exists (select 1 from public.audit_events a
    where a.entity_id = (select id from loner_note)
      and a.action = 'notebook_entry_deleted' and a.school_id is null
      and not (a.after_value ? 'body')),
  'the deletion is audited, without what the note said');

select * from finish();
rollback;
