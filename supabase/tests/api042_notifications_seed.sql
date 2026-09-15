-- API-042 S6 fixture: reuse the shared graph.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set QUIET on

\ir api042_notifications.sql
