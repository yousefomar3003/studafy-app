# Handoff: Studafy

Updated: 2026-10-16. `main` is at `c6c309f`. **Everything from PRs #52–#82
is merged and on the test copy.** No PR is open apart from the three in
progress below.

## Start here (2026-10-16)

### What happened today
- **Merged:** #52–#77 through the merge batch #79 (CI all green; conflicts
  resolved there), then #78 (notebooks on the worker), #80 (store decisions,
  questions for counsel) and #82 (test fix). The stacked PRs #62, #63, #65,
  #74 and #77 show "closed": their commits reached `main` through #79.
- **Test copy deployed from `main`:** backup with restore check, then 19
  migrations (`202610140001` … `202610160001`; #47's and #48's had never been
  applied), then `studafy-api-test` (`/readyz` ready), `studafy-worker-test`
  (`REPORT_ALERTS_ENABLED=true` set as a Fly secret) and the log shipper.
- **Log shipper repaired.** Its `ACCESS_TOKEN` was the org token revoked on
  2026-10-14, so it could not reconnect after a restart (NATS "Authorization
  Violation"). It now uses a read-only org token,
  `studafy-log-shipper-readonly-2`; Vector started 11:19 UTC.
- **Backups go to Cloudflare R2.** Bucket `studafy-backups`, EU
  jurisdiction, lifecycle rule `delete-after-30-days` on `studafy/`; the
  five `BACKUP_OFFSITE_*` secrets are in the `backups` environment. Run
  38896690730 uploaded the encrypted backup and verified it by sha256
  read-back; no backup artifact is kept any more (only a small manifest).
  The R2 key is in `~/studafy-secrets/r2-backups.env`.
- **Reviewer school on the test copy:** "Cedar Grove Review School"
  (`c760d0d5-…`), three accounts at `review.studafy.com`; passwords only in
  `~/studafy-secrets/reviewer-credentials.json`. Signing in with them through
  the API worked, so the Supabase email settings are right.
- **Redis Cloud check answered:** it refuses `CONFIG GET` for these
  settings; the worker read `INFO` instead (`noeviction`, AOF on) and passed.
  A production Redis Cloud database set up the same way will pass.

### Owner: to do
1. **Revoke the exposed Fly token** (it was pasted in chat):
   `fly tokens revoke QnxexwKQqRD5KuwGnlkAqPnOXJCA4RBP0N162bahkA`
   (the old `studafy-log-shipper-readonly`; keep `-2`).
2. **Build the phone app from `main`.** The test copy now asks for policy
   version `2026-10-14` and for AI consent; older builds cannot answer the
   AI consent prompt. New: "Sign in with email" (reviewers), refusal
   messages that name the file, Western digits in Arabic dates.
3. **Old public backup artifacts:** encrypted backups from before
   2026-10-16 are still downloadable from the public repo until they expire
   (up to 30 days). Delete them, or let them expire (R2 holds only today's
   backups so far).
4. **Name two safety-report reviewers** (B9) in
   `docs/security/safe043-operator-runbook.md`.
5. **Production Redis:** a paid Redis Cloud plan, data persistence AOF every
   1 s, eviction policy `noeviction`.
6. **Seoul Supabase project:** "studafy" in ap-northeast-2 (created
   2026-06-17) is still active. Keep or delete?
7. **Lawyers:** send them `docs/legal/questions-for-counsel-2026-10.md`
   and the DPIA draft; keep their answers out of the repo (it is public).
8. **Store listings (B12):** paste from `docs/store/listing-copy.md` as
   decided there, and the reviewer accounts as
   `docs/store/reviewer-access.md` says.
9. The rest of parts B and C of the launch plan (keystore C1, Firebase C3,
   Resend C5, production decisions B1–B3…).

### In progress at writing (check `gh pr list`)
- `study_lesson` capacity (`feat/capacity-study-lesson`): the access check
  as a set query, with the zero-difference proof.
- Western digits in the Material date and time pickers
  (`fix/arabic-picker-digits`).
- Android screenshots for Play, 2:1 or less (`docs/play-screenshots`).

### Next for Claude
- Review and merge those three PRs; `study_lesson` needs a backup and its
  migration on the test copy.
- Tick 2.8 once a lesson saved on the phone with a refused file names it.
- Look into `outbox_dispatch_record_lost` (outbox 25, 12:00 UTC on
  2026-10-16, before the worker deploy): a dispatch the worker lost track of.
- Follow-ups still open: accounts with neither school nor email are never
  warned or deleted; retention periods for the items in the questions for
  counsel; two-person operator grants need a second operator;
  `GoogleService-Info.plist` must be added to the Runner target when it
  arrives (C3).
- Then part A/C of the launch plan as your decisions and accounts arrive.

### Rules (unchanged, plus today's)
- Test only on throwaway stacks. Never the local working database (54322,
  container `supabase_db_studafy`) or its Auth (54321). The repo `.env`
  points `DATABASE_URL` at it and Bun loads it; set `DATABASE_URL`, and for
  the password-session suite `AUTH_INTEGRATION_SUPABASE_URL`, explicitly.
- `scripts/rehearse-recovery.ts` now follows `DATABASE_URL` (#66), but
  check any script that picks Docker containers by name before running it.
- New migrations must sort after everything on `main`
  (`bun run check:migrations`); rename before merging if `main` moved on.
- Hosted: back up before any migration (`gh workflow run backup.yml`), dry
  run, then apply; deploy the API, then the worker.
- Hosted migrations: `.env.hosted`'s `DATABASE_URL` is the transaction
  pooler (6543); `supabase db push` needs the session port (5432). Read it
  with a parser that never prints it; never `source .env.hosted`.
- Secrets never go in chat. Owner-created keys go in `~/studafy-secrets/`
  and only the path is shared. Claude's tools are not allowed to write
  secret stores (GitHub, Fly); the owner runs those commands.
- Keep `ios/Runner.xcodeproj/project.pbxproj` (personal team) and
  `ios/Runner/RunnerPersonalTeam.entitlements` uncommitted.
- Ask before any `fly` command that changes something.

## Earlier (2026-10-15, evening): the PRs that became the merge batch (all done 2026-10-16; kept for the record)

Claude worked through every part-A item of the
[launch plan](docs/planning/launch-plan-2026-10-15.md) that needed nothing
from the owner, then the gaps those turned up. Everything is a PR; none is
merged.

### 1. Owner: do these first
1. **Publish the notebook-queue branch.** The auto-mode classifier blocked
   Claude's push, so the work exists only locally (commit `7e9d019`,
   branch `feat/notebooks-on-worker`, in
   `.claude/worktrees/agent-a3342e6f363071b09`):
   `cd .claude/worktrees/agent-a3342e6f363071b09 && git push -u origin feat/notebooks-on-worker && gh pr create --base main --fill`.
   Don't delete that worktree before pushing.
2. **Review and merge, in this order** (stacked PRs: retarget the next one
   to `main` after the one below it merges):
   1. #54 (this handoff, DL-058) first: #61 adds DL-059 and #72 DL-060 to
      the same table.
   2. #55 → #63 → #74 (file refusals).
   3. #53 → #65 → #77 (capacity).
   4. #61 → #62 (Android internal-testing build; #61 changes the SEC-001
      guards and needs your explicit approval; #62 declares
      `ITSAppUsesNonExemptEncryption = false` — confirm that is true for
      your export-compliance answer).
   5. The rest in any order: #52, #56–#60, #64, #66–#73, #75, #76, the
      notebook-queue PR.

   Expected conflicts, all mechanical (ask Claude to rebase the PR GitHub
   flags): the decision-log table; `fly.worker.toml` (#56, #69, #71,
   notebook queue); the pgTAP step list in `.github/workflows/ci.yml` (keep
   every added step, in timestamp order); the `.arb` files and the generated
   l10n files (#55, #63, #68, #74, #75, #76: rerun `flutter gen-l10n`);
   `auth030_grants.sql`. #60 and #75 work in either order.
3. **Then say "go" for the test-copy deploy batch** (section 3).
4. **Decide and do** (details in each PR):
   - **Backups (#69):** you keep the repo public, so backups move to an
     off-site EU bucket. Create a Cloudflare R2 bucket (EU jurisdiction,
     30-day lifecycle on `studafy/`) and a token for it only, then set
     `BACKUP_OFFSITE_ENDPOINT`, `_BUCKET`, `_ACCESS_KEY_ID`,
     `_SECRET_ACCESS_KEY`, `_REGION` in the `backups` environment (click
     steps in `docs/deployment/backups.md`). Until then artifacts are kept 7
     days, not 30. Before turning it on, the privacy policy §7.2 must list
     Cloudflare R2.
   - **Reviewer accounts (#75):** Supabase dashboard settings are in
     `docs/store/reviewer-access.md` (keep sign-ups on; CAPTCHA off). After
     the migration, approve
     `bun --no-env-file scripts/provision-reviewer-school.ts --target hosted --credentials-out ~/studafy-reviewer-credentials.json`.
     Point mail for `review.studafy.com` at a mailbox you read. Repeat on
     production before the first store submission.
   - **Safety reports (#71):** name at least two reviewers (B9) in the
     runbook table; set `REPORT_ALERTS_ENABLED=true` on the test worker.
   - **Production Redis:** a paid Redis Cloud plan with AOF every 1 s and
     `noeviction` (the free plan has no persistence). After the test deploy,
     check the worker's `queue_redis_posture` log line says the check
     passed (Redis Cloud's INFO via its proxy is unconfirmed).
   - **Store copy (#64):** the eight decisions at the top of
     `docs/store/listing-copy.md` (AI blocks, messaging, Arabic name,
     title…). The screenshots are iPhone only; Play needs an Android set or
     crops.
   - **Lawyers:** the DPIA draft (#57) §12–13, plus: the AI consent notice
     text and who consents for 13–17-year-olds (#76, ADR-0043); 30 days for
     helper photos and the export's exclusions (#72, DL-060); policy text
     updates — §6 photos go to the AI as they are, §7.2 processors
     (Telegram, the alert relay, R2) and the stale outside-scanner row, §10
     helper photos, §11 the export lists files rather than including them.
   - Still open from before: B-list of the launch plan (phone check, Axiom
     30 days, meetings, named owners, Apple, keystore C1, Firebase C3…).

### 2. What each PR does

| PR | Launch plan | What |
|---|---|---|
| #52 | — | Observability: no install id on native crashes, CloudWatch removed, log shipper pinned (earlier) |
| #53 | 4.8 | Capacity fixes 1–3 (earlier) |
| #54 | — | This handoff, the launch plan, work-plan ticks (4.8, 5.5, 7.1, 7.2), DL-058 |
| #55 | — | PDF scan fix and scan messages (earlier) |
| #56 | A6 | Production Fly configs: `fly.scanner.toml`, rules pinned by tests, deploy checklist in `docs/deployment/fly-io.md` |
| #57 | A5 | Draft DPIA, `docs/legal/dpia-draft.md` (public repo: keep counsel's annotated copy outside it) |
| #58 | DPIA D12 | Rate-limit Redis keys hold an HMAC of the IP, not the address |
| #59 | A7 | Owner guides, `docs/guides/owner/` (C1–C16, B11, B12) |
| #60 | A10 | Synthetic school seed; backend device tests in CI on Linux (~12 min) |
| #61 | A3 / 3.5 | Android release bundle only for `APP_ENV=development`; iOS and production stay blocked; upload key via `STUDAFY_ANDROID_KEY_PROPERTIES`, no debug-key fallback (ADR-0042, DL-059) |
| #62 | — | Release docs say `com.studafy.light`; iOS exempt-encryption key |
| #63 | A9 / 2.8 | `ATTACHMENT_REFUSED` (422) names the refused file or link; the editor marks it |
| #64 | A4 | Store listing copy EN/AR with limit checks; 30 iPhone screenshots |
| #65 | A8 | Capacity 4–5: lessons and conversations a page at a time (about 4× cheaper per call) |
| #66 | — | `scripts/rehearse-recovery.ts` targets the container behind `DATABASE_URL` (see incident below) |
| #67 | — | Device tests: per-test limit and one retry for a hang |
| #68 | — | Arabic: app name, plan names, time zone layout, صف/صفوف for class, Western digits in every date (glossary `docs/l10n/arabic-glossary.md`) |
| #69 | — | Off-site EU backups (R2/S3), 7-day artifacts until then; Redis posture falls back to INFO |
| #70 | — | Play voided purchases; Play Pub/Sub names pinned; `scripts/send-test-email.ts` |
| #71 | DPIA D7 | Telegram alert per safety report (no content); audited `scripts/review-report.ts` |
| #72 | DPIA D6, D13 | Export v2 (exam answers, hand-ins, file list, voice notes, received messages, mark/attendance history, AI usage); helper photos deleted after 30 days (DL-060) |
| #73 | — | Inactive-account warning always emailed (once); accounts without a school follow the schedule |
| #74 | — | Hand-ins, messages, announcements, materials refuse scan-refused files; removed files say so; a forbidden attachment rolls the message back |
| #75 | — | "Sign in with email" for Studafy-provisioned accounts; new email sign-ups refused; review school script |
| #76 | DPIA D1–D4 | AI only for students in a class; separate AI consent (parent for managed children); names replaced before the model (ADR-0043) |
| not pushed | capacity | Notebook writing on the worker queue (`feat/notebooks-on-worker`) |
| #77 | capacity | Capacity fix 6: the grades list a page at a time, about 2.5× cheaper per call, zero differences; throughput change within noise (`docs/capacity/2026-10-16.md`) |

### 3. The test-copy deploy batch (Claude, after the merges and your "go")
1. Back up: `gh workflow run backup.yml`, and wait for the restore check.
2. `bunx supabase db push --db-url <hosted, port 5432> --dry-run`, then for
   real. Timestamps interleave across PRs, so if some were applied earlier
   use `--include-all`. New: `202610140003`–`005`, `202610150001`–`002`,
   `…0010`, `…0020`, `…0021`, `…0030`, `…0040`, `…0050`, `…0060`, `…0070`,
   `…0080`, `…0090`, `…0091`.
3. Straight after: `fly deploy --config fly.test.api.toml`, then
   `fly.test.worker.toml`, then `fly.log-shipper.toml`. For a few minutes
   between the migrations and the new API, attachment refusals and AI
   ledger refusals answer 500; that is acceptable on the test copy. (#63
   and #76 each give an ideal order; they conflict, and the batch avoids
   a longer gap.)
4. Set `REPORT_ALERTS_ENABLED=true` on the test worker (needs your go).
5. Check: `/readyz`; worker startup (`queue_redis_posture`, notebook
   processor on); one notebook end to end; a lesson with a refused file
   shows the file's name.
6. Build the phone app from `main` (new email sign-in, AI consent, refusal
   messages). Older builds get `AI_CONSENT_REQUIRED` with no way to consent.
7. Tick 2.8 when a refused-file save shows the named file on the test copy.

### 4. Incident (2026-10-15)
While running the CI-order checks for #65, `scripts/rehearse-recovery.ts`
picked the owner's local working database container by project name
instead of the throwaway one in `DATABASE_URL`. It took a `pg_dump` of
`postgres`, created and dropped `studafy_db020_recovery`, and deleted the
dump; the agent reports nothing of the owner's data was written. Nobody
inspected that database afterwards. Until #66 merges, **never run that
script on this Mac.**

### 5. Next for Claude (after the deploy batch)
- Rebase PRs GitHub reports as conflicting, in the merge order above.
- Follow-ups found today:
  - Material date and time pickers still draw Arabic-Indic digits (#68
    note).
  - Accounts with neither a school nor an email are never warned, so never
    deleted (#73 note).
  - Retention periods missing for: safety reports and evidence, unaccepted
    invitations, the AI usage ledger, export request rows, scan `error`
    files (#72; counsel).
  - Two-person operator grants need a second named operator (B9).
  - Android screenshots for Play (emulator pass, or crops of the iPhone
    set).
  - `GoogleService-Info.plist` must be added to the Runner target when the
    Firebase file arrives (C3).
  - Capacity: `study_lesson` (about 5%): its cost is the access check
    `can_view_resource_publication`, which needs restating as a set query
    with its own proof.
- Then part A of the launch plan as decisions arrive (C-steps), and Axiom
  monitors by environment once production exists.

### Rules (unchanged, plus today's)
- Test only on throwaway stacks; never the local working database (54322,
  container `supabase_db_studafy`). The repo `.env` points `DATABASE_URL`
  at it and Bun loads it, so set `DATABASE_URL` explicitly.
- Never run `scripts/rehearse-recovery.ts` here until #66 is merged.
- `supabase db reset` on a throwaway stack wipes every database in it,
  including the 11M-row `studafy_scale`.
- Hosted: read-only, only when needed; back up before any migration.
- Keep `ios/Runner.xcodeproj/project.pbxproj` (personal team) and
  `ios/Runner/RunnerPersonalTeam.entitlements` uncommitted.
- Read `.env.hosted` with a parser that never prints values; never
  `source` it.
- Ask before any `fly` command that changes something.
- Throwaway stacks on this Mac: `studafy-guardianann` (55721/55722),
  `studafy-offgrade` (55621/55622), `studafy-securityfix` (55421/55422)
  run; the agents' stacks (`a9fix` 5582x, `reviewer` 5592x, `aiaccess`
  5602x, `ops` 5612x, `billing` 5622x) are stopped. Their workdirs were in
  the session scratchpad and may be gone; recreate one from
  `supabase/config.toml` with a new `project_id` and ports.
- Agent worktrees sit in `.claude/worktrees/`. `.claude/` is untracked:
  don't commit it. Remove each worktree with `git worktree remove` once its
  PR merges.

## Earlier (2026-10-15, morning): the launch plan and PRs #52–#55

**The launch plan: [`docs/planning/launch-plan-2026-10-15.md`](docs/planning/launch-plan-2026-10-15.md).**
Everything left before the Play Store and the App Store, split by who does
it:
- **A. Claude without you:**
  - after the merges: the test deploys;
  - ticking finished items;
  - the Android internal-testing release change (needs your approval);
  - store listing copy and screenshots;
  - a draft DPIA;
  - production configs;
  - guides for your steps;
  - the next capacity round.
- **B. Only you:**
  - decide AI at launch, the production database (a new Supabase project on
    Pro) and the domains;
  - merge #52–#55;
  - the phone check;
  - Axiom retention;
  - meetings yes or no;
  - named owners;
  - the lawyers' open questions;
  - Apple;
  - the store listings.
- **C. You start, Claude finishes:**
  - the upload keystore and release SHA-1;
  - Firebase;
  - Resend;
  - Play and App Store billing products;
  - the production Supabase project and its sign-in providers;
  - DNS, Turnstile and backup storage;
  - approving production deploys and key rotation;
  - Sign in with Apple and the APNs key;
  - the TestFlight and Play uploads.
- **D. Launch day:** remove the release blocks (SEC-001), the go-live
  checklist, then the production retention purge.

The fastest route to a store is Android internal testing on the test copy:
merge, then the keystore, SHA-1 and Firebase, while Claude allows the
internal-testing release build.

**Done since 2026-10-13** (the owner's list and Claude's work)
- **Security:** the leaked Fly token was rotated; Sentry scrubs data and
  stores no IP addresses for the whole organization; both runtime roles
  have passwords and the test apps connect as them (no
  `database_privileged_role`); the `postgres` password was reset; Redis is
  a TLS Redis Cloud database in Frankfurt (no `redis_plaintext_remote`).
  Launch plan 2.3–2.5 are ticked.
- **App ID:** `com.studafy.light` (DL-058, launch plan 3.1). The link scheme
  stays `io.studafy.app`.
- **Malware scanner:** self-hosted ClamAV, `studafy-scanner-test`, private
  network only; the test worker uses it; tested end to end (PRs #50, #51).
- **Retention and policy:** the retention schedule (DL-057, PR #47; the
  purge is behind `RETENTION_SCHEDULE_ENABLED`); privacy policy 1.4 approved
  by counsel in both languages and live; the in-app text and consent version
  `2026-10-14` (PR #48).
- **Cleanup:** `studafy-api` holds no secrets, `studafy` is destroyed, deploy
  tokens are per app, the stray local Fly files are gone. AWS was dropped.
- **CI:** the iOS simulator job runs on `main` only (PR #49).

**Open pull requests (Claude, 2026-10-15)**
- **#55 PDFs and scan messages** (`fix/pdf-stream-filter`). A teacher's
  PDFs were refused as "malformed", for two reasons:
  - a small compressed part just before an image was misread;
  - ReportLab, the usual way Claude makes PDFs, writes every part as
    `[ /ASCII85Decode /FlateDecode ]`, which the check could not decode.

  Both are fixed, with tests that hidden scripts are still caught. The app
  now says why a file is refused instead of "Checking" for ever, and the
  worker logs which PDF rule refused a file (`detail`).
  - On the test copy: `studafy-worker-test` runs this branch (deployed
    13:27 UTC), and the phone has the matching build. The owner's PDF then
    scanned clean (13:33).
  - After merging: redeploy the test worker from `main`.
- **#52 Observability** (`feat/observability-fixes`):
  - a native crash carried the Sentry installation id on iOS and Android
    (and Android Dart events the device id). The app now sets one constant
    user, `anonymous`, pins the SDKs' installation id to zeros before they
    start, and the Dart scrubber drops the device id;
  - the dead CloudWatch sink and its AWS dependency are removed;
  - the log shipper image is pinned by digest.
  - After merging: redeploy the log shipper
    (`fly deploy --config fly.log-shipper.toml`), and check one real native
    crash from a test build in Sentry (`user.id` `anonymous`, Android
    `device.id` all zeros).
- **#53 Capacity fixes 1–3** (`feat/capacity-fixes`): access rules once per
  call, grades from the caller's own records, homework rows a page at a
  time. Zero differences against the old code (lists page by page for the
  scale sample and every pgTAP fixture; 145,684 access decisions with edge
  cases planted). About twice the capacity: through the API at 1,000
  people, p50 2.6 s to 89 ms and p95 5.5 s to 762 ms; peak 153 to 310
  req/s (`docs/capacity/2026-10-14.md`). The proof scripts are in
  `scripts/scale/proof/`. After merging: back up, then apply
  `202610140003`–`202610140005` to the hosted test database (SQL only; no
  redeploy).

**Next steps for the owner** (the full list is part B and C of the launch
plan)
1. **On the iPhone** (a profile build pointing at the legal site was
   installed on 2026-10-15): open Study plans, and Family+ as a parent, tap
   Terms and Privacy, and confirm both open the live pages. This completes
   launch plan 4.3's "Done when".
2. **Review and merge #52, #53, #54 and #55**, then the steps after each
   above.
3. **Still open:**

| Item | When |
|---|---|
| AI DPA and DPIA | Paused by the owner |
| Production scanner (`studafy-scanner`, same config as the test one) | Before launch |
| Production purges (`RETENTION_SCHEDULE_ENABLED = "true"` in `fly.worker.toml`) | After the app release with consent version `2026-10-14` |
| Test purges: check the first run's logs | Any time |
| Supabase: upgrade to Pro | Before real students |
| Axiom: set the dataset retention to 30 days | Any time |
| Google Play: add the privacy policy link | Before publishing |
| Apple: register `com.studafy.light` | When the account is approved |
| Lawyers: retention for safeguarding notes, school-wide announcements, other notifications and roster rows with no account | Next follow-up |
| The duplicate `github-actions-api` token and the two unused GitHub secrets | Any time |
| Optional: delete the `feat/legal-site` branch (its first commit holds wrangler's local location data; the repository is now public, and PR #37's commits keep it even after the branch goes) | Any time |
| The local iOS files | Stay uncommitted |

**Next steps for Claude, in order** (the full list is part A of the launch
plan)
1. **Android track** (now that the app ID is decided): 3.5, lifting the
   Android release block for internal testing only, is a reviewed change to
   the SEC-001 guards and waits for the owner's go-ahead; 3.3 (upload key)
   and 3.4 (release SHA-1 in Google Cloud) need the owner first; then 3.7,
   the first internal-testing build.
2. **Capacity, next round** (`docs/capacity/2026-10-14.md`): the lessons
   and conversations lists a page at a time (about 26% of database time
   now), then notebook writing on the worker queue, then a load test against
   a staging project of the production size.
3. **Axiom monitors filtered by environment**, once production exists.
4. **Optional: backend-driven device tests in CI.** The exam and coursework
   device tests need a synthetic school (`dev.teacher`, `dev.student`,
   `dev.parent` at `synthetic.studafy.test`, fixed ids) that was seeded by
   hand and is not in the repository. Running them in CI means committing
   that seed and starting Supabase, Redis and the API in the emulator job.
5. **When the Apple account is approved:** stage 5 (iOS).

**Rules that still apply**
- Test only on throwaway stacks, never the local working database or the
  hosted one. Integration tests pick up `.env`'s `DATABASE_URL` (the local
  working database) unless `DATABASE_URL` is set explicitly.
- Hosted: read-only, and only when needed. Back up before any migration
  (`gh workflow run backup.yml`).
- Keep the local iOS signing files uncommitted:
  `ios/Runner.xcodeproj/project.pbxproj` (the personal team) and
  `ios/Runner/RunnerPersonalTeam.entitlements`. Never `git reset --hard`
  or check out over them: stash everything or rebase.
- Read `.env.hosted` with a parser that never prints values. Never
  `source` it.
- Ask before any `fly` command that changes something; read-only ones
  (`fly logs`, `fly status`) are fine.

## Earlier (2026-10-13): all merged, test copy deployed

**Where things stand**
- **Code:** Claude's launch items (3.6, 3.6b, 5.5, 4.3, 4.7, 4.8, 7.1 and
  7.2) are merged as PRs #34–#43. So are the follow-ups: #44 (Android
  emulator memory in CI) and #45 (legal deploy script, Arabic iOS permission
  prompts, DL-056).
- **CI on `main`:** green for every merge so far, including the device tests
  on an iOS simulator and an Android emulator. Check the run for `4231aa1`
  if it is still in progress.
- **Hosted test copy** (Supabase `cyrngoqnhqflzovlybbr`, Frankfurt):
  - a backup was taken first; restore check passed (run 38391400311);
  - migrations are applied up to `202610110004`;
  - `studafy-api-test` and `studafy-worker-test` run `main` at `3d86381`.
    #45 changed no server code, so no redeploy is needed for it.
  - The worker sends backlog alerts to Telegram. A test alert from the
    deployed worker was received.
  - The worker also runs the file-retention sweep, and Sentry releases carry
    the deploy.
- **Legal site live:** https://studafy-legal.studafy.workers.dev, with
  `/privacy`, `/terms`, `/delete-account` and `/ar/...`.
  - Deploy changes with `bun run legal:deploy`.
  - The texts are drafts awaiting legal review; the review notes are
    comments in `docs/legal/`, never on the pages.
- **Owner decisions** (DL-056):
  - declare under-13s in the store age settings;
  - not the App Store Kids category;
  - AI stays off for real students until the Together AI DPA and the DPIA
    are signed;
  - production database size later (at least 4 dedicated vCPUs
    recommended).

**Next steps for the owner, in order**
1. **Rotate the Fly token in `.env.hosted`.** Part of it was echoed into the
   2026-10-13 session's output. Use `fly tokens list`, then
   `fly tokens revoke`, and put the new one in the file. Never `source` that
   file.
2. **Sentry dashboard,** for both projects: turn on "Prevent Storing of IP
   Addresses", "Data Scrubber" and "Use Default Scrubbers". The CI token
   cannot change project settings.
3. **Security blockers for production:**
   - set the runtime role passwords and switch both `DATABASE_URL` secrets
     (`docs/deployment/fly-io.md`);
   - move Redis to a `rediss://` endpoint.

   The worker still warns about both.
4. **Decide the app ID** (Y5: `com.studafy.light` or `io.studafy.app`). That
   unblocks the Android track and the Play Console listing. Its answers are
   ready:
   - Data safety: `docs/store/google-play-data-safety.md`;
   - privacy URL: the legal site's `/privacy`;
   - account deletion URL: the legal site's `/delete-account`.
5. **Malware scanner: chosen, self-hosted ClamAV** (PR #50).
   `studafy-scanner-test` runs on Fly's private network only (no IP
   addresses) with `SCANNER_API_KEY`; the test worker has
   `MALWARE_SCANNER_URL` (`http://studafy-scanner-test.internal:8080/scan`)
   and `MALWARE_SCANNER_API_KEY`. Tested end to end on 2026-10-14. Production
   still needs its own scanner app, `studafy-scanner`, before launch: a
   production worker refuses to start without one.
6. **Sign the AI DPA and complete the DPIA** before AI reaches real
   students.
7. **Set retention periods** for files, audit records and AI outputs
   (privacy policy §10), then have a **legal review** of the English and
   Arabic texts before moving them to studafy.com.
8. **Cleanup:**
   - delete the AWS IAM key;
   - revoke the token in the suspended `studafy-api` and unset its unused
     secrets;
   - destroy the stray `studafy` app;
   - delete the local `.github/workflows/fly-deploy.yml`;
   - optionally delete the `feat/legal-site` branch. Its first commit holds
     wrangler's local state with city-level location data; it never reached
     `main`.
9. **CI cost:** the iOS device job uses macOS minutes (10×). Drop its
   `pull_request` trigger in `device-tests.yml` if that is too much.

**Next steps for Claude, in order**
1. **Capacity fixes** (`docs/capacity/2026-10-12.md`). Each change needs the
   2026-09-29 zero-difference proof, then a rerun of `bun run scale:bench`
   and `scale:http`.
   - Access checks once per request: about 28% of database time.
   - The grades list built from the caller's own records: 14%.
   - Homework rows built for the whole page at once: about 25%.
2. **A phone build pointing at the legal site**
   (`STUDAFY_PRIVACY_URL`, `STUDAFY_TERMS_URL`), then open both links from
   the subscription screens. That completes item 4.3's "Done when". It
   needs the owner's phone.
3. **Observability recommendations**
   (`docs/operations/observability-review-2026-10.md`):
   - done 2026-10-14: native crashes carry no installation id, the
     CloudWatch sink is gone, the log-shipper image is pinned (redeploy the
     shipper to pick the pin up);
   - still open: filter Axiom monitors by environment once production
     exists.
4. **Optional:** run the backend-driven device tests (exam workflow,
   coursework files) in CI against a local stack.
5. **When the owner's inputs arrive:** launch-plan items 2.3–2.5 (Y2–Y4),
   the Android track 3.x (Y5), and stage 5 for iOS (the Apple account).

**Rules that still apply**
- Test only on throwaway stacks, never the local working database or the
  hosted one.
- Hosted: read-only, and only when needed. Back up before any migration
  (`gh workflow run backup.yml`).
- Keep these four local files uncommitted:
  - `ios/Runner.xcodeproj/project.pbxproj` (the personal signing team);
  - `ios/Runner/RunnerPersonalTeam.entitlements`;
  - `fly.toml`;
  - `.github/workflows/fly-deploy.yml`.
- Read `.env.hosted` with a parser that never prints values. Never
  `source` it.

## Earlier (2026-10-12): the store, legal, alerts, capacity and test items

**What happened.** Claude worked through its remaining launch items in the
owner's order: 3.6, then 3.6b (added), 5.5, 4.3, 4.7, 4.8, 7.1 and 7.2. Item
1.3 was already done (PR #33 merged; `main` CI green). Each item is one PR,
open for the owner to merge:

| PR | Item | What | State |
|---|---|---|---|
| #34 | 3.6 | Google Play Data safety answers (`docs/store/google-play-data-safety.md`); Android Auto Backup off | Green, merge |
| #35 | 3.6b | Account deletion removes what it left behind; deleting a parent deletes their managed child accounts (screen names them); export gains gender, notebooks, devices; file retention sweep on | Green, merge, then **back up and apply migration `202610110004` to hosted**, then deploy the worker |
| #36 | 5.5 | `ios/Runner/PrivacyInfo.xcprivacy`, App Store privacy labels, permission prompts | Green, merge |
| #37 | 4.3 | Privacy policy 1.3, terms 1.2, deletion page, English and Arabic; static Cloudflare Worker in `ops/legal-site` | Green, merge; **deploy awaits approval** (below) |
| #38 | 4.7 | Worker backlog alerts to Telegram; Sentry release per deploy; environment on log lines; observability review | Green, merge; set Telegram secrets on the worker |
| #39 | 4.8 | Capacity re-measured (`docs/capacity/2026-10-12.md`); harness repaired and extended; HTTP load runner | Green, merge; choose the production database size |
| #40 | 7.1a | Tests: Family+ over HTTP, notification processor, material reading and file scan through Postgres; notification isolation | Green, merge |
| #41 | 7.1b | Accessibility checks on every main screen (EN, AR, 2× text) and the fixes they found | Green, merge |
| #42 | 7.1c | Device tests on an iOS simulator and an Android emulator in CI; reduced-motion layout fix | Green, merge |
| #43 | 7.2 | README, credentials map, ADR statuses, environment matrix, this file, launch-plan notes | Merge |

They are independent and branch from `main`. One overlap: #35 and #37 both
describe managed-child deletion, consistently.

**Decisions the owner made (2026-10-11 and 12)**
- **Item order:** 3.6 → 5.5 → 4.3 → 4.7 → 4.8 → 7.1 → 7.2. This overrides
  the earlier order, which had 4.3 first, so that the policy is written from
  the audit.
- **Account deletion:** close the deletion gaps in their own PR. Deleting a
  parent deletes the child accounts they manage.
- **Contact:** the public contact and deletion-request email is
  **hello@studafy.com**.
- **Load testing:** only on a local throwaway stack, with AI stubbed.

**Done 2026-10-13 (owner asked Claude to do them)**
- **Backup:** run 38391400311. Restore check passed: 136 tables, 1,645 rows,
  files included, at `202610110004`'s predecessor.
- **Hosted migration:** `202610110004` applied (dry run first); hosted is at
  `202610110004`.
- **Deployed:** `studafy-api-test` and `studafy-worker-test` from `main` at
  `3d86381`.
  - API: `/readyz` ready.
  - Worker: queue alerts on with Telegram configured; file-retention sweep
    on; releases tagged per deploy.
  - Known warnings: plaintext Redis and the `postgres` login.
- **Telegram:** `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` and
  `QUEUE_ALERTS_ENABLED=true` are set on the test worker (from
  `.env.hosted`). A test alert from the deployed worker was accepted by
  Telegram.
- **Legal site live** at https://studafy-legal.studafy.workers.dev:
  - pages: `/privacy`, `/terms`, `/delete-account`, `/ar/...`;
  - checked: security headers present, no review notes on any page.
  - Deploy with `bun run legal:deploy`. A wrangler custom build ran from the
    wrong folder, so `[build]` was replaced by the script.
- **Rotate the Fly token in `.env.hosted`.** Sourcing that file with the
  shell echoed part of `FLY_API_TOKEN` (and the public Sentry DSN) into the
  session output. Revoke and reissue it (`fly tokens list`, `fly tokens
  revoke`); never `source` that file. Use a parser instead.

**Owner decisions 2026-10-13 (DL-056)**
- **Ages:** include under-13s in the store age declarations.
- **App Store:** not the Kids category.
- **AI:** off for real students until the DPA and DPIA are signed.
- **Database size:** decided later.
- **Arabic permission prompts:** added (`ios/Runner/ar.lproj`).

**Waiting on the owner (new today)**
1. **Merge #34 to #43.**
2. **Approve the legal-site deploy:**
   `npx wrangler deploy --config ops/legal-site/wrangler.toml` (after
   `npx wrangler login`). It publishes to
   `https://studafy-legal.studafy.workers.dev/privacy`, `/terms` and
   `/delete-account`, plus `/ar/...`. Deploy it after #35 is live on hosted,
   because the pages describe that deletion behaviour. Make sure mail to
   hello@studafy.com arrives.
3. **Hosted:** back up, then apply `202610110004`, then deploy the worker.
4. **Telegram alerts:** set `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` and
   `QUEUE_ALERTS_ENABLED=true` on the worker, then run `bun run alerts:test`.
   The commands are in `docs/deployment/queue-alerts.md`.
5. **Store decisions:** listed at the top of `docs/store/*.md`. They include
   the malware-scanner vendor, the AI DPA and DPIA, target ages and Families,
   the Kids category, Sentry "prevent storing IP", retention periods, and
   Arabic iOS permission strings.
6. **Production database size:** at least 4 dedicated vCPUs is recommended
   (`docs/capacity/2026-10-12.md`).
7. **Legal review** of the English and Arabic legal texts, before moving them
   to studafy.com. The open items are `TODO(legal)` comments in
   `docs/legal/`.
8. **CI cost:** the iOS device job uses macOS minutes (10×). Drop its
   `pull_request` trigger if that is too much.
9. **A cleanup choice.** Wrangler's local state, which includes city-level
   location data from the owner's connection, was committed by mistake in
   the first commit of `feat/legal-site`. A later commit removed it, and it
   never reached `main`. To purge it from history: squash-merge #37 and
   delete the branch, or let Claude force-push a rewrite. Either needs the
   owner's OK.

**Known issues and findings (not fixed)**
- **Capacity:** the same screens cost about 40% more in the database than on
  2026-09-29. The ranked fixes are in the capacity report: per-request access
  checks first, then the grades list, then homework rows.
- **AI:** the basic study helper runs whenever `AI_API_KEY` is set, whatever
  `AI_LESSON_TOOLS_ENABLED` says.
- **Sentry:** native iOS and Android crashes bypass the Dart scrubber.
  Verify a native event (observability review).
- **Supabase Auth** keeps sign-in IP addresses itself. The privacy policy now
  says so; the retention is still to confirm.

**Next for Claude** (all items in the earlier list are done or in PRs):
- After the merges and deploys above, tick the launch-plan items whose
  **Done when** checks then pass.
- Optional: run the backend-driven device tests (exam workflow, coursework
  files) in CI on the Android job with a local stack.
- The capacity fixes, in the report's order.

**Throwaway stack:** `studafy-guardianann` on ports 55721 (API) and 55722
(database). Its workdir is now in this session's scratchpad (`annstack`).
Recreate one with `supabase/config.toml` copied, a new `project_id`, and the
`[db] port` changed. It holds `studafy_scale`, the 11M-row capacity
database; drop it when space is needed.

## Earlier (2026-10-11): the start of the launch plan

**Owner's checklist:** the "★ Your to-do" section at the top of
`docs/planning/launch-work-plan.md` (Y1–Y9), with step-by-step
instructions.

**Done since the assessment (2026-10-11), all on the test copy:**
- **Stage 1:** PR #20 merged; `main` CI is green.
- **2.1:** account deletion and export executors are on.
- **2.2:** production timeout set to 20 s.
- **2.6:** comment-only paper corrections need no reason; the marking notice
  sits above Save.
- **2.7:** notebooks a stopped instance left are resumed.
- **2.10:** re-authentication needs a fresh sign-in.
- **3.2:** INTERNET is in the release manifest.
- **Database:** migrations up to `202610110003` on hosted; the API, worker
  and iPhone build are deployed.

**Claude's remaining items (need nothing from the owner), in order:**

| Order | Item | What | Effort |
|---|---|---|---|
| 1 | 4.3 | Host the privacy policy and terms on a temporary public page (the existing Cloudflare account, `studafy.workers.dev`), because Google Play needs the link (Y8) | 0.5 day |
| 2 | 3.6 | Draft the Google Play Data safety answers from the code | 2 h |
| 3 | 5.5 | iOS privacy manifest and App Store privacy labels, ready for when Apple approves | 2 h |
| 4 | 4.7 | Telegram alerts on worker backlog; check Sentry and Axiom retention and scrubbing | 1 day |
| 5 | 4.8 | Re-run capacity with exams, notebooks and AI routes | 1 day |
| 6 | 7.1 | Test gaps (Family+ insights, notifications, material reading), accessibility checks per screen, simulator device tests in CI | 2–3 days |
| 7 | 7.2 | Bring stale docs up to date (README, credentials map, ADR statuses) | 0.5 day |

**Blocked on the owner:**
- 2.3, 2.4 and 2.5 (needs Y2, Y3, Y4);
- 3.1 to 3.9, the Android track (needs Y5, the app ID);
- stage 5, iOS (needs the Apple account);
- 2.8 waits for the next lesson-save rejection, now logged with the field.

**What to work on:** `docs/planning/launch-work-plan.md`, top to bottom. It
turns the production readiness assessment
(`docs/evidence/launch-readiness/2026-10-11-production-readiness.md`, issues
`PR-01` to `PR-29`) into ordered steps, each with who does it and a "Done
when" check. Tick items there, with the date and evidence, as they are done.

**Verdict of the assessment:** not ready for a public launch. Ready for a
closed pilot on the test copy once stage 2 of the plan is done. The full
reasoning, feature inventory, scorecard and go-live checklist are in the
assessment.

**Accounts**
- **Apple Developer:** applied for; the owner's email is still being
  verified. iOS store work (Sign in with Apple, push keys, TestFlight,
  App Store products) waits; it is stage 5 of the plan.
- **Google Play Console:** open. Android goes first (stage 3).

**State of the system**
- **Test copy:**
  - Fly: `studafy-api-test` and `studafy-worker-test`, both running `0ba0fd0`
    plus the logging change `34e4d6f`.
  - Supabase: `cyrngoqnhqflzovlybbr`. The owner created every account in it
    for testing: preserve its data, never reset it.
  - Migrations are up to date there (latest `202610110003`).
- **Phone:** the iPhone 14 Pro has the 2026-10-11 profile build, pointing at
  the test copy.
- **Backups:**
  - daily (GitHub Actions, `main`), encrypted, including uploaded files,
    restore-checked;
  - kept 30 days;
  - the key is `~/studafy-backup.key` plus a copy in the owner's Apple
    Passwords; the offline USB copy is still to do.
- **Release builds:** blocked on purpose (SEC-001) on iOS and Android, and a
  production app refuses to start. The plan lifts this in steps.

**Do first (stage 1 of the plan)**
1. Push the branch: everything since 2026-10-03 exists only on this Mac.
2. Make CI reliable: the Flutter job's Android build times out on GitHub's
   runner but builds locally in about 3 minutes.
3. Open a PR to `main`.

**Waiting on the owner**
- Database role passwords (SQL in `docs/deployment/fly-io.md`; auto mode
  refuses to run it).
- A Redis with TLS.
- Clean-up of old Fly secrets and the AWS key.
- The app ID decision (`com.studafy.light` or `io.studafy.app`).
- AI provider DPA and DPIA.
- A malware scanner vendor.
- Domains.

**Rules that still apply**
- Test with synthetic accounts on a throwaway local stack, never on the
  owner's accounts.
- Hosted reads only as needed, read-only.
- Back up before any hosted migration (`gh workflow run backup.yml`).
- Keep these four files uncommitted:
  - `ios/Runner.xcodeproj/project.pbxproj`;
  - `ios/Runner/RunnerPersonalTeam.entitlements`;
  - `fly.toml`;
  - `.github/workflows/fly-deploy.yml`.

**How to reproduce flows locally** (used on 2026-10-11)
1. Run a local API and worker on a throwaway Supabase stack.
2. Seed a teacher, student, class and assignment through the real API.
3. Run `integration_test/coursework_files_device_test.dart` on the
   simulator.

The seed scripts lived in that session's scratchpad. Recreate them from the
test file's header if needed.

## Earlier (2026-10-11): uploads and hand-ins fixed on the phone

**Reproduced and fixed.** Reproduced on the iOS simulator with the real
screens against a local API, worker and Storage
(`integration_test/coursework_files_device_test.dart`, seeded by a local
script). Commit `0ba0fd0`.

- **Word and PowerPoint.** Storage refused `.docx` and `.pptx` (415) after the
  API had granted the upload: the bucket's allow-list never gained the Office
  types from `202610070001`. A lesson with a Word file showed "That file could
  not be uploaded" and could not be saved. Migration `202610110001` makes the
  bucket allow exactly what the purposes allow, and pgTAP checks it.
- **Blocked uploads.** Failed uploads kept one of only 3 open upload slots for
  2 hours, which blocked every upload. There are now 10 slots, and links last
  30 minutes.
- **Students may hand in Word and PowerPoint.** This reverses an earlier test
  rule; the owner may revert it.
- **Opening files.** The app sent an expired token and gave up on the 401. It
  now refreshes and retries once.
- **No submissions on the test copy.** The hosted database had none ever, so
  teachers had nothing to grade: student hand-ins had never reached the
  server.
- **Access log reasons.** The access log now records `problem_code` and
  `invalid_fields` (`34e4d6f`). An earlier hosted lesson save failed with a
  400 that is still unexplained; the next one will name the field.

**Hosted.** A backup ran first (restore check passed). `202610110001` was
applied, and the API, worker and phone build are deployed.

**Checks**
- 37 of 37 pgTAP CI steps pass.
- 1,013 backend tests pass.
- 765 Flutter tests pass.
- The simulator test passes.

**Backups include files (2026-10-11).** PR #32 was merged into `main`
(`feac3b4`) on the owner's instruction, although CI's "Verify synthetic debug
build" step failed on GitHub's runner; the same build passes locally.
`BACKUP_INCLUDE_STORAGE=true`. Test run 38143723528:
- 7 files (4.1 MB, none missing) were exported;
- the restore check passed (136 tables);
- the 8.2 MB encrypted artifact decrypts with the owner's key and contains
  the files.

The `backups` environment can be used only from `main`.

## Earlier (2026-10-08, later): security audit (ADR-0041)

The full report, with evidence for each finding, is
`docs/evidence/launch-readiness/2026-10-08-security-audit.md`. This section
supersedes the ones below where they conflict.

### Status (deployed 2026-10-08)

- **Committed** as `9c23c03` (not pushed). The four files that must stay
  uncommitted (end of section 6) are unchanged.
- **Backup first.** An encrypted, restore-checked backup was taken before the
  migrations: 136 tables, 715 rows, at `202610070004`. It is in
  `~/studafy-backups/` and its private key is `~/studafy-backup.key`; move the
  key to a password manager. The backup excludes Storage file contents.
- **Hosted database.** `202610070005`, `202610070006` and `202610080001` were
  applied with `db push`; no reset, and the history is up to date.
- **Deployed.** `studafy-api-test` and `studafy-worker-test` run `9c23c03`.
  - `DATABASE_CA_CERT` is the Supabase root CA. It matches the pooler's
    fingerprint, and the certificate is verified.
  - `/readyz` is ready.
  - The forged-header check now logs one `ip_hash`.
  - The worker shows no errors.
- **Backups are automatic (2026-10-11).** The owner created
  `studafy_backup` and set `BACKUP_DATABASE_URL` in the `backups`
  environment. The first workflow run passed its restore check (136 tables,
  641 rows, at `202610080001`). It runs daily and keeps each backup for
  30 days.
- **Denied in auto mode** (left for the owner): creating `studafy_backup` and
  setting the runtime-role passwords, a privilege grant. Steps are in
  `docs/deployment/backups.md` and `docs/deployment/fly-io.md`.

### Fixed and verified locally

1. **Client IP spoofing.** IP limits were bypassable through caller-written
   headers; this was confirmed on the test copy via `ip_hash` in `fly logs`.
   Fixed with `CLIENT_IP_SOURCE` (`fly` on the test copy, `cloudflare` in
   production) and the opt-in `ORIGIN_REQUIRE_CLOUDFLARE`.
2. **Database TLS.** Postgres connections were plaintext. Every non-loopback
   connection is now TLS; `DATABASE_CA_CERT` adds verification.
3. **Database role.** Production refuses the `postgres` login (ADR-0014
   runtime roles); elsewhere it logs `database_privileged_role`.
4. **AI metering.** Billed AI failures are charged instead of released. The
   new `studyGeneration` limit allows 30 per 5 minutes and fails closed.
5. **Image pixel cap.** 50 MP, enforced in the scan, `prepareImage` and
   pdf.js. A 389 KB bomb had reached 481 MB of memory.
6. **Wellbeing notes.** A removed teacher could still read their
   safeguarding notes through PostgREST; fixed by the migration.
7. **Redis.** Command timeout of 2 s, plus a warning for plaintext remote
   Redis.

### Checks (throwaway stack on 55722, reset)

- pgTAP: 56 files in CI order, all pass.
- Backend: 1,010 pass, 1 skipped, 0 fail.
- Gates: typecheck, lint, format, bounds, migrations, `generate:check` and
  `db lint` are clean.
- `verify-auth-lifecycle.ts` passes 26/26 as `studafy_api_runtime`.
- No Dart changes, so Flutter tests were not re-run.

### Owner actions (blocking, hosted)

1. **Backups.** None has ever succeeded. `BACKUP_DATABASE_URL` and
   `BACKUP_AGE_RECIPIENTS` are missing, and the daily workflow fails.
2. **Redis.** The hosted Redis is plaintext over the internet. Move to a
   `rediss://` endpoint.
3. **Database logins.** Set the runtime role passwords (the worker role
   also needs `login`) and switch both `DATABASE_URL` secrets; see
   `docs/deployment/fly-io.md`.
4. **Fly cleanup.**
   - Delete the AWS IAM key and revoke the `FLY_API_TOKEN` stored in the
     suspended `studafy-api`.
   - Unset the unused secrets there.
   - Destroy the stray `studafy` app.
   - Delete (don't commit) `.github/workflows/fly-deploy.yml`.
5. **Deploy.** Decide whether the Frankfurt database is still a test
   target. Then apply `0005`, `0006` and `202610080001`, and deploy the
   test API and worker.

## Earlier (2026-10-08): exam marking, absence, Today lists, checks (ADR-0040)

This section supersedes the study-AI sections below wherever they conflict.

### Status

- **Committed** on this branch; see the git log. Not pushed.
- **Not deployed.**
  - The Frankfurt test database has migrations up to `202610070004` only.
  - `202610070005` (unwound wraps) and `202610070006` (absence and
    feedback-only edits) are **not** applied there.
  - The deployed `studafy-api-test` predates them. Until both migrations
    and an API deploy go out, the hosted test copy:
    - refuses absences for online work;
    - asks for a reason on feedback-only edits.
- **The hosted database is the planned production database.**
  - ADR-0035 says production depends on "the Frankfurt database". The one
    hosted Supabase project, `cyrngoqnhqflzovlybbr`, serves the test copy
    now.
  - The production app `studafy-api` is suspended, not removed.
  - Auto mode blocks reading it as a production read. This session did not
    access it.
  - Before the next deploy, the owner should decide whether that database
    is still a test target.
- **Phone build.** An iOS profile build (signed, team `DX87P72856`) is at
  `build/ios/iphoneos/Runner.app` (45.6 MB, built 2026-10-08). It was not
  installed or distributed. It points at the hosted test API from
  `config/dart-defines.device.json`, which does not yet have `0005` and
  `0006`.

### What works now

**Exam marking**
- Every online exam opens its submissions from the Teaching, class and
  Gradebook lists.
- The submissions list shows the whole class:
  - submitted (not graded, or partly graded);
  - graded (a private draft);
  - published;
  - not submitted, absent, absent (published), and not graded (published).
- Each student's answers are shown question by question, with the key, the
  automatic mark, the score and comment fields, and the feedback.
- Marks save as a private draft. Publishing asks first and never notifies
  twice.

**Corrections**
- After publication, only a change to the **mark or score** needs a reason.
- The app sends the save and asks for a reason only if the server refuses
  without one.
- Feedback-only edits are applied, kept in the grade history (non-material,
  no reason), and not announced. Answer comments never touch the grade.
- An unchanged save sends nothing.

**Absence**
- A teacher marks a non-submitter absent, with optional notes. It is never
  a score, and it stays private until published.
- Published, it shows as "Missed the exam" to the student and their
  parents.
- A draft absence can be removed. A published one is corrected with a
  reason, for example to "Not graded (excused)".
- If the student hands in after an absence:
  - an unpublished absence is replaced, and that is recorded;
  - a published absence stands until the teacher replaces it, with a
    reason, from the attempt.

**Refresh**
- Pull-to-refresh on the results and submissions pages now asks the server
  again. It used to reuse a copy up to 20 seconds old.

**Today lists**
- These are as in ADR-0040 (2026-10-07 entries).

**Checks**
- `check:migrations` passes. Forward migration `202610070005` unwinds the
  five wraps:
  - `authz_authorize` is flattened, with 0 differences across 314,976
    recorded decisions;
  - four inner functions are renamed for what they do.
- The gate accepts a wrap only once a later migration unwinds it; see the
  ADR-0030 addendum and `scripts/migration-wraps.ts`.
- `check:bounds` passes. The import scan now reads tokens
  (`scripts/import-scan.ts`) and finds the same 747 real imports in 185
  files; the old one read "from" inside comments and strings.
- The fixture teardown now removes cached study outputs
  (`private.material_outputs`). Before, the material-selection suite failed
  on any second run against the same database.

### Evidence (2026-10-08)

**Local checks** (throwaway Supabase stack, reset)
- 56 of 56 pgTAP suites, in CI order;
- 987 backend, scripts and ops tests pass, 1 skipped;
- 762 Flutter tests;
- analyze, lint, format, typecheck, generated code, bounds, the migration
  gate and `db lint` are clean.

**Device run** (iPhone 18 Pro simulator, iOS 27)
- `integration_test/exam_workflow_device_test.dart`, driven by
  `flutter drive`, passed. This is an automated run, not a person's
  hands-on test.
- It used the real screens, repositories and HTTP transport against a
  local API on the throwaway database, with synthetic accounts:
  - `dev.teacher`, `dev.student` and `dev.parent` at
    `synthetic.studafy.test`;
  - "Dev Absentee", a student with no account.
- It covered:
  - building and publishing an exam;
  - the student answering and submitting;
  - the teacher seeing both students and an out-of-range score refused;
  - a draft save sent once despite a double tap, and kept private;
  - marking the absentee absent, then publishing;
  - the student (after a pull to refresh) and the parent (read-only) seeing
    3 of 4 and the feedback;
  - a feedback edit with no prompt;
  - a mark correction with a reason;
  - correcting the absence to not graded;
  - everything still in place after reopening.
- The run needs `E2E_API_URL`, `E2E_SUPABASE_URL`, `E2E_ANON_KEY` and
  `E2E_PASSWORD`.

**AI and messaging, real model** (local API, Together `Qwen/Qwen3.5-9B`,
synthetic lesson)
- A quiz is refused on the free plan.
- On Max:
  - quiz: 6 questions in 7.9 s, and the same selection returns the kept
    quiz;
  - flashcards: 8 cards;
  - a summary saved to the class notebook;
  - a helper answer grounded in the chosen lesson;
  - a background notebook reaching `ready`.
- A lesson the student cannot see is refused (404).
- Usage moves and the app's plan carries no token counts.
- An exhausted allowance is refused (`AI_ALLOWANCE_USED`).
- Messaging, once the school's switch is on: the teacher starts a
  conversation, the parent reads and replies.

### Blockers and findings

- **No hands-on testing.** No person tapped through the app. No
  non-intrusive input tool is installed (idb, XCUITest runner), and
  scripting the Mac's mouse would take over the owner's desktop.
- **Payments:** no App Store or Google Play sandbox credentials on this
  machine.
- **Push:** no FCM or APNs credentials, so no real push delivery was
  tested.
- **Hosted:** no reads or writes this session (see Status).
- **Quiz timeouts.** `fly.api.toml` (production) does not set
  `API_REQUEST_TIMEOUT_MS`. The default of 10 s leaves the model 8.5 s, and
  quizzes take 6–9 s, so they would time out there. `fly.test.api.toml`
  sets 20 s.
- **Paper sheet.** The paper grade sheet still requires a reason for a
  comment-only change to a published mark; online marking no longer does.
- **Snackbar.** A save confirmation covers the bottom Save button for a few
  seconds on a phone.

## 1. Goal

Make Studafy's AI study features dependable and clear for students:

- **Grounded AI and allowances.** The AI reads lesson attachments (PDF, Word, PowerPoint, images, links) and cites them. It runs under one shared token allowance per student: Free 40k a week, Plus 3M a month, Max 6M a month. This is ADR-0037.
- **Quizzes, flashcards and notebooks.** Quizzes and flashcards work again. Students can make organised study notebooks from lessons, with their own notes, highlights, bookmarks and sections. This is ADR-0038.
- **Exact material.** Every AI feature (AI Helper, summaries, quizzes, flashcards, notebooks) uses exactly the material the student picks, in one shared picker. The server enforces it. This is ADR-0039.
- **No token numbers.** AI usage appears as a bar with plain labels. Token accounting stays on the server.
- **Phone testing.** The owner tests on an iPhone 14 Pro and an iOS simulator against the Fly test copy.

## 2. Current status

- **Everything is committed.** The latest commit is `7255221`. The working tree holds only files that must stay uncommitted (see the end of section 6).
- **Deployed.** Migrations up to `202610070003_material_selection.sql` are applied to the hosted Frankfurt test database, and the Fly test API (`studafy-api-test`) and worker are redeployed.
- **On the devices.** The latest build is installed on the iPhone (profile build) and running on the simulator.
- **Tests pass:**
  - 945 backend tests (`bun test apps packages`);
  - all 37 database test suites, run in CI order on the throwaway database;
  - 743 Flutter tests.
  - Analyze, lint, typecheck, the generated-code check and the Dart bounds check are clean.
- **Known gate failure.** `bun run check:migrations` fails on `202610060001_online_assessments.sql` and `202610070001_grounded_material_and_token_allowances.sql`. Both rename functions to wrap them, which ADR-0030 bans. This predates the latest work, and CI will fail on it.
- **Not yet checked by a person.** No one has used the new features signed in as a student on the test copy. Automated tests and a direct run of the real model on sample material pass.
- **Real model behaviour seen:**
  - an English notebook takes about 14s;
  - an Arabic notebook takes 8–14s;
  - a quiz takes about 6–9s;
  - flashcards take about 4–5s;
  - the provider (Together, Qwen3.5-9B) once returned a transient 503.

## 3. Active files

**Backend (`apps/api/src/study/`)**
- `selection.ts`: resolves and validates the chosen references, gathers exactly that material, and fingerprints it.
- `selectionRoutes.ts`: `POST /v1/study-sets` and `POST /v1/classrooms/{id}/notebook/summary`.
- `studyNotebookRoutes.ts`: notebook routes, including background generation.
- `material.ts`, `metering.ts`: material retrieval and AI usage metering, used by the routes above.
- `apps/api/src/study-assistant/routes.ts`: the helper uses the exact selection.
- `apps/api/src/composition/routes.ts`: where modules are mounted (the order must match the catalogue).
- `apps/api/src/authorization/catalogue.ts`: permissions, including `study_notebook.*` and `material_set.generate`.

**Contracts (`packages/contracts/src/v1/`)**
- `materialSelection.ts`, `studyNotebooks.ts`, `studyAssistant.ts`, `routes.ts`.

**Domain and infrastructure**
- `packages/domain/src/study/notebook.ts`: notebook parsing.
- `packages/domain/src/study/studyContent.ts`: stricter quiz and flashcard parsers that also recover cut-off replies.
- `packages/infrastructure/src/studyAssistant.ts`: the model calls.

**Database**
- Migrations: `supabase/migrations/202610070002_study_notebooks.sql` and `202610070003_material_selection.sql`.
- Tests: `supabase/tests/study_notebooks.sql`, `material_selection.sql`, and `auth030_grants.sql` (the reviewed list of API functions).

**App**
- Shared code:
  - `lib/core/material_selection.dart`;
  - `lib/core/material_unavailable_dialog.dart`;
  - `lib/core/ai_usage.dart`;
  - `lib/core/ai_tokens.dart`.
- Pages that compose features: `lib/app/material_picker.dart`, `student_lessons_page.dart`, `student_shell.dart`, `account_hub_page.dart`.
- Study screens (`lib/features/study/presentation/`):
  - `study_set_pages.dart`;
  - `study_notebook_page.dart`;
  - `study_notebook_shelf.dart`;
  - `notebook_cover.dart`;
  - `notes_text.dart`;
  - `notebook_view.dart`.
- Study data: `lib/features/study/domain/study.dart`, `study_notebook.dart`, and `data/api_study_repository.dart`.
- Helper: `lib/features/study_assistant/` (domain, data and presentation).
- Other:
  - `lib/data/contracts/v1_http_transport.dart` (notebook reads are marked live);
  - `scripts/generate-dart-client.ts` (handles nullable lists);
  - `lib/l10n/app_en.arb` and `app_ar.arb`.

**Docs**
- `docs/adr/ADR-0037…`, `ADR-0038-study-notebooks.md`, `ADR-0039-exact-material-selection-and-ai-usage.md`.

## 4. Changes made

**Quizzes and flashcards (`22489ac`, `9c21ac8`)**
- **Root cause:** the generated Dart client crashed on the `null` half of a study set. A quiz has `cards: null` and flashcards have `questions: null`. The generator now reads nullable lists as nullable.
- **Reply parsing:**
  - study sets have their own 1,400-token output budget;
  - a reply cut off at the limit keeps its complete items;
  - duplicate or malformed items are dropped;
  - a set with fewer than 3 questions or 4 cards fails, and the AI usage held for it is released.
- **Quizzes:** answer everything, then check, with a score and explanations.
- **Flashcards:** they flip, and the student marks "I knew it" or "Still learning".
- **Every set:** loading, empty and error states, with Try again.

**Study notebooks (`9c21ac8`, ADR-0038)**
- **Writing:** a notebook is written in the background from one lesson, in a fixed structure with citations. Generation is metered once per generation.
- **The notebook itself:**
  - a cover, contents and numbered pages, on lined, plain or grid paper;
  - notes, highlights, bookmarks, the student's own sections, and renamed headings;
  - saves are versioned and merged with copies saved elsewhere.
- **Updates:** "Update available" appears when the lesson changes. Updating rewrites only the AI part.
- **Practice:** quizzes and flashcards from a notebook are kept per notebook version.
- **Old entries:** old notebook entries render Markdown properly.

**App icon (`9c23886`)**
- The Studafy icon replaces Flutter's on iOS, Android and macOS. The source image is `assets/brand/source/app_icon.png`.

**Exact material selection and AI usage (`7255221`, ADR-0039)**
- **References:**
  - `lesson` means the whole lesson;
  - `text` means the lesson's own text only;
  - `file` and `link` mean one attachment;
  - `note` means one of the student's notes, for the helper only.
- **Server refusals:**
  - lessons the student cannot see;
  - files that are not on the lesson named;
  - more than 10 lessons.
- **Unreadable files:** the server returns `MATERIAL_UNAVAILABLE` naming each file. They are skipped only when the request says `skipUnavailable`.
- **Bug fixed:** the helper used to widen a whole-lesson choice to every file of every chosen lesson.
- **New routes:** quizzes and flashcards from a selection (Max), and summaries into the class notebook (Plus). Results are kept in `private.material_outputs` by a fingerprint of the selection, and access is re-checked on every read.
- **Notebooks:** they record `whole_lesson` and `include_text`.
- **One picker in the app:**
  - class, then lesson, then the lesson's text and each attachment;
  - search, filters, a persistent summary line, a review sheet and specific action buttons;
  - a whole class only after a confirmation;
  - the helper shows its material above the chat and marks changes in the chat.
- **AI usage:**
  - a profile section with a bar, a level label, the reset date and an upgrade button;
  - every token count removed from the interface and messages.

**Also fixed**
- `committedJson` is only for routes whose SQL already stored the response against the idempotency key. Other routes now use `c.json`, so retries replay correctly.
- Notebook list and notebook reads are excluded from the app's short read cache, so progress polling sees changes.

## 5. Failed attempts

- **`committedJson` misuse.** Using it on routes whose SQL does not store the response left idempotency keys stuck "in progress". The lesson reading retry route had the same bug. Fixed by using `c.json`.
- **Text-only notebooks widened.** A notebook from a lesson's text alone was first stored with an empty source list, which the database reads as "whole lesson". Fixed with an explicit `whole_lesson` column.
- **Tests ran against the local database.** Running `bun test` without `DATABASE_URL` picked up `.env` and hit the local DB on port 54322. Nothing was left behind, but always set `DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:55722/postgres`, the throwaway stack whose workdir is the session scratchpad's `annstack`.
- **Paper styling hid ripples.** A coloured `DecoratedBox` behind the notebook pages hid tap ripples and tripped ListTile assertions. Fixed by using a `Material` surface.
- **Dialog controller disposed early.** A text dialog's controller was disposed while the dialog was still closing. Fixed with a dialog widget that owns its controller.
- **Brittle scripted edits.** Python string replacements failed where `dart format` had reflowed the code. Re-read the file before editing.
- **Live debugging on the phone.** `flutter attach` to the profile build on the phone kept losing its connection. Diagnose from server logs and the database instead.
- **Wrong test fixture.** In pgTAP, the seed guardian can see the lessons, so use `other_school_user` as the outsider in access tests.

## 6. Next steps

1. **Check the new features on the phone**, signed in as a student on the test copy:
   - the picker opened from a lesson;
   - "Select entire class";
   - the "Continue without them" dialog;
   - summaries;
   - a notebook from the lesson text only;
   - the helper context bar and its change marker;
   - Profile → AI usage, in both English and Arabic.
2. **Fix the CI migration gate.** Rework the function wrapping in `202610060001` and `202610070001` to follow ADR-0030, using a forward migration with named handlers. Both are already applied to the hosted test database, so don't edit them in place.
3. **Decide whether to make background notebook writing durable**, by moving it to a worker queue. Today it runs inside the API process: if the machine stops mid-write, the notebook times out after 10 minutes and the student retries.
4. **Possible follow-ups:**
   - notebooks made from several lessons;
   - storing summary sources in a structured field (today they are a line of text in the note);
   - a separate subject field on classes (today the class name is used);
   - a higher limit than 10 lessons for whole-class selection.
5. **Remove unused strings.** The `nbSheet*` keys in the ARB files belonged to the removed create sheet.
6. **Distribution.**
   - iPhone testers outside the owner's own devices need TestFlight, which requires the Apple Developer Program ($99 a year).
   - Android can be shared now as a sideloaded APK.
   - Real students need the provider data agreement and the privacy assessment (DPIA) first, as ADR-0037 says.
7. **Keep these uncommitted:**
   - `ios/Runner.xcodeproj/project.pbxproj` (the personal signing team);
   - `ios/Runner/RunnerPersonalTeam.entitlements`;
   - `fly.toml`;
   - `.github/workflows/fly-deploy.yml`.
8. **Deploy routine:**
   1. Run all gates (see Current status).
   2. Run `bunx supabase db push --db-url <hosted URL, port 5432>` with `--dry-run` first, then for real.
   3. Run `fly deploy --config fly.test.api.toml` and `fly.test.worker.toml`.
   4. On the phone, run `flutter build ios --profile --dart-define-from-file=config/dart-defines.device.json`, then `xcrun devicectl device install app --device 00008120-00067D5E3CC2201E build/ios/iphoneos/Runner.app`.
