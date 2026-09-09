-- SEC-001 containment: authenticated clients must not upload directly until
-- immutable file metadata, ownership checks, quarantine, and scanning exist.
-- This is intentionally forward-only; do not restore the former namespace-only
-- policy in real-data environments.
drop policy if exists "private uploads own namespace" on storage.objects;
