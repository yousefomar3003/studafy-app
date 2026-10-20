# ADR-0029: Free Lessons, Studafy Plus / Max, and a metered AI ledger

- Status: Accepted; deployed to the Fly test copy, not yet to production
  (status reviewed 2026-10-12, launch plan 7.2). Originally accepted for
  local/disposable use; superseded in part by
  [ADR-0034](ADR-0034-paid-plans-live-from-launch.md), which lists the plans
  in staging and production and ships the lesson AI switched on
- Date: 2026-09-27
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Supersedes: the Student Notebook paywall (PAY-071 `student_notebook`)
- Relates to: ADR-0026 (AI capability removed), SEC-001

## Context

The Student Notebook was a paid product: without a `student_notebook`
entitlement a student could not read their own class's lessons. That put the
core of school work behind a subscription. The product decision is:

1. **Lessons are free.** Every enrolled student reads their class's lessons,
   grouped by class and by date.
2. **Each student has a free notebook for each class.** Entries are dated
   and belong to that student and that class.
3. **Studafy Plus** (US$3.99/month) adds *Snap the whiteboard*: a photo of
   the board becomes real notebook notes.
4. **Studafy Max** (US$5.99/month) includes Plus, and adds quizzes and
   flashcards made from a lesson.
5. **The "ask" box stays free**, limited to 10 questions a day.
6. **AI spend has a hard cap for each student each month.** Plus is capped
   at US$0.80 and Max at US$1.60. A subscription must never cost more in AI
   than these caps.

## Decision

### Plans are resolved on the server, in one place

`private.study_plan(user)` returns `max`, `plus` or `free`. It reads:

- active `entitlements` for the `studafy_max` and `studafy_plus` products, in
  the `notebook_runtime` environment, the same PAY-071 machinery as before,
  with store verification and refunds (a student's own purchase needed a
  guardian's approval until DL-071, 2026-10-20, removed it: the student now
  buys the plan themselves);
- comp grants in `private.study_plan_grants`, for support and testing.

`private.ai_plan_limits(plan)` holds everything a plan permits:

| Plan | Monthly AI cap | Questions a day | Features                            |
| ---- | -------------- | --------------- | ----------------------------------- |
| free | $0             | 10              | ask                                 |
| plus | $0.80          | 40              | ask, whiteboard                     |
| max  | $1.60          | 60              | ask, whiteboard, quiz, flashcards   |

Changing a limit is a migration, never a client release or an env var. The
app displays the plan it is given and makes no access decisions of its own.
The old `AI_DAILY_QUESTION_LIMIT` env var is removed.

### Every AI call goes through a reserve → settle ledger

The ledger is `private.api047_ai_usage` over `private.ai_usage`:

1. **Reserve.** Before calling the provider, the API reserves the
   *worst-case* cost of the call, sized from the input and the maximum
   output tokens at the configured prices. This runs under a per-user
   advisory lock. The reservation is refused, with `plan_required`,
   `daily_limit` or `monthly_cap`, if the feature is not in the plan, the
   daily count is reached, or the settled costs this month plus open holds
   plus this hold would exceed the cap. The provider is never called after
   a refusal.
2. **Settle.** After the call, the hold is replaced by the actual cost,
   computed from the provider's own token counts
   (`ceil(in × input price + out × output price)`, in micro-dollars).
3. **Release.** If the call fails, the hold is released and nothing is
   charged.

A hold older than 15 minutes stops counting, so a crash cannot lock a
student out. Because reservations are serialised and sized at worst case,
concurrent requests cannot push a student over the cap. The integration
suite tests the race.

The cap is enforced against *our* computed cost. `AI_PRICE_INPUT_USD_PER_MTOK`
and `AI_PRICE_OUTPUT_USD_PER_MTOK` must therefore match the provider's price
list. The defaults are Together.ai's prices for `Qwen/Qwen3.5-9B`.

### Study sets are made once for each lesson version and shared

Quizzes (exactly 6 questions) and flashcards (6–12 cards) are stored in
`public.study_sets`, unique on `(resource_version_id, kind)`. The first Max
student to ask for a set pays for it. Every classmate who can see that
published version then gets the same set free. Only a revised lesson
produces a new set. This keeps Max's real cost far below its cap.

### Whiteboard photos use the existing file pipeline

A photo is uploaded with the new `notebook_photo` purpose (JPEG/PNG, 10 MB
limit, bound to a classroom in which the student is enrolled). It goes
through quarantine and the malware scan like any other file. The API reads
it only once it is clean, and checks its sha256 against the stored digest
before sending it to the model. An unreadable or blank board returns
`PHOTO_UNREADABLE` and the call is not settled beyond what was used.

### Privacy boundaries

- `public.notebook_entries` and `public.study_sets` have RLS on with no
  policies. Access is only through `api046_query` and `api046_command`, which
  check enrolment and ownership. A notebook is private to its student.
  Teachers and classmates cannot read it.
- Audit events record that a notebook entry was made, never its content.
- `ai_usage` stores costs and token counts, never prompts or model output.

### The grounded AI path stays gated

Whiteboard notes and study sets send a student's photo or a lesson's text to
the provider, which is the path ADR-0026 closed. The routes are behind
`AI_LESSON_TOOLS_ENABLED` (default `false`) and return
`AI_FEATURE_DISABLED` while it is off. It may be turned on only for
development, or after the provider DPA and a DPIA covering minors are in
place.

## Consequences

- Staging and production products `studafy_plus_monthly` and
  `studafy_max_monthly` stay unlisted until they exist in App Store Connect
  and Google Play and have been confirmed. They are listed only in synthetic
  and development.
- `student_notebook` products are deactivated. Existing entitlements to them
  grant nothing, because Lessons are free. The feature key stays valid in
  `billing_purchase_approvals` so historical rows remain readable.
- A new AI feature is added by giving it a `feature` value, a row in
  `ai_plan_limits`, and a `holdFor` size, then calling it through the same
  `metered()` helper. No feature can call the provider without the ledger.
