-- Self-contained synthetic fixture for API-040's durable idempotency proof.
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir api040_idempotency.sql
