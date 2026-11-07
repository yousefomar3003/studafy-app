-- The School Portal at scale, for capacity testing (docs/operations/capacity.md),
-- on top of seed-scale.sql in the same scratch database - never a real one.
-- Pass the sizes seed-scale.sql was given, plus how many of its schools'
-- teachers link with one large school page:
--   psql -v schools=100 -v teachers=40 -v classes=60 -v big=5 -f seed-school-portal.sql
--
-- Every workspace's teachers link with one school page ("org"): org s for
-- workspace s, except the last :big workspaces, whose teachers all link
-- with org 0 - a large school (5 x 60 = 300 classes by default). Each org
-- has one administrator (pa:org), two announcements a month for a year, a
-- class group for every 12 classes (six classes each, approved), and a year
-- of activity record at 40 reads a day. Ids are md5(kind:a:b) as in
-- seed-scale.sql, so bench.ts names them without reading them back.

\set ON_ERROR_STOP on
\if :{?schools} \else \set schools 100 \endif
\if :{?teachers} \else \set teachers 40 \endif
\if :{?classes} \else \set classes 60 \endif
\if :{?big} \else \set big 5 \endif

select current_database() like '%scale%' as scratch \gset
\if :scratch
\else
  \echo 'Refusing: the database name must contain "scale".'
  \quit
\endif

set session_replication_role = replica;
set synchronous_commit = off;

create or replace function pg_temp.sid(kind text, a bigint, b bigint default 0)
returns uuid language sql immutable as $$
  select (substr(h, 1, 12) || '4' || substr(h, 14, 3) || '8' || substr(h, 18, 15))::uuid
  from (select md5(kind || ':' || a || ':' || b) as h) x
$$;

-- Which org each workspace's teachers link with.
create temporary table portal_ws as
  select s, case when s > :schools - :big then 0 else s end as org
  from generate_series(1, :schools) s;
create temporary table portal_orgs as select distinct org from portal_ws;

\echo 'school pages and administrators'
insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data)
select pg_temp.sid('pa', org), 'pa.' || org || '@scale.studafy.test',
  'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}', '{}'
from portal_orgs;
insert into public.profiles (id, display_name, locale, status, profile_completed_at,
  public_id, account_kind)
select pg_temp.sid('pa', org), 'Principal ' || org, 'en', 'active', now(),
  (8000000000 + org)::text, 'adult'
from portal_orgs;
insert into private.school_portal_orgs (id, name, country, city, kind, status, created_by, created_at)
select pg_temp.sid('org', org), 'Portal School ' || org, 'Jordan', 'Amman', 'private',
  'active', pg_temp.sid('pa', org), now() - interval '13 months'
from portal_orgs;
insert into private.school_portal_admins (org_id, user_id, job_title, agreement_version, added_at)
select pg_temp.sid('org', org), pg_temp.sid('pa', org), 'Principal',
  private.school_portal_agreement_version(), now() - interval '13 months'
from portal_orgs;

\echo 'teacher links'
insert into private.school_portal_teacher_links (org_id, teacher_id, requested_by, status,
  requested_at, decided_at)
select pg_temp.sid('org', w.org), pg_temp.sid('tu', w.s, n), pg_temp.sid('pa', w.org), 'linked',
  now() - interval '12 months', now() - interval '12 months' + interval '1 day'
from portal_ws w, generate_series(1, :teachers) n;

\echo 'announcements'
insert into private.school_portal_announcements (org_id, author_id, title, body, audience,
  classroom_ids, created_at)
select pg_temp.sid('org', org), pg_temp.sid('pa', org), 'Notice ' || k,
  'School will close early on Thursday for staff training.',
  (array['students', 'parents', 'students_and_parents', 'teachers'])[1 + k % 4],
  null, now() - (k * 15 || ' days')::interval
from portal_orgs, generate_series(1, 24) k;

\echo 'class groups'
-- A group for every 12 classes of the org, holding six of them.
create temporary table portal_classes as
  select w.org, row_number() over (partition by w.org order by w.s, c) - 1 as i,
    pg_temp.sid('cl', w.s, c) as classroom_id
  from portal_ws w, generate_series(0, :classes - 1) c;
insert into private.school_portal_groups (id, org_id, name, code_hash, derivation_salt,
  status, created_by, created_at)
select pg_temp.sid('pg', org, i / 12), pg_temp.sid('org', org), 'Grade ' || (i / 12 + 1),
  encode(extensions.digest('scale-group:' || org || ':' || i / 12, 'sha256'), 'hex'),
  'scalesaltscalesalt' || lpad((i / 12)::text, 6, '0'), 'active', pg_temp.sid('pa', org),
  now() - interval '11 months'
from portal_classes where i % 12 = 0;
insert into private.school_portal_group_classes (group_id, classroom_id, status, requested_by,
  requested_at, decided_at)
select pg_temp.sid('pg', org, i / 12), classroom_id, 'approved', pg_temp.sid('pa', org),
  now() - interval '11 months', now() - interval '11 months' + interval '1 day'
from portal_classes where i % 12 < 6;

\echo 'a year of activity record'
insert into private.school_portal_views (admin_id, org_id, classroom_id, view, at)
select pg_temp.sid('pa', o.org), pg_temp.sid('org', o.org),
  case when r % 2 = 0 then null else pc.classroom_id end,
  case when r % 2 = 0 then 'dashboard' else 'roster' end,
  now() - (d || ' days')::interval + (r || ' minutes')::interval
from portal_orgs o
cross join generate_series(1, 365) d
cross join generate_series(1, 40) r
join portal_classes pc on pc.org = o.org and pc.i = (r * 7) % :classes;

set session_replication_role = origin;
\echo 'analyze'
analyze private.school_portal_orgs, private.school_portal_admins,
  private.school_portal_teacher_links, private.school_portal_announcements,
  private.school_portal_groups, private.school_portal_group_classes,
  private.school_portal_views;
select relname, n_live_tup from pg_stat_user_tables
where relname like 'school_portal%' order by n_live_tup desc;
