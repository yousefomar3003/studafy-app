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

## Fixed on 2026-10-14

| Finding | Fix | Where |
|---|---|---|
| **Native crashes carried a per-install id** (recommendation 2). Checked in the SDK sources `sentry_flutter` 9.30.1 ships (sentry-android 8.56.0, sentry-cocoa 8.58.4). The app never sets a user, so on iOS a crash report gets `user.id` = the installation id (`SentryClient.m` `setUserIdIfNoUserSet`, run for fatal events too). On Android every Java, NDK, ANR and tombstone event gets it as `user.id` (`DefaultAndroidEventProcessor.mergeUser`) and as `device.id` (`DeviceInfoUtil`), and sessions carry it as `did` on both platforms (`AndroidOptionsInitializer`, `SentryHub.m`). None of these pass through the Dart `beforeSend`. On Android the Dart events had it too: the native device context, `id` included, is copied into them | Three layers. (1) A constant user `anonymous` is set from Dart at start-up; scope sync copies it to the native SDKs, so native crashes carry it rather than the installation id. (2) The Dart `beforeSend` drops `device.id` and `device_unique_identifier`. (3) Before Dart starts, the native apps write one shared all-zero value to the file the SDKs read their installation id from (`files/INSTALLATION`, `Caches/INSTALLATION`), so `device.id`, the `user.id` fallback and session `did` are the same for every install. A native `beforeSend` was not an option: `sentry_flutter` starts the native SDKs from Dart and sets their `beforeSend` itself, and a hook added afterwards would race the upload of the previous run's crash. A test pins the `sentry_flutter` version so an upgrade forces a re-check of (3). Still worth one look at a real native crash from a test build | `lib/core/crash_reports.dart`, `test/core/crash_reports_test.dart`, `android/app/src/main/kotlin/com/studafy/light/MainActivity.kt`, `ios/Runner/AppDelegate.swift` |
| **Dead CloudWatch sink** (recommendation 6) | Removed: the sink, its test, the `@aws-sdk/client-cloudwatch-logs` dependency, `AWS_REGION` / `AWS_LOG_GROUP` from the API config, the env examples and the start-up summary. Logs leave only through stdout and the Fly log shipper to Axiom | `packages/infrastructure`, `apps/api/src/composition/platform.ts`, `apps/api/src/index.ts`, `packages/config`, `.env.example`, `.env.hosted.example` |
| **Log shipper on a floating tag** (recommendation 5) | Pinned to `ghcr.io/superfly/fly-log-shipper:latest@sha256:844d0847…c642` (the image `latest` pointed at on 2026-10-14, a single linux/amd64 manifest), with how to update it; `scripts/fly-config.test.ts` fails on an unpinned image. Takes effect on the next `fly deploy --config fly.log-shipper.toml` | `fly.log-shipper.toml`, `docs/deployment/fly-io.md` |

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
| PII scrubbing, app (native crashes) | Native iOS and Android crashes go through the native SDKs, which the Dart `beforeSend` never sees. They now carry a constant user and a shared installation id (above) | Fixed 2026-10-14 |
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
| Shipper image | Pinned to a digest (above) | Fixed 2026-10-14 |
| Monitors | API errors, API slow, notifications stuck, uploads failing to scan, worker silent (`docs/deployment/fly-io.md` section 6) | Fine; **Recommendation 3** |

## Recommendations, in order

1. **App debug symbols.** When release builds are allowed (lifting SEC-001),
   build with `--obfuscate --split-debug-info=build/symbols` and run
   `dart run sentry_dart_plugin` in the release workflow, with
   `SENTRY_AUTH_TOKEN` as a CI secret. Without it, obfuscated release crashes
   are unreadable. Keep `sentry.properties` out of git; it already is
   (`.gitignore`).
2. **Native crash privacy.** *Done 2026-10-14 (above); one real native
   crash from a test build is still worth a look.* Check one real native
   crash from a test build in Sentry. If it carries a `user.id` (an installation id) or an IP,
   either set a constant user from Dart at start-up, which syncs to the
   native scope (`Sentry.configureScope((s) => s.setUser(SentryUser(id:
   'anonymous')))`), or turn off native crash handling for children's
   builds. The App Store label "crash data not linked to the user" depends
   on this.
3. **Environment in the monitors.** *Still open: production does not
   exist yet.* Once production is live, add
   `and m.environment == "production"` to each Axiom monitor query. Or
   point the test copy at a second dataset (`studafy-test`) through a second
   shipper or a Vector filter, so test traffic never wakes anyone.
4. **`user_id` in request logs.** Keep it: it is how a support question is
   traced. If the DPIA prefers otherwise, log a keyed hash instead, the same
   way `ip_hash` is made.
5. **Pin the log shipper** to a digest (`fly image show --config
   fly.log-shipper.toml`), so a new upstream image can't change where logs go
   without review. *Done 2026-10-14 (above); redeploy the shipper to apply.*
6. **Remove the CloudWatch sink.** AWS is no longer used (handoff: delete the
   AWS key). The optional sink in `apps/api/src/composition/platform.ts` and
   `packages/infrastructure/src/cloudwatchLogs.ts` is dead weight and one
   more place logs could leak to. *Done 2026-10-14 (above).*
