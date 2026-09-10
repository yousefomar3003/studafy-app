# Phase 1A verification — container smoke

Evidence date: 2026-09-10. Images built from the repository root with the
pinned base `oven/bun:1.3.14-slim`; non-root `USER bun`; frozen production
install. Local Docker 29.6.2. Redis from `docker-compose.dev.yml`
(`redis:7.4.4-alpine3.21`, host port 6379); Postgres from the disposable
Supabase stack (127.0.0.1:54322) via `host.docker.internal`.

## API container — degraded mode (Redis only, no DATABASE_URL)

```sh
docker run -d --name api-smoke -p 18080:8080 \
  -e ENVIRONMENT=development -e REDIS_URL=redis://host.docker.internal:6379 studafy-api
```

| Check | Result |
|---|---|
| `GET /healthz` | `200 {"status":"ok"}` |
| `GET /readyz` | `503 {"ready":false,"reasons":["database_unreachable"]}` — Redis healthy, database unconfigured |
| `GET /version` | `200 {"service":"api","version":"0.1.0","environment":"development"}` |
| `GET /v1/me` | `404` with `{"error":{"code":"NOT_IMPLEMENTED",…,"request_id":"<uuid>"}}` |
| `docker stop` (SIGTERM) | structured `shutdown`/`signal_received` → `complete` logs; **exit code 0** |

## API container — full stack (Supabase Postgres + Redis)

```sh
docker run -d --name api-full -p 18080:8080 \
  -e ENVIRONMENT=development \
  -e REDIS_URL=redis://host.docker.internal:6379 \
  -e DATABASE_URL=postgresql://postgres:…@host.docker.internal:54322/postgres studafy-api
```

| Check | Result |
|---|---|
| `GET /readyz` | `200 {"ready":true,"reasons":[]}` |
| `docker stop` | **exit code 0** |

## Worker container

```sh
docker run -d --name worker-smoke \
  -e ENVIRONMENT=development -e REDIS_URL=redis://host.docker.internal:6379 studafy-worker
```

| Check | Result |
|---|---|
| Startup logs | `startup` (redacted config, queues list) then `worker_ready {"queue":"smoke"}` |
| Job enqueued from host into `studafy-development:smoke` | `job_processed` logged in container with `job_id`, `attempt` |
| `docker stop` (SIGTERM) | `signal_received` → `drain_workers` → `complete`; **exit code 0** |

## Negative validation

- Boundary checker: a deliberate `hono` import inside `@studafy/domain` failed
  the check with exit 1 (then removed); green state re-verified.
- Production fail-closed: see `fail-closed-2026-09-10.md`.
- CI repeats degraded-mode readiness and both SIGTERM smokes on every push
  (`.github/workflows/ci.yml` `workspace` job).
