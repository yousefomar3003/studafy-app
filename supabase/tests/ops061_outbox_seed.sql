-- OPS-061 fixture: reuse the shared graph.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only

\set QUIET on

\ir ops061_outbox.sql
