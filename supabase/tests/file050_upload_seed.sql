-- Reuse the complete synthetic multi-school graph, then exercise FILE-050.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir file050_upload.sql
