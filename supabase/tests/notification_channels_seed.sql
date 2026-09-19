-- Reuse the multi-role DB-021 graph, then prove the DL-053 channel fan-out.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir notification_channels.sql
