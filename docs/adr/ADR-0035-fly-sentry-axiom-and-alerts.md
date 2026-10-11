# ADR-0035: Fly.io hosting, Sentry errors, Axiom logs, and Telegram alerts

- Status: Accepted
- Date: 2026-10-02
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Supersedes: the AWS App Runner plan (`docs/deployment/aws-app-runner.md`)
- Relates to: OPS-090 (observability gap in `docs/governance/decision-log.md`),
  ADR-0024 (Redis posture), ADR-0025 (outbox), ADR-0034 (launch plans)

## Context

There was no production metrics, alerting or central logging pipeline
(OPS-090). On 2026-10-02 in-app notifications had silently stopped
delivering for every role. The worker's notification queue was switched
off, and nothing noticed until a person did.

The owner's goals:

1. know when something breaks, and be able to find out why;
2. keep cost low: do not store every log line;
3. receive alerts by email and Telegram.

AWS (App Runner with CloudWatch) was the earlier plan. For one API and one
worker it costs more, through the load balancer, NAT and CloudWatch ingest,
and is more to operate.

## Decision

### Hosting: Fly.io, Frankfurt

- `fly.api.toml`, `fly.worker.toml` and `fly.log-shipper.toml` sit at the
  repository root.
- The region is `fra`. The Supabase database moves to `eu-central-1` before
  launch: it is in Tokyo today, about 1 s per request away from the region's
  users.
- The API keeps one warm machine and starts more past 200 concurrent
  requests per machine. Idle machines stop. Routing health is `/healthz`.
  Dependency health (`/readyz`) is watched by the uptime alert, so a short
  database blip does not pull every machine at once.
- The worker runs one always-on machine.
- `scripts/fly-config.test.ts` loads each config through the production
  validation in CI, so a broken config fails before deploy.

### Logs: sampled at the source, shipped to Axiom

`createLogSampler` (`packages/observability/src/sampling.ts`) decides per line:

- **always kept:** warnings, errors, every 4xx/5xx, every request of at least
  `LOG_SLOW_REQUEST_MS`, heartbeats, money and account-rights events;
- **dropped:** `/healthz` and `/readyz` successes;
- **sampled:** ordinary successes and routine job completions at
  `LOG_SAMPLE_SUCCESS_RATE` (production 0.1), and the unread-badge poll at
  `LOG_SAMPLE_ROUTINE_RATE` (0.01).

A sampled line carries `sample_rate`. The defaults keep everything, so local
and test runs are unchanged. Retention is 30 days. Expected volume is roughly
80–90% lower than unsampled. Audit history is in the database and is not
affected.

Fly's log shipper forwards stdout to Axiom.

### Errors: Sentry, with personal data off at every layer

- **API:** reports unexpected exceptions with their stack from the error
  handler.
- **API and worker:** turn every error-level log line into one issue per
  service, event and code.
- **Flutter app:** reports crashes. It is on only when the build carries
  `SENTRY_DSN`.

Most users are children, so Sentry's own data collection is switched off
entirely: user info, headers, cookies, query strings, bodies, database
values, queue arguments, AI I/O and stack-frame variables. So are
screenshots, printed lines and tap breadcrumbs in the app. Emails, long
numbers and tokens are masked in any text. Tests pin each of these.

### Alerts: email and Telegram

- Sentry alerts on new issues and spikes.
- Axiom alerts on patterns no exception shows: server errors over 5 in
  5 minutes, slow requests, notifications stuck in the outbox, uploads
  failing to scan, and a silent worker.
- Both email natively, and both send webhooks to `ops/alert-relay`, a
  Cloudflare Worker that forwards them to Telegram.
- The relay also checks `/readyz` every minute from outside Fly. It alerts
  once when the API goes down and once when it recovers, by Telegram and
  email (Resend).

The queries and setup are in `docs/deployment/fly-io.md`.

## Consequences

- Fly.io, Axiom and Sentry become processors in the privacy policy (§7.2).
  Their DPAs and EU regions are publication items (Appendix A).
- Production depends on things this change does not provide:
  - a TLS Redis;
  - the malware-scanner vendor (still unchosen; the worker refuses to start
    without it);
  - the Frankfurt database.
- Cost at launch is about $10–20 a month for Fly. Sentry, Axiom, Cloudflare
  and Telegram are free at this size.
- CI now runs the `scripts/` and `ops/` tests and type-checks the relay.
