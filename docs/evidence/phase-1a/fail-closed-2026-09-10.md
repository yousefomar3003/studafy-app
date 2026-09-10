# Phase 1A verification — production fail-closed

Evidence date: 2026-09-10. Command and result:

```sh
$ ENVIRONMENT=production bun apps/api/src/index.ts   # no DATABASE_URL / REDIS_URL
ConfigError: Production requires DATABASE_URL and REDIS_URL to be configured.
# process exit code: 1
```

The API refuses to start in production without its authoritative dependencies
(`packages/config` `enforceApiFailClosed`). Non-production environments may
start degraded and report the missing dependencies as `/readyz` reason codes
instead (proven in the container smoke: degraded run returned
`503 {"ready":false,"reasons":["database_unreachable"]}`).
