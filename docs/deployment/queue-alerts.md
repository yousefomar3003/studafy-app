# Background-work alerts to Telegram

Launch plan 4.7. The worker watches its own queues and backlogs and sends a
Telegram message when one goes past a limit. Code:
`apps/worker/src/monitoring/` (`queueMonitor.ts`, `sources.ts`,
`sendTestAlert.ts`) and `packages/infrastructure/src/alerts/telegram.ts`.

## What it watches

| Source | Kind | Depth | Age | Failed | Stalled |
|---|---|---|---|---|---|
| `smoke`, `notifications`, `billing-events` | BullMQ queues the worker runs | waiting jobs | oldest waiting job | new failed jobs in the window | a job active longer than the stall limit, or BullMQ reporting a stalled job (its worker died holding it) |
| notification outbox | Postgres (`private.api061_outbox_backlog`) | pending + retry rows | oldest pending row | new dead letters in the window | — |
| file scan | Postgres (`private.api051_scan_backlog`) | quarantined files | oldest quarantined file | new scan or delete dead letters in the window | — |
| study notebooks | Postgres (`private.notebook_jobs_backlog`, 2026-10-16) | notebooks waiting to be written | oldest waiting notebook | new dead letters (three failed attempts, or nine minutes waiting) in the window | — |

Only queues that are switched on are watched: `notifications` with
`OPS061_NOTIFICATIONS_ENABLED`, `billing-events` with
`PAY071_BILLING_ENABLED`, file scan with `FILE051_SCAN_ENABLED`, and study
notebooks when the worker writes them (a database, the AI provider and
`AI_LESSON_TOOLS_ENABLED`).

## Thresholds (worker environment)

| Variable | Default | Meaning |
|---|---|---|
| `QUEUE_ALERTS_ENABLED` | `false` | Switches the monitor on |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | — | Required when on. The alert relay's bot and chat can be reused |
| `QUEUE_ALERT_INTERVAL_MS` | `60000` | How often it samples |
| `QUEUE_ALERT_MAX_DEPTH` | `500` | Waiting items per source |
| `QUEUE_ALERT_MAX_AGE_SECONDS` | `300` | Age of the oldest waiting item |
| `QUEUE_ALERT_MAX_FAILED_PER_WINDOW` | `10` | New failures or dead letters within the window |
| `QUEUE_ALERT_WINDOW_SECONDS` | `300` | The window for failures and stalled jobs |
| `QUEUE_ALERT_STALL_SECONDS` | `600` | A job running longer than this means a stuck worker |
| `QUEUE_ALERT_COOLDOWN_SECONDS` | `1800` | Gap between reminders while an incident lasts |

## One incident, one message

- The first time a condition is seen: `ALERT Studafy production:
  notifications queue: 812 jobs waiting (limit 500)`.
- While it lasts, a reminder once per cooldown: `STILL HAPPENING ...`.
- When it clears: `RESOLVED Studafy production: notifications depth is back
  within its limit`.

The state is kept in Redis under `studafy-<environment>:alerts:`, so with
several worker machines each message is sent once. If Redis is unreachable,
the monitor keeps alerting from its own memory and logs
`queue_alert_state_unavailable`. A failed Telegram send is logged as
`queue_alert_send_failed` and never stops the worker.

Every sample logs `queue_monitor_tick`. This line is never sampled away.

## Switching it on (owner)

1. Use the relay's bot and chat (`docs/deployment/fly-io.md`, section 5), or
   create a new bot with @BotFather.
2. Set the worker's secrets, which restarts it:
   ```sh
   fly secrets set --config fly.test.worker.toml \
     TELEGRAM_BOT_TOKEN=<token> TELEGRAM_CHAT_ID=<chat id> QUEUE_ALERTS_ENABLED=true
   ```
   For production use `--config fly.worker.toml`.
3. Send a test alert. Locally, with the two variables in your shell:
   `bun run alerts:test`. On the deployed worker:
   ```sh
   fly ssh console --config fly.test.worker.toml \
     -C "bun apps/worker/src/monitoring/sendTestAlert.ts"
   ```
   It prints `alerts:test sent to chat ...` and Telegram shows
   `TEST Studafy development: queue alerts reach this chat (...)` (the test copy runs as `development`).

## Inactive-account warnings that could not be emailed

When queue alerts are on and the retention schedule runs
(`RETENTION_SCHEDULE_ENABLED`), the hourly retention pass also reports how
many warnings to people with no school could not be emailed. While that count
is above zero, the same chat gets one `ALERT` a day, then `STILL HAPPENING`
once a day, then `RESOLVED`. It uses the same Redis state, so each message is
sent once. The message has the count only. What to do:
`docs/security/inactive-account-warnings-runbook.md`.

## Safety report alerts (DPIA D7)

A separate switch on the same bot and chat: `REPORT_ALERTS_ENABLED`
(`REPORT_ALERT_POLL_INTERVAL_MS`, default 30000). Each new safety report
sends one `SAFETY REPORT` message with the report id, kind, priority and a
hash of the school id, nothing else. It does not need
`QUEUE_ALERTS_ENABLED`; it does need `TELEGRAM_BOT_TOKEN`,
`TELEGRAM_CHAT_ID` and `DATABASE_URL`. Production has it on in
`fly.worker.toml`, so the production worker refuses to start without the
bot. On the test copy:

```sh
fly secrets set --config fly.test.worker.toml REPORT_ALERTS_ENABLED=true
```

What reviewers do with the message, and the response times, are in
`docs/security/safe043-operator-runbook.md` (Reviewing a report).

## What it cannot see

A worker that is down sends nothing. Axiom's **Worker silent** monitor
(`docs/deployment/fly-io.md`, section 6) covers that, and so does the relay's
uptime check for the API. Keep both.
