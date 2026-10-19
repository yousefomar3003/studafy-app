# Studafy Plus and Studafy Max

Replaces the retired Student Notebook subscription. Design and rationale are in
[ADR-0029](../adr/ADR-0029-study-plans-and-ai-lesson-tools.md).

## What is sold

| Plan | Price (US storefront) | Store product ID | Adds |
| ---- | --------------------- | ---------------- | ---- |
| Studafy Free | free | - | Lessons, the notebook for each class, 10 questions a day |
| Studafy Plus | US$3.99 / month | `studafy_plus_monthly` | Whiteboard photo → notebook notes; 40 questions a day |
| Studafy Max | US$5.99 / month | `studafy_max_monthly` | Everything in Plus, quizzes and flashcards; 60 questions a day |

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
  monthly AI cap (Plus $0.80, Max $1.60), the questions a day, and the
  features. Changing any of these is a migration.
- **Spending:** `private.api047_ai_usage` reserves the worst-case cost before
  every AI call, then settles it to the real cost or releases it.
- **Student purchases:** a student's own purchase needs a verified guardian's
  approval, exactly as before.

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

## The AI switch

Whiteboard notes, quizzes and flashcards also need `AI_LESSON_TOOLS_ENABLED=true`
on the API. It is off by default. Study notebooks are written by the worker
(2026-10-16), so they need the same switch and provider on the worker too
(`docs/deployment/fly-io.md`). Turn it on for real students only once the
provider DPA and the minors' DPIA are in place (ADR-0026, ADR-0029).
