-- Studafy School Portal (202611050010, docs/planning/school-portal.md):
-- anyone adult creates a school's page; it links a teacher only by the
-- teacher's Studafy ID and the teacher's acceptance; while linked it reads,
-- and only reads, all of the teacher's classes; never messages, AI Tutor
-- material or students' own notes; one school at a time; every read is
-- recorded; the administrator is never a school member.
-- Transactional fixtures: this test leaves existing local users/data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(175);
select set_config('studafy.request_id', 'school-portal-test', true);

\set admin1 'f0000000-0000-4000-8000-000000000001'
\set admin2 'f0000000-0000-4000-8000-000000000002'
\set admin3 'f0000000-0000-4000-8000-000000000003'
\set admin4 'f0000000-0000-4000-8000-000000000004'
\set stranger 'f0000000-0000-4000-8000-000000000005'
\set later_class 'f0000000-0000-4000-8000-000000000011'
\set archived_class 'f0000000-0000-4000-8000-000000000012'
\set assignment 'f0000000-0000-4000-8000-000000000013'
\set submission 'f0000000-0000-4000-8000-000000000014'
\set hand_in 'f0000000-0000-4000-8000-000000000015'
\set online 'f0000000-0000-4000-8000-000000000016'
\set question 'f0000000-0000-4000-8000-000000000017'
\set attempt 'f0000000-0000-4000-8000-000000000018'

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
select id::uuid, email, 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
  now(), now(), '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', name)
from (values
  (:'admin1', 'head@cedar.synthetic.studafy.test', 'Cedar Head'),
  (:'admin2', 'deputy@cedar.synthetic.studafy.test', 'Cedar Deputy'),
  (:'admin3', 'it@cedar.synthetic.studafy.test', 'Cedar IT'),
  (:'admin4', 'head@oak.synthetic.studafy.test', 'Oak Head'),
  (:'stranger', 'stranger@synthetic.studafy.test', 'Stranger')) v(id, email, name);
-- Website-only adults: no membership anywhere, and no kind recorded yet;
-- admin1 confirms being an adult when creating the school (below).
update public.profiles set account_kind = 'adult'
where id in (:'admin2', :'admin3', :'admin4', :'stranger');

create function pg_temp.cmd(actor uuid, op text, res uuid, body jsonb)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(null, 'school-portal', gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api062_command(op, res, jsonb_build_object('body', body),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.q(actor uuid, op text, res uuid, org uuid default null)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api062_query(op, res, jsonb_build_object('orgId', org));
end $$;
-- Earlier suites in CI leave more students in the seed class: pick by id.
create function pg_temp.seed(items jsonb, id uuid) returns jsonb language sql as $$
  select i from jsonb_array_elements(items) i where i->>'studentId' = id::text limit 1;
$$;
-- A clean file, as the scan leaves one.
create function pg_temp.file(p_id uuid, p_name text) returns void language sql as $$
  insert into public.file_objects (id, school_id, bucket, object_key, uploader_id,
    size_bytes, declared_media_type, detected_media_type, sha256, scan_state,
    owner_id, purpose, display_name)
  values (p_id, '11111111-1111-4111-8111-111111111111', 'private-school-files',
    'quarantine/v1/' || p_id::text || '/abcdefghijklmnopqrstuvwx',
    'aaaa0000-0000-4000-8000-000000000001', 10, 'application/pdf', 'application/pdf',
    encode(extensions.digest(p_id::text, 'sha256'), 'hex'), 'quarantined',
    'aaaa0000-0000-4000-8000-000000000001', 'lesson_resource', p_name);
  update public.file_objects set scan_state = 'clean', scanned_at = now(),
    stored_sha256 = sha256, stored_size_bytes = size_bytes
  where id = p_id;
$$;
-- The portal's download intent, and serving it, as the given user.
create function pg_temp.open(actor uuid, org uuid, p_file uuid, seq int)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(null, 'v1.createSchoolPortalFileDownload',
    'portal-download-' || lpad(seq::text, 8, '0') || '-' || gen_random_uuid(),
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api062_file_download(org, p_file,
    jsonb_build_object('nonceHash', md5('pnonce' || seq) || md5('pnonce:' || seq),
      'downloadUrl', 'https://api.studafy.test/delivery/v1/files/' || p_file || '/content?token=t',
      'expiresAt', now() + interval '5 minutes'),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.serve(actor uuid, p_file uuid, seq int)
returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  return private.api051_consume_download_grant(p_file,
    md5('pnonce' || seq) || md5('pnonce:' || seq));
end $$;
-- A student typing a code in "Join a class" (the API sends its HMAC).
-- schoolGroups: the API sends it while the School Portal is switched on.
create function pg_temp.redeem(actor uuid, code_hash text, portal_on boolean default true)
returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claim.sub', actor::text, true);
  r := private.api_idempotency_reserve(null, 'v1.redeemClassJoinLink', gen_random_uuid()::text,
    encode(extensions.digest(gen_random_uuid()::text, 'sha256'), 'hex'), 3600, 60);
  return private.api044_command('redeemClassJoinLink', null,
    jsonb_build_object('body', jsonb_build_object('codeHash', code_hash)
      || case when portal_on then '{"schoolGroups": true}'::jsonb else '{}'::jsonb end),
    (r->>'id')::uuid, (r->>'generation')::bigint);
end $$;
create function pg_temp.hash(code text) returns text language sql as $$
  select encode(extensions.digest(code, 'sha256'), 'hex');
$$;
create function pg_temp.views(actor uuid) returns bigint language sql as $$
  select count(*) from private.school_portal_views where admin_id = actor;
$$;

-- 1. Creating a school's page.
select is(pg_temp.cmd(:'admin1', 'createOrg', null, '{"name":"Cedar Grove School",
  "country":"Jordan","city":"Amman","kind":"private","jobTitle":"Principal","agreementVersion":"2026-11-06"}')->>'outcome',
  'forbidden', 'an account nobody has classified must confirm being an adult first');
select is(pg_temp.cmd(:'admin1', 'createOrg', null, '{"name":"Cedar Grove School",
  "country":"Jordan","city":"Amman","kind":"private","jobTitle":"Principal","adult":true,"agreementVersion":"2026-11-06"}')->>'status',
  '201', 'an adult with no school membership creates a school''s page');
select is((select account_kind from public.profiles where id = :'admin1'), 'adult',
  'and the account is recorded as an adult, once');
select is((select agreement_version || ' ' || (agreement_accepted_at is not null)::text
  from private.school_portal_admins where user_id = :'admin1'), '2026-11-06 true',
  'with the School Agreement version they accepted, and when');
select set_config('test.org', (select id::text from private.school_portal_orgs
  where name = 'Cedar Grove School'), true);
select is(pg_temp.cmd(:'admin4', 'createOrg', null, '{"name":"Oak Hill School",
  "country":"Jordan","city":"Irbid","kind":"public","jobTitle":"Principal","agreementVersion":"2026-11-06"}')->>'outcome',
  'ok', 'and so does another school');
select set_config('test.org2', (select id::text from private.school_portal_orgs
  where name = 'Oak Hill School'), true);
select is(pg_temp.cmd(:'student_user', 'createOrg', null, '{"name":"Kid School",
  "country":"Jordan","city":"Amman","kind":"other","jobTitle":"Boss","adult":true,"agreementVersion":"2026-11-06"}')->>'outcome',
  'forbidden', 'a student cannot create one, even saying they are an adult');
select is(pg_temp.cmd(:'admin4', 'createOrg', null, '{"name":"Elm School",
  "country":"Jordan","city":"Irbid","kind":"public","jobTitle":"Principal",
  "agreementVersion":"2026-01-01"}')->>'outcome',
  'invalid', 'a school is not created without the current School Agreement');
select is(pg_temp.cmd(:'admin1', 'createOrg', null, '{"name":"x","country":"Jordan",
  "city":"Amman","kind":"private","jobTitle":"Principal","agreementVersion":"2026-11-06"}')->>'outcome',
  'invalid', 'a too-short name is refused');
select is(jsonb_array_length(pg_temp.q(:'admin1', 'orgs', null)->'orgs'), 1,
  'an administrator sees only their own school');
select is(pg_temp.q(:'admin1', 'dashboard', current_setting('test.org2')::uuid)->>'outcome',
  'not_found', 'and nothing of another school');
select ok(not exists (select 1 from public.memberships where user_id = :'admin1'),
  'the administrator has no school membership');

-- 2. Administrators: at most three.
select is(pg_temp.cmd(:'admin1', 'inviteAdmin', current_setting('test.org')::uuid,
  '{"email":"Deputy@cedar.synthetic.studafy.test","jobTitle":"Deputy head"}')->>'status',
  '201', 'an administrator invites a second by email');
select is(pg_temp.cmd(:'admin1', 'inviteAdmin', current_setting('test.org')::uuid,
  '{"email":"it@cedar.synthetic.studafy.test","jobTitle":"IT lead"}')->>'outcome',
  'ok', 'and a third');
select is(pg_temp.cmd(:'admin1', 'inviteAdmin', current_setting('test.org')::uuid,
  '{"email":"stranger@synthetic.studafy.test","jobTitle":"Fourth"}')->>'reason',
  'admin_limit', 'a fourth is refused');
select is(pg_temp.cmd(:'stranger', 'acceptInvite', (select id from private.school_portal_admin_invites
  where email = 'deputy@cedar.synthetic.studafy.test'), '{"agreementVersion":"2026-11-06"}')->>'outcome',
  'not_found', 'an invite is accepted only by the address it was sent to');
select is(pg_temp.cmd(:'admin2', 'acceptInvite', (select id from private.school_portal_admin_invites
  where email = 'deputy@cedar.synthetic.studafy.test'), '{}')->>'outcome',
  'invalid', 'an invite is not accepted without the School Agreement');
update auth.users set email_confirmed_at = null where id = :'admin2';
select is(pg_temp.cmd(:'admin2', 'acceptInvite', (select id from private.school_portal_admin_invites
  where email = 'deputy@cedar.synthetic.studafy.test'), '{"agreementVersion":"2026-11-06"}')->>'outcome',
  'not_found', 'nor by an address the sign-in provider has not confirmed');
update auth.users set email_confirmed_at = now() where id = :'admin2';
select is(pg_temp.cmd(:'admin2', 'acceptInvite', (select id from private.school_portal_admin_invites
  where email = 'deputy@cedar.synthetic.studafy.test'), '{"agreementVersion":"2026-11-06"}')->>'outcome',
  'ok', 'the invited person accepts');
select is((select agreement_version from private.school_portal_admins
  where user_id = :'admin2' and removed_at is null), '2026-11-06',
  'and their acceptance of the School Agreement is recorded too');
select is(jsonb_array_length(pg_temp.q(:'admin2', 'orgs', null)->'orgs'->0->'admins'), 2,
  'and both administrators are listed');
select is(pg_temp.cmd(:'admin1', 'inviteAdmin', current_setting('test.org')::uuid,
  '{"email":"it@cedar.synthetic.studafy.test","jobTitle":"Head of IT"}')->>'status',
  '201', 'sending again to the same address corrects an invite, even with every seat taken');
select is((select string_agg(job_title, ',') from private.school_portal_admin_invites
  where email = 'it@cedar.synthetic.studafy.test' and revoked_at is null), 'Head of IT',
  'and replaces the earlier one');
select is(pg_temp.cmd(:'admin4', 'revokeInvite', current_setting('test.org')::uuid,
  jsonb_build_object('inviteId', (select id from private.school_portal_admin_invites
    where email = 'it@cedar.synthetic.studafy.test' and revoked_at is null)))->>'outcome',
  'not_found', 'another school''s administrator cannot cancel an invite');
select is(pg_temp.cmd(:'admin1', 'revokeInvite', current_setting('test.org')::uuid,
  jsonb_build_object('inviteId', (select id from private.school_portal_admin_invites
    where email = 'it@cedar.synthetic.studafy.test' and revoked_at is null)))->>'outcome',
  'ok', 'an administrator cancels an invite');
select is(jsonb_array_length(pg_temp.q(:'admin1', 'orgs', null)->'orgs'->0->'invites'), 0,
  'and it is no longer listed');

-- 3. Finding a teacher by Studafy ID: teachers only, counted.
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'student_user')))
  ->>'outcome', 'teacher_not_found', 'a student''s account is never found');
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'guardian_user')))
  ->>'outcome', 'teacher_not_found', 'nor a parent''s');
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', 'tc-' || (select public_id from public.profiles where id = :'teacher_user')))
  ->'response'->>'status', 'pending', 'a teacher is found and asked, by the ID as their app shows it');
select is(pg_temp.q(:'admin1', 'dashboard', current_setting('test.org')::uuid)
  ->'waiting'->0->'teacher'->'email', 'null'::jsonb,
  'the school sees a waiting teacher''s name, never their email');
select is((select count(*)::int from private.school_portal_lookups where admin_id = :'admin1'), 3,
  'every lookup is counted, found or not');
select is(pg_temp.cmd(:'admin2', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'teacher_user')))
  ->>'reason', 'already_requested', 'the same teacher is not asked twice at once');

-- 4. Nothing is visible before the teacher accepts.
select is(jsonb_array_length(pg_temp.q(:'admin1', 'classes', current_setting('test.org')::uuid)->'classes'),
  0, 'a waiting request shows no classes');
select is(pg_temp.q(:'admin1', 'roster', :'classroom_id', current_setting('test.org')::uuid)->>'outcome',
  'not_found', 'nor any class''s roster');
select is(pg_temp.q(:'teacher_user', 'myLinks', null)->'links'->0->'org'->>'name',
  'Cedar Grove School', 'the teacher sees who is asking');
select is(pg_temp.q(:'teacher_user', 'myLinks', null)->'links'->0->'requestedBy'->>'jobTitle',
  'Principal', 'with the administrator''s job title');
select is(pg_temp.cmd(:'admin1', 'decideLink', (select id from private.school_portal_teacher_links
  where teacher_id = :'teacher_user'), '{"decision":"accept"}')->>'outcome',
  'not_found', 'an administrator cannot accept for the teacher');

-- 5. Decline, the 30-day block, then accept.
select is(pg_temp.cmd(:'teacher_user', 'decideLink', (select id from private.school_portal_teacher_links
  where teacher_id = :'teacher_user'), '{"decision":"decline"}')->'response'->>'status',
  'declined', 'the teacher declines');
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'teacher_user')))
  ->>'reason', 'recently_declined', 'the school cannot ask again for 30 days');
select ok((select bool_and(t->'email' = 'null'::jsonb) from jsonb_array_elements(
    pg_temp.q(:'admin1', 'teachers', current_setting('test.org')::uuid)->'teachers') t),
  'and keeps no email of a teacher who declined');
insert into private.school_portal_admins (org_id, user_id, job_title, agreement_version)
values (current_setting('test.org2')::uuid, :'admin1', 'Visitor', private.school_portal_agreement_version());
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org2')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'teacher_user')))
  ->>'reason', 'recently_declined', 'nor can whoever asked, from another school page');
delete from private.school_portal_admins
where org_id = current_setting('test.org2')::uuid and user_id = :'admin1';
update private.school_portal_teacher_links set decided_at = now() - interval '31 days'
where teacher_id = :'teacher_user';
select is(pg_temp.cmd(:'admin1', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'teacher_user')))
  ->'response'->>'status', 'pending', 'after 30 days it can');
select set_config('test.link', (select id::text from private.school_portal_teacher_links
  where teacher_id = :'teacher_user' and status = 'pending'), true);
select is((select count(*)::int from public.notification_outbox o
  where o.template_key = 'school_portal.link_requested'
    and o.source_event_id = current_setting('test.link')
    and o.school_id = :'school_id'), 1,
  'the request queues one notice, under the teacher''s own workspace');
select is((select private.api061_notification_recipients(o.school_id, o.template_key,
    o.source_event_id, o.audience) from public.notification_outbox o
  where o.source_event_id = current_setting('test.link')),
  array[:'teacher_user'::uuid], 'it reaches the teacher, and nobody else');
select is(pg_temp.cmd(:'teacher_user', 'decideLink', current_setting('test.link')::uuid,
  '{"decision":"accept"}')->'response'->>'status', 'linked', 'the teacher accepts');
select is((select t->>'email' from jsonb_array_elements(
    pg_temp.q(:'admin1', 'teachers', current_setting('test.org')::uuid)->'teachers') t
  where t->>'status' = 'linked'), (select email::text from auth.users where id = :'teacher_user'),
  'once linked, the school has the teacher''s email');
select is((select private.api061_notification_recipients(o.school_id, o.template_key,
    o.source_event_id, o.audience) from public.notification_outbox o
  where o.source_event_id = current_setting('test.link')),
  '{}'::uuid[], 'a request already answered notifies nobody');

-- 6. Every class of the linked teacher, read-only and recorded.
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'later_class', :'school_id', :'term_id', 'Later Class', 'G7', 'B', :'teacher_user'),
       (:'archived_class', :'school_id', :'term_id', 'Old Class', 'G5', 'C', :'teacher_user');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', c.id, m.id, :'teacher_user', 'lead_teacher'
from public.memberships m, (values (:'later_class'::uuid), (:'archived_class'::uuid)) c(id)
where m.school_id = :'school_id' and m.user_id = :'teacher_user' and m.role = 'teacher';
update public.classrooms set status = 'archived', archived_at = now() where id = :'archived_class';
select is((select array_agg(c->>'name' order by c->>'name') from jsonb_array_elements(
    pg_temp.q(:'admin1', 'classes', current_setting('test.org')::uuid)->'classes') c),
  array['Later Class', 'Seed Classroom'],
  'all the teacher''s classes, including one created after linking; not archived ones');
select is(pg_temp.q(:'admin1', 'dashboard', current_setting('test.org')::uuid)->>'linkedTeachers',
  '1', 'the dashboard counts the linked teacher');

select set_config('test.before', pg_temp.views(:'admin1')::text, true);
select is(pg_temp.seed(pg_temp.q(:'admin1', 'roster', :'classroom_id', current_setting('test.org')::uuid)
  ->'students', :'student_id')->>'email', 'seed.student@synthetic.studafy.test', 'the roster has students'' emails');
select is(pg_temp.views(:'admin1') - current_setting('test.before')::bigint, 1::bigint,
  'and that read wrote exactly one activity row');
select is(pg_temp.seed(pg_temp.q(:'admin1', 'roster', :'classroom_id', current_setting('test.org')::uuid)
  ->'students', :'student_id')->>'studafyId', 'STU-SEED-0001', 'their Studafy IDs');
select is(pg_temp.seed(pg_temp.q(:'admin1', 'roster', :'classroom_id', current_setting('test.org')::uuid)
  ->'students', :'student_id')->'parents', '[{"name": "Seed Guardian", "email": "seed.guardian@synthetic.studafy.test", "relationship": "parent"}]'::jsonb,
  'and their verified parents with emails, never a pending one');
select is((select array_agg(m->>'state' order by m->>'state') from jsonb_array_elements(
    pg_temp.q(:'admin1', 'marks', :'classroom_id', current_setting('test.org')::uuid)->'marks') m
    where m->>'studentId' = :'student_id'),
  array['draft', 'published'], 'marks include unpublished ones');
select is((select r->>'date' from jsonb_array_elements(
    pg_temp.q(:'admin1', 'attendance', :'classroom_id', current_setting('test.org')::uuid)->'records') r
    where r->>'sessionId' = :'session_id' and r->>'studentId' = :'student_id'), '2026-09-10', 'attendance is each student''s record by day');

insert into public.wellbeing_events (student_id, classroom_id, kind, title, created_by, visibility)
values (:'student_id', :'classroom_id', 'concern', 'Restricted note', :'teacher_user', 'safeguarding_restricted');
select is((select array_agg(n->>'title' order by n->>'title') from jsonb_array_elements(
    pg_temp.q(:'admin1', 'wellbeing', :'classroom_id', current_setting('test.org')::uuid)->'notes') n
    where n->>'title' in ('Seed wellbeing note', 'Restricted note')),
  array['Seed wellbeing note'], 'wellbeing notes are included, safeguarding-restricted ones are not');

insert into public.announcements (school_id, classroom_id, title, body, audience,
  published_at, created_by, state)
values (:'school_id', :'classroom_id', 'Trip on Friday', 'Bring a packed lunch.', 'both',
  now(), :'teacher_user', 'published');
select is(pg_temp.q(:'admin1', 'lessons', :'classroom_id', current_setting('test.org')::uuid)
  ->'announcements'->0->>'title', 'Trip on Friday', 'lessons come with the class''s announcements');

\set trip_file 'f0000000-0000-4000-8000-000000000021'
\set loose_file 'f0000000-0000-4000-8000-000000000022'
select pg_temp.file(:'trip_file', 'trip-letter.pdf');
select pg_temp.file(:'loose_file', 'not-shared.pdf');
insert into public.file_bindings (school_id, file_object_id, announcement_id)
select :'school_id', :'trip_file', id from public.announcements where title = 'Trip on Friday';
select is(pg_temp.open(:'admin1', current_setting('test.org')::uuid, :'trip_file', 1)
  ->'response'->>'displayName', 'trip-letter.pdf',
  'an administrator gets a single-use link for a file of a linked class');
select is((select count(*)::int from private.school_portal_views
  where admin_id = :'admin1' and view = 'file' and file_id = :'trip_file'), 1,
  'and the activity record says which file');
select is(pg_temp.serve(:'admin1', :'trip_file', 1)->>'outcome', 'ok',
  'the link is served once, re-checked when it is used');
select is(pg_temp.serve(:'admin1', :'trip_file', 1)->>'outcome', 'grant_invalid',
  'and never twice');
select is(pg_temp.open(:'admin1', current_setting('test.org')::uuid, :'loose_file', 2)->>'outcome',
  'not_found', 'a file of no visible class is not the school''s to open');
select is(pg_temp.open(:'admin4', current_setting('test.org2')::uuid, :'trip_file', 3)->>'outcome',
  'not_found', 'nor another school''s');
select is(pg_temp.open(:'admin1', current_setting('test.org')::uuid, :'trip_file', 4)->>'outcome',
  'ok', 'a second link, issued while linked');

insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, published_at)
values (:'assignment', :'school_id', :'classroom_id', 'Essay on rivers', now() + interval '3 days',
  'published', :'teacher_user', now());
insert into public.submissions (id, school_id, assignment_id, student_id, status, submitted_at)
values (:'submission', :'school_id', :'assignment', :'student_id', 'submitted', now());
insert into public.submission_attempts (id, school_id, submission_id, operation_id, answer_text, submitted_at)
values (:'hand_in', :'school_id', :'submission', gen_random_uuid(), 'Rivers carve valleys.', now());
update public.submissions set current_attempt_id = :'hand_in' where id = :'submission';
select is(pg_temp.seed(pg_temp.q(:'admin1', 'handIns', :'assignment', current_setting('test.org')::uuid)
  ->'handIns', :'student_id')->>'answerText', 'Rivers carve valleys.', 'hand-ins show what each student handed in');
select is(pg_temp.q(:'admin1', 'assignments', :'classroom_id', current_setting('test.org')::uuid)
  ->'assignments'->0->>'handedIn', '1', 'assignments count hand-ins');

insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score,
  state, delivery, created_by, published_at)
values (:'online', :'school_id', :'classroom_id', 'Rivers quiz', 'quiz', 5, 'published',
  'online', :'teacher_user', now());
insert into public.assessment_questions (id, school_id, assessment_id, position, prompt,
  maximum_score, kind)
values (:'question', :'school_id', :'online', 1, 'Name a river.', 5, 'short_answer');
insert into public.assessment_attempts (id, school_id, assessment_id, student_id, operation_id, submitted_at)
values (:'attempt', :'school_id', :'online', :'student_id', gen_random_uuid(), now());
insert into public.assessment_answers (school_id, attempt_id, question_id, answer_text)
values (:'school_id', :'attempt', :'question', 'The Jordan');
select is(pg_temp.q(:'admin1', 'testAnswers', :'online', current_setting('test.org')::uuid)
  ->'attempts'->0->'answers'->0->>'answerText', 'The Jordan', 'test answers are readable');
select is(pg_temp.q(:'admin1', 'tests', :'classroom_id', current_setting('test.org')::uuid)
  ->>'outcome', 'ok', 'and the class''s tests');
select is(pg_temp.q(:'admin1', 'roster', :'classroom_id', current_setting('test.org2')::uuid)->>'outcome',
  'not_found', 'another school sees none of it');
select is(pg_temp.q(:'teacher_user', 'roster', :'classroom_id', current_setting('test.org')::uuid)->>'outcome',
  'not_found', 'nor does anyone who is not the school''s administrator');

select is((select (c->'term'->>'name') || ' ' || (c->>'lastActivityAt' is not null)::text
    from jsonb_array_elements(pg_temp.q(:'admin1', 'classes',
      current_setting('test.org')::uuid)->'classes') c where c->>'id' = :'classroom_id'),
  (select name from public.terms where id = :'term_id') || ' true',
  'each class has its term and when something last happened in it');
select set_config('test.before', pg_temp.views(:'admin1')::text, true);
select is((pg_temp.q(:'admin1', 'classOverview', :'classroom_id',
    current_setting('test.org')::uuid)->'upcomingAssignments'->0)->>'handedIn', '1',
  'a class''s overview lists work coming up, with how many handed it in');
select is((select count(*)::int from private.school_portal_views where admin_id = :'admin1'
    and view = 'overview' and classroom_id = :'classroom_id'), 1,
  'and is recorded as that class''s overview');
select is(pg_temp.q(:'admin4', 'classOverview', :'classroom_id',
    current_setting('test.org2')::uuid)->>'outcome', 'not_found',
  'another school sees no class overview');

-- 6b. The overview: per class, and students who need attention.
insert into public.assignments (school_id, classroom_id, title, due_at, state, created_by, published_at)
values
  (:'school_id', :'classroom_id', 'Late map', now() - interval '2 days', 'published', :'teacher_user', now() - interval '5 days'),
  (:'school_id', :'classroom_id', 'Late essay', now() - interval '1 day', 'published', :'teacher_user', now() - interval '5 days');
select ok((select bool_or(a->>'studentId' = :'student_id' and a->'reasons' ? 'missing_work')
    from jsonb_array_elements(pg_temp.q(:'admin1', 'overview',
      current_setting('test.org')::uuid)->'attention') a),
  'a student with two pieces of overdue work is on the needs-attention list, with the reason');
select ok((select (c->>'missing')::int >= 2 from jsonb_array_elements(pg_temp.q(:'admin1', 'overview',
      current_setting('test.org')::uuid)->'classes') c where c->>'classroomId' = :'classroom_id'),
  'and the class counts its missing work');
select is(pg_temp.q(:'admin4', 'overview', current_setting('test.org')::uuid)->>'outcome',
  'not_found', 'another school''s administrator sees no overview');

select is(jsonb_array_length(pg_temp.q(:'admin1', 'reports', current_setting('test.org')::uuid)->'weeks'),
  12, 'reports cover the last twelve weeks');
select ok((select (c->>'handInRate')::numeric < 1 from jsonb_array_elements(pg_temp.q(:'admin1', 'reports',
      current_setting('test.org')::uuid)->'classes') c where c->>'classroomId' = :'classroom_id'),
  'and count overdue work that was not handed in');

select is(pg_temp.cmd(:'admin1', 'recordExport', current_setting('test.org')::uuid,
  jsonb_build_object('kind', 'marks', 'format', 'csv', 'classroomId', :'classroom_id'))->>'status',
  '201', 'an export is recorded before the file is made');
select is((select count(*)::int from private.school_portal_views where admin_id = :'admin1'
  and view = 'export' and export_kind = 'marks' and export_format = 'csv'), 1,
  'with what was exported and as what');
select is(pg_temp.cmd(:'admin1', 'recordExport', current_setting('test.org')::uuid,
  jsonb_build_object('kind', 'marks', 'format', 'csv', 'classroomId', gen_random_uuid()))->>'outcome',
  'not_found', 'a class the school cannot see cannot be exported');

-- 6d. Announcements from the school.
select is(pg_temp.cmd(:'admin1', 'sendAnnouncement', current_setting('test.org')::uuid,
  '{"title":"Sports day","body":"Friday from 9.","audience":"students_and_parents"}')->>'status',
  '201', 'an administrator sends an announcement to every linked class');
select is(pg_temp.cmd(:'admin4', 'sendAnnouncement', current_setting('test.org2')::uuid,
  '{"title":"Hello","body":"Anyone?","audience":"students"}')->>'reason', 'no_recipients',
  'an announcement that would reach nobody is refused');
select is((select count(*)::int from private.school_portal_announcements
  where org_id = current_setting('test.org2')::uuid), 0, 'and nothing is kept');
select set_config('test.ann', (select id::text from private.school_portal_announcements
  where title = 'Sports day'), true);
select ok((select bool_and(u = any(array(select r.user_id from private.school_portal_announcement_recipients(
    current_setting('test.ann')::uuid) r))) from unnest(array[:'student_user'::uuid, :'guardian_user'::uuid]) u),
  'it reaches the class''s students and their parents');
select ok(not exists (select 1 from private.school_portal_announcement_recipients(
    current_setting('test.ann')::uuid) r where r.user_id = :'teacher_user'),
  'and not the teacher, for whom it was not meant');
select is((select count(*)::int from public.notification_outbox
  where template_key = 'school_portal.announcement' and source_event_id = current_setting('test.ann')), 1,
  'one notice for the teacher''s workspace it reaches');
select is((pg_temp.q(:'admin1', 'announcements', current_setting('test.org')::uuid)
    ->'announcements'->0->>'recipients')::int,
  (select count(*)::int from private.school_portal_announcement_recipients(current_setting('test.ann')::uuid)),
  'the school sees how many people it reached');
select is(pg_temp.q(:'student_user', 'myAnnouncements', null)->'announcements'->0->>'title', 'Sports day',
  'the student reads it in the app');
select is(pg_temp.cmd(:'admin1', 'sendAnnouncement', current_setting('test.org')::uuid,
  jsonb_build_object('title', 'x', 'body', 'y', 'audience', 'teachers',
    'classroomIds', jsonb_build_array(gen_random_uuid())))->>'outcome',
  'not_found', 'a class the school cannot see cannot be chosen');
insert into public.platform_operators (user_id) values (:'stranger');
select is(pg_temp.cmd(:'stranger', 'removeAnnouncement', current_setting('test.ann')::uuid, '{}')
  ->'response'->>'removed', 'true', 'Studafy can remove an announcement after a report');
select is(jsonb_array_length(pg_temp.q(:'student_user', 'myAnnouncements', null)->'announcements'), 0,
  'and it disappears for everyone');

-- 6c. A student's page and a teacher's page.
select is(pg_temp.q(:'admin1', 'student', :'student_id', current_setting('test.org')::uuid)
  ->'student'->>'email', 'seed.student@synthetic.studafy.test',
  'a student''s page shows them across the school''s classes');
select ok((select bool_or(m->>'title' = 'Late map') from jsonb_array_elements(
    pg_temp.q(:'admin1', 'student', :'student_id', current_setting('test.org')::uuid)->'missingWork') m),
  'with their missing work');
select is(pg_temp.q(:'admin1', 'student', gen_random_uuid(), current_setting('test.org')::uuid)->>'outcome',
  'not_found', 'a student in no linked class has no page');
select ok((select bool_or(c->>'classroomId' = :'classroom_id') from jsonb_array_elements(
    pg_temp.q(:'admin1', 'teacher', :'teacher_user', current_setting('test.org')::uuid)->'classes') c),
  'a linked teacher''s page lists their classes');
select is(pg_temp.q(:'admin1', 'teacher', :'other_school_user', current_setting('test.org')::uuid)->>'outcome',
  'not_found', 'a teacher who is not linked has no page');

-- 6e. One code for many classes: the teacher approves each class; the
--     student joins every approved class through the class-join steps.
\set kid 'f0000000-0000-4000-8000-000000000021'
\set kid2 'f0000000-0000-4000-8000-000000000022'
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
select id::uuid, email, 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
  now(), now(), '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', name)
from (values (:'kid', 'kid1@synthetic.studafy.test', 'Kid One'),
  (:'kid2', 'kid2@synthetic.studafy.test', 'Kid Two')) v(id, email, name);
update public.profiles set account_kind = 'student' where id in (:'kid', :'kid2');
select is(pg_temp.cmd(:'admin1', 'createGroup', current_setting('test.org')::uuid,
  '{"name":"Grade 6 - A"}')->>'outcome', 'invalid', 'a group needs the code the API mints');
select is(pg_temp.cmd(:'admin1', 'createGroup', current_setting('test.org')::uuid,
  jsonb_build_object('name', 'Grade 6 - A', 'codeHash', pg_temp.hash('GROUPONE'),
    'derivationSalt', 'abcdefghijklmnopqrstuvwxyz01'))->>'status', '201',
  'an administrator makes a group');
select set_config('test.group', (select id::text from private.school_portal_groups
  where name = 'Grade 6 - A'), true);
select is(pg_temp.cmd(:'teacher_user', 'createGroup', current_setting('test.org')::uuid,
  jsonb_build_object('name', 'Mine', 'codeHash', pg_temp.hash('GROUPTWO'),
    'derivationSalt', 'abcdefghijklmnopqrstuvwxyz02'))->>'outcome', 'not_found',
  'a teacher cannot');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.group')::uuid,
  jsonb_build_object('classroomId', :'classroom_id'))->>'status', '201',
  'the school adds a linked class');
select set_config('test.gc', (select id::text from private.school_portal_group_classes
  where group_id = current_setting('test.group')::uuid), true);
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.group')::uuid,
  jsonb_build_object('classroomId', :'classroom_id'))->>'reason', 'already_in_group',
  'once');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.group')::uuid,
  jsonb_build_object('classroomId', gen_random_uuid()))->>'outcome', 'not_found',
  'never a class it cannot see');
select is((select private.api061_notification_recipients(o.school_id, o.template_key,
    o.source_event_id, o.audience) from public.notification_outbox o
  where o.source_event_id = current_setting('test.gc')),
  array[:'teacher_user'::uuid], 'the class''s teacher is asked, and nobody else');
select is(pg_temp.q(:'teacher_user', 'myGroupClasses', null)->'classes'->0->>'groupName',
  'Grade 6 - A', 'and sees the request in the app');
select is(pg_temp.cmd(:'student_user', 'decideGroupClass', current_setting('test.gc')::uuid,
  '{"decision":"approve"}')->>'outcome', 'not_found', 'only the class''s teacher answers');
select is(pg_temp.redeem(:'kid', pg_temp.hash('GROUPONE'))->>'outcome', 'not_found',
  'before the teacher approves, the code joins nothing');
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', current_setting('test.gc')::uuid,
  '{"decision":"approve"}')->'response'->>'status', 'approved', 'the teacher approves');
select is(pg_temp.redeem(:'kid', pg_temp.hash('GROUPONE'), false)->>'outcome', 'not_found',
  'with the School Portal switched off, a group code joins nothing');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.group')::uuid,
  jsonb_build_object('classroomId', :'later_class'))->>'status', '201', 'a second class is added');
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', (select id from private.school_portal_group_classes
  where classroom_id = :'later_class'), '{"decision":"approve"}')->'response'->>'status', 'approved',
  'and approved');
select is(jsonb_array_length(pg_temp.redeem(:'kid', pg_temp.hash('GROUPONE'))
  ->'response'->'group'->'classrooms'), 2, 'one code joins the student to both classes');
select is((select count(*)::int from public.enrollments e join public.students st on st.id = e.student_id
  where st.user_id = :'kid' and e.active and e.classroom_id in (:'classroom_id', :'later_class')), 2,
  'as an enrolled student of each');
select is(pg_temp.redeem(:'kid', pg_temp.hash('GROUPONE'))->>'outcome', 'invalid_state',
  'typing it again says they are already in');
select is(pg_temp.redeem(:'admin2', pg_temp.hash('GROUPONE'))->>'outcome', 'forbidden',
  'an adult account never joins');
select is(jsonb_array_length(pg_temp.q(:'admin1', 'groups', current_setting('test.org')::uuid,
  current_setting('test.org')::uuid)->'groups'->0->'classes'), 2, 'the school sees its group');
select is(pg_temp.cmd(:'admin1', 'renewGroupCode', current_setting('test.group')::uuid,
  jsonb_build_object('codeHash', pg_temp.hash('GROUPNEW'),
    'derivationSalt', 'abcdefghijklmnopqrstuvwxyz03'))->>'outcome', 'ok', 'a new code');
select is(pg_temp.redeem(:'kid2', pg_temp.hash('GROUPONE'))->>'outcome', 'not_found',
  'and the old one stops working');
select is(pg_temp.redeem(:'kid2', pg_temp.hash('GROUPNEW'))->>'outcome', 'ok', 'the new one works');
update public.enrollments e set active = false, status = 'withdrawn', ends_on = current_date
from public.students st
where st.id = e.student_id and st.user_id = :'kid2' and e.classroom_id = :'later_class';
select is(pg_temp.redeem(:'kid2', pg_temp.hash('GROUPNEW'))->>'outcome', 'invalid_state',
  'a student the teacher removed is never put back by the code');
update public.memberships set active = false, status = 'revoked'
where user_id = :'kid2' and school_id = :'school_id' and role = 'student';
select is(pg_temp.redeem(:'kid2', pg_temp.hash('GROUPNEW'))->>'outcome', 'invalid_state',
  'nor one the teacher took out of their workspace');
select is((select status::text from public.memberships
  where user_id = :'kid2' and school_id = :'school_id' and role = 'student'), 'revoked',
  'whose membership stays revoked');
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', (select id from private.school_portal_group_classes
  where classroom_id = :'later_class'), '{"decision":"remove"}')->'response'->>'status', 'removed',
  'the teacher takes a class out');
select is(pg_temp.cmd(:'admin1', 'closeGroup', current_setting('test.group')::uuid, '{}')
  ->'response'->>'status', 'closed', 'the school closes the group');
select is(pg_temp.redeem(:'kid2', pg_temp.hash('GROUPNEW'))->>'outcome', 'not_found',
  'and its code joins nothing');
select is(pg_temp.cmd(:'admin1', 'createGroup', current_setting('test.org')::uuid,
  jsonb_build_object('name', 'Grade 6 - B', 'codeHash', pg_temp.hash('GROUPTHR'),
    'derivationSalt', 'abcdefghijklmnopqrstuvwxyz04'))->>'status', '201', 'another group');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', (select id from private.school_portal_groups
  where name = 'Grade 6 - B'), jsonb_build_object('classroomId', :'classroom_id'))->>'status', '201',
  'with a class waiting for the teacher');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', (select id from private.school_portal_groups
  where name = 'Grade 6 - B'), jsonb_build_object('classroomId', :'later_class'))->>'status', '201',
  'and another');
update public.classroom_staff set role = 'co_teacher'
where classroom_id = :'later_class' and user_id = :'teacher_user';
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', (select gc.id
    from private.school_portal_group_classes gc join private.school_portal_groups g on g.id = gc.group_id
    where g.name = 'Grade 6 - B' and gc.classroom_id = :'later_class'), '{"decision":"approve"}')
  ->>'reason', 'lead_teacher_only', 'only the lead teacher puts a class in a group');
update public.classroom_staff set role = 'lead_teacher'
where classroom_id = :'later_class' and user_id = :'teacher_user';
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', (select gc.id
    from private.school_portal_group_classes gc join private.school_portal_groups g on g.id = gc.group_id
    where g.name = 'Grade 6 - B' and gc.classroom_id = :'later_class'), '{"decision":"decline"}')
  ->'response'->>'status', 'declined', 'the teacher says no');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', (select id from private.school_portal_groups
  where name = 'Grade 6 - B'), jsonb_build_object('classroomId', :'later_class'))->>'reason',
  'group_class_declined', 'and the school cannot ask again for 30 days');

-- 6f. One code across two teachers' classes, each in their own workspace:
--     Mr. Ahmad's Arabic (teacher_user, Seed School) and Mr. Khalid's Math
--     (other_school_user, Seed School B), both Grade 8 Section B.
\set math 'f0000000-0000-4000-8000-000000000031'
\set kid3 'f0000000-0000-4000-8000-000000000023'
\set kid4 'f0000000-0000-4000-8000-000000000024'
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at,
  created_at, updated_at, instance_id, raw_app_meta_data, raw_user_meta_data)
select id::uuid, email, 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
  now(), now(), '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', name)
from (values (:'kid3', 'kid3@synthetic.studafy.test', 'Kid Three'),
  (:'kid4', 'kid4@synthetic.studafy.test', 'Kid Four')) v(id, email, name);
update public.profiles set account_kind = 'student' where id in (:'kid3', :'kid4');
\set math_term 'f0000000-0000-4000-8000-000000000032'
insert into public.terms (id, school_id, name, starts_on, ends_on, active)
values (:'math_term', :'other_school_id', '2026-27', current_date - 60, current_date + 200, true);
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'math', :'other_school_id', :'math_term', 'Math 8B', 'G8', 'B', :'other_school_user');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'other_school_id', :'math', m.id, :'other_school_user', 'lead_teacher'
from public.memberships m
where m.school_id = :'other_school_id' and m.user_id = :'other_school_user' and m.role = 'teacher';
select is(pg_temp.cmd(:'admin2', 'requestLink', current_setting('test.org')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'other_school_user')))
  ->'response'->>'status', 'pending', 'the school asks a second teacher, from another workspace');
select set_config('test.khalid', (select id::text from private.school_portal_teacher_links
  where teacher_id = :'other_school_user' and org_id = current_setting('test.org')::uuid
    and status = 'pending'), true);
select is(pg_temp.cmd(:'other_school_user', 'decideLink', current_setting('test.khalid')::uuid,
  '{"decision":"accept"}')->'response'->>'status', 'linked', 'who accepts');
select is(pg_temp.cmd(:'admin1', 'createGroup', current_setting('test.org')::uuid,
  jsonb_build_object('name', 'Grade 8 - Section B', 'codeHash', pg_temp.hash('GRADE8B1'),
    'derivationSalt', 'abcdefghijklmnopqrstuvwxyz05'))->>'status', '201',
  'a group for one section');
select set_config('test.g8', (select id::text from private.school_portal_groups
  where name = 'Grade 8 - Section B'), true);
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.g8')::uuid,
  jsonb_build_object('classroomId', :'classroom_id'))->>'status', '201', 'with the first teacher''s class');
select is(pg_temp.cmd(:'admin1', 'addGroupClass', current_setting('test.g8')::uuid,
  jsonb_build_object('classroomId', :'math'))->>'status', '201', 'and the second teacher''s');
select is((select private.api061_notification_recipients(o.school_id, o.template_key,
    o.source_event_id, o.audience) from public.notification_outbox o
  where o.source_event_id = (select id::text from private.school_portal_group_classes
    where group_id = current_setting('test.g8')::uuid and classroom_id = :'math')),
  array[:'other_school_user'::uuid], 'each teacher is asked about their own class only');
select is(pg_temp.cmd(:'other_school_user', 'decideGroupClass', (select id from private.school_portal_group_classes
  where group_id = current_setting('test.g8')::uuid and classroom_id = :'classroom_id'),
  '{"decision":"approve"}')->>'outcome', 'not_found', 'and cannot answer for the other''s');
select is(pg_temp.cmd(:'teacher_user', 'decideGroupClass', (select id from private.school_portal_group_classes
  where group_id = current_setting('test.g8')::uuid and classroom_id = :'classroom_id'),
  '{"decision":"approve"}')->'response'->>'status', 'approved', 'the first teacher approves');
select is(jsonb_array_length(pg_temp.redeem(:'kid3', pg_temp.hash('GRADE8B1'))
  ->'response'->'group'->'classrooms'), 1,
  'until the second approves, the code joins only the approved class');
select is(pg_temp.cmd(:'other_school_user', 'decideGroupClass', (select id from private.school_portal_group_classes
  where group_id = current_setting('test.g8')::uuid and classroom_id = :'math'),
  '{"decision":"approve"}')->'response'->>'status', 'approved', 'the second teacher approves');
select is((select array_agg(c->>'classroomName' order by c->>'classroomName')
  from jsonb_array_elements(pg_temp.redeem(:'kid4', pg_temp.hash('GRADE8B1'))
    ->'response'->'group'->'classrooms') c),
  array['Math 8B', 'Seed Classroom'], 'one code joins a student to both teachers'' classes');
select is((select array_agg(distinct m.school_id order by m.school_id) from public.memberships m
  where m.user_id = :'kid4' and m.role = 'student' and m.active),
  array[:'school_id'::uuid, :'other_school_id'::uuid],
  'as a student of each teacher''s workspace');
select is(jsonb_array_length(pg_temp.redeem(:'kid3', pg_temp.hash('GRADE8B1'))
  ->'response'->'group'->'classrooms'), 1,
  'a student who joined early gets the class approved since');
select is(pg_temp.cmd(:'other_school_user', 'endLink', current_setting('test.khalid')::uuid, '{}')
  ->'response'->>'status', 'unlinked', 'the second teacher unlinks');
select is((select array_agg(x) from private.school_portal_group_live_classes(
  current_setting('test.g8')::uuid) x), array[:'classroom_id'::uuid],
  'and their class leaves the group at once; the first teacher''s stays');
select is((select count(*)::int from public.enrollments
  where classroom_id = :'math' and status = 'active'), 2,
  'students who joined stay in the class; only the school stops seeing it');

-- 7. Never: messages, AI Tutor material, students' own notes and practice.
select ok(pg_get_functiondef('private.api062_query(text, uuid, jsonb)'::regprocedure)
  !~ '(messages|conversation|notebook|study_sets|practice_sessions|material_outputs|ai_material|lesson_notes_cache|flashcard)',
  'no portal read touches messages, AI Tutor material, notebooks, notes, flashcards or quizzes');

-- 8. The administrator is never a member, so no existing staff check lets them in.
select set_config('request.jwt.claim.sub', :'admin1', true);
select ok(not private.coursework_teacher(:'classroom_id')
  and not private.coursework_staff(:'classroom_id')
  and not private.is_school_admin(:'school_id'),
  'coursework_teacher, coursework_staff and is_school_admin are all false for a portal administrator');

-- 9. One school at a time.
select is(pg_temp.cmd(:'admin4', 'requestLink', current_setting('test.org2')::uuid,
  jsonb_build_object('studafyId', (select public_id from public.profiles where id = :'teacher_user')))
  ->'response'->>'status', 'pending', 'a second school asks the same teacher');
select set_config('test.link2', (select id::text from private.school_portal_teacher_links
  where teacher_id = :'teacher_user' and org_id = current_setting('test.org2')::uuid), true);
select is(pg_temp.cmd(:'teacher_user', 'decideLink', current_setting('test.link2')::uuid,
  '{"decision":"accept"}')->'current'->>'orgName', 'Cedar Grove School',
  'accepting asks the teacher to leave the current school first');
select is(pg_temp.cmd(:'teacher_user', 'decideLink', current_setting('test.link2')::uuid,
  '{"decision":"accept","replaceCurrent":true}')->'response'->>'status', 'linked',
  'agreeing links the new school');
select is(jsonb_array_length(pg_temp.q(:'admin1', 'classes', current_setting('test.org')::uuid)->'classes'),
  0, 'and the first school stops seeing the classes at once');
select is((select count(*)::int from private.school_portal_group_classes gc
  join private.school_portal_groups g on g.id = gc.group_id
  where g.org_id = current_setting('test.org')::uuid and gc.status in ('pending', 'approved')), 0,
  'and its groups lose those classes for good');
select is(pg_temp.serve(:'admin1', :'trip_file', 4)->>'outcome', 'not_found',
  'a link issued before the teacher left is refused when used');

-- 10. Unlinking, suspension.
select is(pg_temp.cmd(:'teacher_user', 'endLink', current_setting('test.link2')::uuid, '{}')
  ->'response'->>'status', 'unlinked', 'the teacher unlinks');
select is(pg_temp.q(:'admin4', 'roster', :'classroom_id', current_setting('test.org2')::uuid)->>'outcome',
  'not_found', 'and the school sees nothing');
select is(pg_temp.cmd(:'teacher_user', 'reportOrg', current_setting('test.link2')::uuid,
  '{"reason":"pressure","details":"They insisted I link."}')->>'status', '201',
  'the teacher reports the school');
select is((select row(c.org_id, c.reason)::text
  from private.school_portal_alerts_claim(10, 60) c),
  row(current_setting('test.org2')::uuid, 'pressure')::text,
  'the operator is alerted with the school and the reason, never the teacher''s words');
select is(pg_temp.cmd(:'stranger', 'suspendOrg', current_setting('test.org2')::uuid,
  '{"suspend":true,"reason":"Reported by a teacher"}')->'response'->>'status', 'suspended',
  'Studafy suspends a reported school');
select is(pg_temp.q(:'admin4', 'dashboard', current_setting('test.org2')::uuid)->>'outcome',
  'not_found', 'a suspended school sees nothing');
select is(pg_temp.cmd(:'admin4', 'suspendOrg', current_setting('test.org2')::uuid, '{"suspend":false}')
  ->>'outcome', 'forbidden', 'only a platform operator suspends or restores');

-- 11. Limits and expiry.
insert into private.school_portal_lookups (admin_id, org_id, found)
select :'admin2', current_setting('test.org')::uuid, false from generate_series(1, 10);
select is(pg_temp.cmd(:'admin2', 'requestLink', current_setting('test.org')::uuid,
  '{"studafyId":"1234567890"}')->>'outcome', 'rate_limited', 'ten lookups an hour per administrator');
update private.school_portal_teacher_links set status = 'pending', decided_at = null, ended_at = null,
  requested_at = now() - interval '15 days'
where id = current_setting('test.link')::uuid;
select is(pg_temp.q(:'teacher_user', 'myLinks', null)->'links'->-1->>'status', 'expired',
  'a request left 14 days has expired');
select is(pg_temp.cmd(:'teacher_user', 'decideLink', current_setting('test.link')::uuid,
  '{"decision":"accept"}')->>'reason', 'not_pending', 'and can no longer be accepted');
select is(private.school_portal_purge(100)->>'school_portal_expired', '1',
  'the retention job marks it expired');

-- 12. The last administrator leaving closes the school's page.
select is(pg_temp.cmd(:'admin4', 'removeAdmin', current_setting('test.org2')::uuid,
  jsonb_build_object('userId', :'admin4'))->>'outcome', 'not_found',
  'a suspended school''s administrator cannot act');
select is(pg_temp.cmd(:'admin2', 'removeAdmin', current_setting('test.org')::uuid,
  jsonb_build_object('userId', :'admin1'))->>'outcome', 'ok', 'an administrator removes another');
select is(pg_temp.cmd(:'admin2', 'removeAdmin', current_setting('test.org')::uuid,
  jsonb_build_object('userId', :'admin2'))->>'outcome', 'ok', 'and then leaves');
select is((select status from private.school_portal_orgs where id = current_setting('test.org')::uuid),
  'closed', 'which closes the page');

-- 13. Export and grants.
select is(jsonb_array_length(private.data_export_document(:'teacher_user')
  ->'sections'->'schoolPortal'->'links'), 3, 'a teacher''s export lists every school request and link');
select ok(has_function_privilege('studafy_api_runtime', 'private.api062_query(text, uuid, jsonb)', 'execute')
  and not has_function_privilege('authenticated', 'private.api062_query(text, uuid, jsonb)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.school_portal_purge(integer)', 'execute'),
  'only the API calls the portal, and only the worker purges');

-- 14. A deleted account takes its portal records with it.
update private.school_portal_orgs set status = 'active', suspended_at = null
where id = current_setting('test.org2')::uuid;
update public.profiles set status = 'deleted', deleted_at = now() where id = :'admin4';
select is((select status from private.school_portal_orgs where id = current_setting('test.org2')::uuid),
  'closed', 'a school whose only administrator deletes their account closes');
select ok(not exists (select 1 from private.school_portal_views where admin_id = :'admin4')
  and not exists (select 1 from private.school_portal_lookups where admin_id = :'admin4'),
  'and their activity record and lookups go');
update public.profiles set status = 'deleted', deleted_at = now() where id = :'teacher_user';
select ok(not exists (select 1 from private.school_portal_teacher_links where teacher_id = :'teacher_user'),
  'a deleted teacher''s requests and links go');

select * from finish();
rollback;
