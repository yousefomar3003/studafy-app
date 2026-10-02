# ADR-0034: Studafy Plus, Max and Family+ are live from launch

- Status: Accepted. The production AI switch is conditional on the DPA and
  DPIA below.
- Date: 2026-10-02
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Supersedes in part: [ADR-0029](ADR-0029-study-plans-and-ai-lesson-tools.md):
  its rule that `AI_LESSON_TOOLS_ENABLED` is for development only until some
  later date, and its rule that staging and production products stay unlisted
- Relates to: [ADR-0026](ADR-0026-ai072-remove-ai-capability.md) (the DPA and
  DPIA conditions, which still apply), ADR-0032 (subscription lifecycle),
  `docs/release/rel-002-store-accounts.md`

## Context

ADR-0029 built Studafy Plus (whiteboard photo to notes) and Studafy Max
(quizzes and flashcards from a lesson) with a capped AI ledger. It kept two
things off:

1. `AI_LESSON_TOOLS_ENABLED` was allowed only in development, or after a
   provider DPA and a DPIA covering minors were in place. Those features send
   a student's photo or a lesson's text to the AI provider, the path ADR-0026
   closed.
2. Every staging and production row in `store_products` for `studafy_plus`,
   `studafy_max`, `family_plus` and `family_plus_large` was unlisted. The
   catalogue therefore offered no plan, and the server refused a new purchase
   of them.

On 2026-10-02 the owner decided that Plus and Max are part of the first
release, not a later addition. Revenue planning assumes all three paid
products from day one: Plus and Max make up about 70% of the expected
revenue. Family+ has no AI and was blocked only by the listing.

## Decision

### The plans are listed now, in every environment

Migration `202610020002_list_paid_plans_for_launch.sql` lists the four launch
subscriptions in staging and production:

| Store product id                | Feature key         | Price          |
| ------------------------------- | ------------------- | -------------- |
| `studafy_plus_monthly`          | `studafy_plus`      | US$3.99/month  |
| `studafy_max_monthly`           | `studafy_max`       | US$5.99/month  |
| `studafy_family_plus_monthly`   | `family_plus`       | US$2.99/month  |
| `studafy_family_plus_8_monthly` | `family_plus_large` | US$4.99/month  |

Retired products (`student_notebook`, `student_ai`, `teacher_ai_grading`,
`parent_insights`) stay unlisted. `supabase/tests/paid_plans_listed.sql`
checks this in CI.

Listing before the store products exist sells nothing by accident:

- the app shows a plan only with the price and terms the store returns, and
  refuses the purchase ("Subscription terms are unavailable") if the store
  does not know the product;
- the server grants a plan only from a verified store receipt (ADR-0032).

The four products must be created in App Store Connect and Google Play
Console with exactly these ids before release. This is now a release gate in
`docs/release/rel-002-store-accounts.md`.

### The lesson AI ships switched on

Production runs with `AI_LESSON_TOOLS_ENABLED=true`. The code default stays
`false`, so a missing setting fails closed and the routes answer
`AI_FEATURE_DISABLED`.

The ADR-0026 conditions are unchanged. They become **launch blockers** rather
than a reason to ship without the features:

1. a signed data processing agreement with the AI provider that covers
   processing of minors' data; and
2. a DPIA extended to AI processing of minors' data.

The production flag is set to `true` only once both exist. Without them, the
release waits; it does not go out with Plus and Max quietly disabled while
they are still sold.

The hosted development environment has had the flag on since 2026-10-02, for
end-to-end testing with **synthetic material only**. Testers get a plan
through `private.study_plan_grants`, because hosted billing is off.

### Provider

The provider is Together.ai (`https://api.together.xyz`), model
`Qwen/Qwen3.5-9B`, pinned as the only allowed origin (ADR-0026's SEC-001
fix). On 2026-10-02 the model was verified to accept image input, which
whiteboard notes need. If Together cannot sign a DPA covering minors, the
provider changes before launch. That means a new `AI_BASE_URL`, `AI_MODEL`
and `AI_PRICE_*`, a review of the pinned origin, and the per-question costs
in the revenue estimate are redone. It does not mean shipping without the
features.

## Consequences

- The catalogue offers Plus, Max and Family+ in every environment as soon as
  the store products exist. Purchase, guardian approval, refunds and caps
  follow ADR-0029 and ADR-0032 unchanged.
- The release checklist gains three hard items: the DPA, the DPIA, and the
  four store products. The privacy policy's §6 (AI study tools) must name the
  provider and match the DPIA before submission.
- ADR-0029's caps ($0.80 Plus, $1.60 Max, a month) and the reserve-settle
  ledger are what keep a paid student's AI cost below the price. Changing a
  price or a cap needs both a migration and a check against the store prices
  above.
