# ADR-0001: Modular monolith target architecture

Status: Accepted (provisional on Phase 1 pinning proofs). Decision-log: DL-005.
Date: 2026-09-10.

## Context

Studafy is a Flutter app with Supabase (Auth, PostgreSQL, Storage, Deno Edge
Functions). The audit (instructions.md §3) found the Edge Functions lack shared
validation, idempotency, transactions, and observability, and that a
microservice split is not justified at current scale. Eight Deno functions
already duplicate auth/bootstrap logic.

## Decision

Adopt a **modular monolith** as the target server architecture:

- Containerised **Bun + Hono API** in `apps/api` with shared middleware
  (request ID, auth, tenant, limits, errors, logging) and domain modules.
- Long-running **Bun + BullMQ workers** in `apps/worker`; workers are separate
  deployments, not microservices.
- **Supabase remains authoritative**: PostgreSQL + RLS, Supabase Auth, private
  Supabase Storage.
- **Redis** for rate limiting, selected caches, idempotency coordination, and
  BullMQ queues.
- **Cloudflare** in front of the API (DNS, TLS, CDN, WAF, bot controls). BullMQ
  workers never run in Cloudflare Workers.
- Migrate each Deno Edge Function to an equivalent versioned Hono route only
  after contract, authorization, idempotency, and rollback tests pass; keep
  only explicitly justified Supabase hooks.

## Consequences

- One monorepo, one deployable API plus workers: simpler observability and
  transactions than microservices, with module boundaries preserving future
  extraction options.
- **Provisional commitments to prove in Phase 0/1 before this becomes
  binding:** exact Bun/Hono/BullMQ/Redis version pins; queue semantics,
  reconnect behaviour, duplicated blocking connections, graceful shutdown, and
  the selected Redis provider under load.
- Deno remains the runtime for the eight existing Edge Functions until each is
  migrated route-by-route behind feature flags with compatible contracts.
- Separate services are introduced only when a domain needs independent
  scaling/security/release ownership that modules cannot provide.
