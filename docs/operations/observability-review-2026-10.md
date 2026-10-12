# Sentry and Axiom review, October 2026

Launch plan 4.7, 2026-10-12. This review covers what the repository
configures. Dashboard settings (retention, scrubbing toggles, IP storage)
can't be read from the repo; they are listed for the owner to check.

## Fixed in this change

| Finding | Fix | Where |
|---|---|---|
| **Every deploy reported the same Sentry release** (`studafy-api@0.1.0`, `studafy-worker@0.1.0`), so an error could not be tied to the deploy that introduced it, and "resolved in next release" never worked | `releaseId()` adds the build to the version: `SENTRY_RELEASE` if set (for example a git SHA), else Fly's deployment tag from `FLY_IMAGE_REF`, which every Fly machine has. Releases now look like `studafy-api@0.1.0+deployment-01J…` | `packages/infrastructure/src/sentry.ts`, `apps/api/src/composition/platform.ts`, `apps/worker/src/index.ts` |
| **Log lines did not say which environment they came from.** The test copy and production ship to one Axiom dataset (`studafy-production`), so a monitor could fire on test traffic and a production query could count test lines | Every API and worker log line now carries `environment` and `release` | same files (`logger.child`) |
| **No alerts on BullMQ queues.** `queueStats()` existed, but nothing called it | The queue monitor and Telegram alerts | `docs/deployment/queue-alerts.md` |

## Sentry

| Area | State | Verdict |
|---|---|---|
| Per-environment DSN | One `SENTRY_DSN` secret per Fly app; `environment` comes from `ENVIRONMENT` (API, worker) and `APP_ENV` (app) | Fine |
| Release tagging, server | Fixed above | Fixed |
| Release tagging, app | `sentry_flutter` defaults to `<package>@<version>+<build>` from the app itself (`LoadReleaseIntegration`) | Fine |
| Source maps / debug symbols, server | Bun runs the TypeScript directly (`CMD bun run apps/*/src/index.ts`), so stack traces already show real files and lines | Not needed |
| Debug symbols, app | `pubspec.yaml` sets `upload_debug_symbols` and `upload_source_maps`, but no build runs `sentry_dart_plugin`, and release builds are blocked on purpose (SEC-001) | **Recommendation 1** |
| Sample rates | Server: errors only, `tracesSampleRate: 0`. App: every error, no tracing, no profiling, no replay | Fine for this size |
| PII scrubbing, server | User info, headers, cookies, bodies, query strings, DB values, queue data, AI input/output and stack variables are off; console breadcrumbs dropped; `beforeSend` masks emails, tokens and long numbers (`packages/infrastructure/src/sentry.ts`) | Fine |
| PII scrubbing, app (Dart) | `sendDefaultPii = false`; no screenshots or view hierarchy; `user` and `request` removed; text masked (`lib/core/crash_reports.dart`) | Fine |
| PII scrubbing, app (native crashes) | Native iOS and Android crashes go through the native SDKs, which the Dart `beforeSend` never sees | **Recommendation 2** |
| IP addresses | "Prevent Storing of IP Addresses" is a dashboard setting (`docs/deployment/fly-io.md` section 4) | **Owner check** |
| Retention | Set by the Sentry plan, not the repo | **Owner check**; state it in the privacy policy (§10) |

## Axiom

| Area | State | Verdict |
|---|---|---|
| Datasets | One dataset, `studafy-production`, in the EU region (`fly.log-shipper.toml`), receiving every app in the Fly organisation, including the test copy | Workable now that lines carry `environment`; **Recommendation 3** |
| Retention | 30 days per ADR-0035 and the privacy policy; set in Axiom | **Owner check** |
| Structured fields | One JSON object per line: `level`, `time`, `service`, `version`, `event`, plus fields, and now `environment` and `release`. Requests log `request_id`, route, status, duration, outcome, `user_id`, `ip_hash` and user-agent family | Fine |
| PII in logs | Names, emails, tokens, bodies and message content are redacted by key before writing (`apps/api/src/platform/logging.ts`). IPs are keyed hashes. `user_id` (account UUID) is present: pseudonymous, and declared in the store answers and the policy | Acceptable; **Recommendation 4** |
| Sampling | About 10% of successful requests and 1% of routine polling kept; errors, slow requests, backlog heartbeats and `queue_monitor_tick` always kept (`packages/observability/src/sampling.ts`) | Fine |
| Shipper image | `ghcr.io/superfly/fly-log-shipper:latest`, not pinned | **Recommendation 5** |
| Monitors | API errors, API slow, notifications stuck, uploads failing to scan, worker silent (`docs/deployment/fly-io.md` section 6) | Fine; **Recommendation 3** |

## Recommendations, in order

1. **App debug symbols.** When release builds are allowed (lifting SEC-001),
   build with `--obfuscate --split-debug-info=build/symbols` and run
   `dart run sentry_dart_plugin` in the release workflow, with
   `SENTRY_AUTH_TOKEN` as a CI secret. Without it, obfuscated release crashes
   are unreadable. Keep `sentry.properties` out of git; it already is
   (`.gitignore`).
2. **Native crash privacy.** Check one real native crash from a test build
   in Sentry. If it carries a `user.id` (an installation id) or an IP,
   either set a constant user from Dart at start-up, which syncs to the
   native scope (`Sentry.configureScope((s) => s.setUser(SentryUser(id:
   'anonymous')))`), or turn off native crash handling for children's
   builds. The App Store label "crash data not linked to the user" depends
   on this.
3. **Environment in the monitors.** Once production is live, add
   `and m.environment == "production"` to each Axiom monitor query. Or
   point the test copy at a second dataset (`studafy-test`) through a second
   shipper or a Vector filter, so test traffic never wakes anyone.
4. **`user_id` in request logs.** Keep it: it is how a support question is
   traced. If the DPIA prefers otherwise, log a keyed hash instead, the same
   way `ip_hash` is made.
5. **Pin the log shipper** to a digest (`fly image show --config
   fly.log-shipper.toml`), so a new upstream image can't change where logs go
   without review.
6. **Remove the CloudWatch sink.** AWS is no longer used (handoff: delete the
   AWS key). The optional sink in `apps/api/src/composition/platform.ts` and
   `packages/infrastructure/src/cloudwatchLogs.ts` is dead weight and one
   more place logs could leak to.
