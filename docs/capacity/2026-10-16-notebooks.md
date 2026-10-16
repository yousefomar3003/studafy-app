# Study notebooks on the worker queue, 16 October 2026

Fix 4 of the [12 October list](2026-10-12.md#fixes-ranked-by-impact), item 2
of the 14 October one (`docs/capacity/2026-10-14.md`, on
`feat/capacity-lists-paging` until it merges): study notebooks are written
by the worker, off a queue, not inside the API process. ADR-0038 has the design (amendment of 2026-10-16);
the migration is `202610160000_notebook_generation_queue.sql`.

## The short answer

**A notebook now costs the API what the request itself costs: about a third
of the database work it did, and no AI work at all.** The writing - reading
the lesson, holding and settling the allowance, calling the model, saving -
moved to the worker. The total database work per notebook is unchanged; it
is just no longer in the process that answers people.

Per notebook, median of 11 interleaved runs (database blocks: 6 runs):

| | API before | API after | Worker after |
|---|---|---|---|
| Database statements | 24.9 | **9.6** | 5.3 |
| Database blocks read or hit (shared buffers) | ~2,140 | **~610** | ~1,510 |
| Database time | 545 ms | **134 ms** | ~500 ms |
| Process CPU | 36 ms | **24 ms** | ~32 ms |
| The request, p50 | 223 ms | 190 ms | - |
| Asked to ready, p50 | 3.1 s | 8.9 s (see below) | - |

- **Statements and blocks are the reliable figures.** They do not depend on
  what else the machine is doing. The time and CPU columns do: the Docker VM
  was shared with several other stacks under load, so single runs ranged
  from 107 ms to 3.3 s of API database time per notebook for the same code.
  Medians of interleaved before/after runs are given for those.
- **What left the API** per notebook: the lesson read again as the student,
  the passage search, the allowance hold and settle, and the save - 15
  statements and ~1,500 blocks. What remains is the request: sign-in
  context, authorization, idempotency, the selection check and the create
  (which now also records the job, in the same transaction).
- **CPU barely mattered.** The model's 8-14 s was always waiting, not CPU;
  the API saves building the prompt and parsing the reply, about a third of
  its CPU per notebook, within the noise of these runs.
- **Asked to ready is slower in a burst, by design.** These runs ask for 60
  notebooks in about 15 s. The API used to call the provider for all of them
  at once; the worker writes `AI_NOTEBOOK_CONCURRENCY` (16) at a time, so the
  last of a burst waits its turn. With the real provider (8-14 s each) a
  worker writes about 70-120 notebooks a minute; raise the setting (up to
  50) if a launch shows queues - the queue alert's age limit (300 s) is the
  signal. Single notebooks are as quick as before plus up to one poll
  (`AI_NOTEBOOK_POLL_INTERVAL_MS`, 2 s).

## What changed

| | Before | After |
|---|---|---|
| Who writes a notebook | The API instance that took the request, as a promise in its own process | The worker, from `private.study_notebook_jobs` |
| How it is queued | - | A trigger records one job per (notebook, generation) in the transaction that creates or regenerates it |
| A process stopping mid-write | Every API instance looked once a minute for notebooks left "creating" 3-9 minutes, resumed at most twice (`202610110003`) | The job's three-minute lease lapses and the next attempt takes it; the stopped attempt's allowance hold is released |
| A busy provider | The notebook failed; the student retried | Tried again after 20 s and 80 s (three attempts), charging nothing for the busy ones |
| Gave up | Read as `timed_out` after ten minutes | A dead letter after three attempts or nine minutes; the notebook shows failed with its retry; counted by the queue alerts ("study notebooks") |
| Charging | Once per generation (key `notebook:<id>:<generation>`); a resumed write had its own key | Once per generation: every attempt shares the key |
| Names out of the request (ADR-0043) | The API writer wrapped the model client with the owner's known names | The worker does the same before the model call, with the same shared code; it reads the names through `private.notebook_job_names` (`202610160001`), and with no names it sends nothing (`names_unavailable`) |
| Owner lost AI access while it waited | The ledger refused the API writer's hold | The ledger refuses the worker's hold: the notebook fails with the reason (`consent_required` ...), no model call, no retry |

The app sees no change: the same routes, answers ("creating" at once, the
same refusals), polling and statuses.

## How it was measured

`scripts/scale/notebook-load.ts` (new). It starts the real API, and for
"after" the real worker, from a directory without the repository's `.env`,
connected as their runtime roles (`studafy_api_runtime`,
`studafy_worker_runtime`) to a throwaway local stack (Postgres 17, the
Supabase local stack in a shared Docker VM). It seeds one school, a class,
and a lesson with text and a read PDF of 30 passages, and 30 students on
Plus. Each asks for two notebooks, four requests at a time. The AI provider
is a local stand-in over HTTPS that answers with a notebook of realistic
size (~2.5 k output tokens) after 2.5 s ± a third; nothing real is called.

"Before" is `origin/main` (`4f18c85`), unpacked with `git archive` and run
with `--api-root` against the same database, alternating with "after" run by
run. Per notebook it reports the API's and the worker's CPU time (`ps`), and
their database statements, blocks and time from `pg_stat_statements`,
grouped by runtime role, reset after a warm-up notebook.

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -days 2 -subj "/CN=127.0.0.1" -addext "subjectAltName=IP:127.0.0.1" \
  -keyout ai.key -out ai.pem
# after (this branch):
bun scripts/scale/notebook-load.ts --cert ai.pem --key ai.key \
  --admin-url postgresql://postgres:postgres@127.0.0.1:<throwaway port>/postgres \
  --redis redis://127.0.0.1:<port> --students 30 --notebooks 2 \
  --concurrency 4 --worker --top
# before: the same, with --api-root <a checkout of the earlier commit>
# and without --worker.
```

It gives the two runtime roles a login password for the run and takes it
away after; it refuses the developer database (54322) and anything not
local.

## Next

From the 14 October list: production database size and settings (fix 5 of
12 October), then `http-load.ts` against a staging project of that size
before launch.
