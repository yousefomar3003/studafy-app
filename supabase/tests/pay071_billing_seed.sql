-- Reuse the complete multi-role DB-021 graph, then prove the billing ledger's
-- trust boundary (2026-09-19 audit H2/H4 and guardian entitlement reads).
\set auth031_fixture_only true
\ir rls_access_seed.sql
\ir db021_access_seed.sql
\unset auth031_fixture_only
\ir pay071_billing.sql
