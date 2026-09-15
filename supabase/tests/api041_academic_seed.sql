-- Reuse the complete multi-role DB-021 graph, then exercise API-041.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir api041_academic.sql
