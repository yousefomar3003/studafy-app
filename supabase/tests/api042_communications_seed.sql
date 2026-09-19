-- API-042 S4 fixture: reuse the shared DB-021/AUTH-031/API-042 graph.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set QUIET on

-- DL-049: messaging is off until a school turns it on. These suites exercise
-- messaging, so the seed school opts in explicitly.
insert into public.school_content_controls (school_id, messaging_enabled)
values ('11111111-1111-1111-1111-111111111111', true)
on conflict (school_id) do update set messaging_enabled = true;

\ir api042_communications.sql
