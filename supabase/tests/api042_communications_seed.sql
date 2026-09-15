-- API-042 S4 fixture: reuse the shared DB-021/AUTH-031/API-042 graph.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set QUIET on

\ir api042_communications.sql
