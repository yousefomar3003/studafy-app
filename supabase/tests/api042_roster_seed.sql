-- API-042 S9 fixture: reuses the shared graph for the forbidden-actor cases,
-- and adds one genuinely term-less school so createTerm can be proven to
-- unblock createClassroom for a school that starts with zero terms - the
-- exact gap this slice closes.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set fresh_school_id 'a04b0000-0000-4000-8000-000000000001'

\set QUIET on

insert into public.schools (id, name, timezone, status) values
  (:'fresh_school_id', 'API-042 S9 Roster Fixture School', 'Asia/Riyadh', 'active')
on conflict (id) do update set status = 'active';

insert into public.memberships (school_id, user_id, role, active, status, version) values
  (:'fresh_school_id', :'admin_user', 'school_admin', true, 'active', 1)
on conflict (school_id, user_id, role) do nothing;

\ir api042_roster.sql
