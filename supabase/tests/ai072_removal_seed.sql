-- Reuse the complete multi-role DB-021 graph, then prove AI-072's removal.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir ai072_removal.sql
