-- Self-contained local AUTH-031 fixture: reuse the reviewed DB-021 synthetic
-- graph, then run the API/RLS parity assertions against those exact rows.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir auth031_authorization.sql
