# Studafy Plus and Studafy Max

Replaces the retired Student Notebook subscription. Design and rationale are in
[ADR-0029](../adr/ADR-0029-study-plans-and-ai-lesson-tools.md).

## What is sold

| Plan | Price (US storefront) | Store product ID | Adds |
| ---- | --------------------- | ---------------- | ---- |
| Studafy Free | free | - | Lessons, the notebook for each class, typed personal notes, the AI Tutor; **40,000 tokens a week** (renews Monday 00:00 UTC) |
| Studafy Plus | US$3.99 / month | `studafy_plus_monthly` | Photos in AI Tutor questions, whiteboard and screenshot → notes, lesson summaries and study notebooks; **3,000,000 tokens a month**, cost cap US$0.80 |
| Studafy Max | US$5.99 / month | `studafy_max_monthly` | Everything in Plus, quizzes and flashcards (also from the student's own notes); **6,000,000 tokens a month**, cost cap US$1.60 |

The allowances replaced the old "10 / 40 / 60 questions a day" on 2026-10-06
(ADR-0037). The app shows usage as a bar, never as token counts (ADR-0039).
Monthly allowances renew on the 1st, 00:00 UTC.

Teachers have their own plan, **Studafy AI Marking** (`studafy_ai_marking`,
product `studafy_ai_marking_monthly`), for AI-suggested marks: see
[Studafy AI Marking](#studafy-ai-marking-teachers) below.

Store-local prices and currencies come from the store at checkout. The app
never hard-codes a price.

Both plans are auto-renewing subscriptions sold through Apple In-App Purchase
and Google Play Billing. Stripe is not used for them (ADR-0009): the stores
require in-app digital content to be sold in-app.

## Where the rules live

- **Who has which plan:** `private.study_plan(user)`. It reads verified store
  entitlements in the `notebook_runtime` environment and comp grants in
  `private.study_plan_grants`.
- **What each plan permits:** `private.ai_plan_limits(plan)`. This holds the
  token allowance (weekly on Free, monthly on Plus and Max), the monthly cost
  cap (Plus $0.80, Max $1.60) and the features. Changing any of these is a
  migration.
- **Spending:** `private.api047_ai_usage` reserves the worst-case cost before
  every AI call, then settles it to the real cost or releases it.
- **Student purchases (DL-071, 2026-10-20):** a student buys Plus or Max
  themselves, in their own app, with no approval step in Studafy. The store
  account on the phone pays; for a child, that account should be a parent's
  or parent-controlled, and Google Family Link or Apple Ask to Buy is where a
  parent approves. The server grants the plan from the verified purchase
  alone (`private.billing_resolve_beneficiary`,
  `private.billing_apply_verification`, migration
  `202610210010_student_direct_purchase.sql`).
- **The school switch:** `public.school_billing_settings.self_purchase_enabled`
  is on by default, and a school with no row counts as on. It is kept for a
  future opt-out; nothing needs an administrator to sell.
- **Family+** is unchanged: only a verified guardian of at least one child
  can buy it.
- **Restore purchases** is on the profile: Account → Subscription, a small
  link at the bottom (students and parents alike). The Plans and Family+
  screens no longer show it.

## Listing

The products exist in every environment. They are **listed** (offered in the
catalogue) only in `synthetic` and `development`.

Before listing them in `staging` or `production`, do both of these:

1. Create both subscriptions in App Store Connect and Google Play with
   exactly the IDs above, in one subscription group.
2. Confirm them there, then set `storefront_listed = true` for that
   environment in a migration.

## Turning on real (sandbox) purchases

The full setup - both store consoles, webhooks, every credential and the
sandbox test checklist - is in [subscriptions.md](subscriptions.md). In
short:

The API needs these settings. The names are in `.env.example`; keep the values
in the secret manager, never in the repo.

- `PAY071_BILLING_ENABLED=true` and `PAY071_ENVIRONMENT` (`development` for
  local sandbox testing)
- **Apple:** `APPLE_BUNDLE_ID`, `APPLE_APP_APPLE_ID`, `APPLE_ENVIRONMENT`
  (`Sandbox`), `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`,
  `APPLE_ROOT_CERTIFICATES_BASE64`
- **Google:** `GOOGLE_PACKAGE_NAME`, `GOOGLE_SERVICE_ACCOUNT_JSON`

Buy with an App Store sandbox tester account. You are not charged.

## Testing a plan without a purchase

On a local database only, give an account a plan for a day:

```sql
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
values ('<user uuid>', 'max', 'local testing', now() + interval '1 day');
```

Grants are for support and testing. They never touch the store ledger.

### Family+ without a purchase

A parent's Family+ has comp grants of its own (2026-10-19, migration
`202610190010_family_plus_grants.sql`), in `private.family_plus_grants`:

| Column | Value |
| ------ | ----- |
| `user_id` | the parent's profile id |
| `tier` | `family_plus` (up to 4 children) or `family_plus_large` (up to 8) |
| `reason` | why, 3 to 200 characters |
| `starts_at` | defaults to now |
| `ends_at` | when it ends; after `starts_at` |

Like study-plan grants, only an operator with direct database access writes
them; no API does, and no runtime role can read the table. A live grant
counts exactly as a live store plan of that tier:

- `private.family_plus_seats(parent)` takes the larger of the grant and any
  store plan, so `family_plus_covered`, the `parent_insights_has_access` gate
  and `getFamilyInsights` all honour it.
- The app learns it from `GET /v1/me/guardian-links`: each link says whether
  Family+ is open for that child (`familyPlus`), and `familyPlan` names the
  parent's plan with `granted: true`. This read is served whether or not
  store billing is, so a grant works on the test copy, which runs with
  `PAY071_BILLING_ENABLED=false`.
- Where billing is on, `GET /v1/billing/entitlements` also lists the grant as
  a family plan row with `granted: true` and no platform or product.
- The app shows "Given by Studafy, nothing to pay" on the plan and offers no
  store subscription to manage or cancel.

Give a parent Family+ for up to 8 children for a year, by email:

```sql
insert into private.family_plus_grants (user_id, tier, reason, ends_at)
select p.id, 'family_plus_large', 'App store reviewer account',
  now() + interval '1 year'
from auth.users u join public.profiles p on p.id = u.id
where u.email = 'parent@review.studafy.com';
```

End one early with `update private.family_plus_grants set ends_at = now()
where ...`; the next read covers nobody. Rows are kept, so a grant's history
stays visible.

### The store reviewers' accounts

`scripts/provision-reviewer-school.ts` gives the three reviewer accounts their
plans for a year, with the reason `App store reviewer account`: Studafy Max to
the teacher, the student and the parent, and Family+ for up to 8 children to
the parent. A re-run adds nothing while a grant has more than 30 days left.
See [reviewer-access.md](../store/reviewer-access.md).

## Studafy AI Marking (teachers)

A teacher's own monthly plan for AI-suggested marks (DL-073,
[ADR-0046](../adr/ADR-0046-ai-suggested-marking.md)). The AI suggests a mark
for written answers and hand-ins against the teacher's reference; the
teacher decides, and a suggestion never becomes a mark until the teacher
saves one. It is not the retired `teacher_ai_grading`.

| | |
| --- | --- |
| Feature key | `studafy_ai_marking` |
| Store product ID | `studafy_ai_marking_monthly`, auto-renewing, 1 month |
| Price | Set by the owner in the stores (not decided yet) |
| Who may buy | A teacher with an active teacher membership, for themselves |
| Allowance | Per teacher per calendar month (UTC): 4,000,000 tokens, a US$2 cost cap, 20 pages per hand-in (`private.marking_limits()`) |
| Listed | `synthetic` and `development` only. `staging` and `production` have unlisted rows until the owner creates the product in both stores and a migration lists it |
| Who has it | `private.marking_plan_active(user)`: a verified store entitlement in the runtime's environment, or a live comp grant |
| Server switch | `MARKING_SUGGESTIONS_ENABLED` on the API and the worker, plus the AI provider. On in the test copy, off in production until launch |

### Studafy AI Marking without a purchase

Comp grants live in `private.marking_plan_grants`, written only by an
operator with direct database access (app review, pilots). Give the review
teacher the plan for a year:

```sql
insert into private.marking_plan_grants (user_id, reason, ends_at)
select p.id, 'App store reviewer account', now() + interval '1 year'
from auth.users u join public.profiles p on p.id = u.id
where u.email = 'teacher@review.studafy.com';
```

`reason` is 3 to 200 characters and `ends_at` must be after `starts_at`
(default now). End one early with `update private.marking_plan_grants set
ends_at = now() where ...`. A grant is deleted with the teacher's account.

## The AI switch

Whiteboard notes, quizzes and flashcards also need `AI_LESSON_TOOLS_ENABLED=true`
on the API. It is off by default. Study notebooks are written by the worker
(2026-10-16), so they need the same switch and provider on the worker too
(`docs/deployment/fly-io.md`). Turn it on for real students only once the
provider DPA and the minors' DPIA are in place (ADR-0026, ADR-0029).
