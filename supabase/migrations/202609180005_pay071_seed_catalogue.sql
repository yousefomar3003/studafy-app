-- PAY-071 catalogue seed.
--
-- `synthetic` gets all four products on both platforms, listed, so the
-- ledger/derivation/webhook machinery is fully exercised by tests without
-- ever touching a real store console.
--
-- `development`/`staging`/`production` get only Student Notebook (listed)
-- and Parent Insights (present but NOT listed - ADR-0009/§29 legal
-- sign-off is still open). No rows are seeded for Student AI or Teacher AI
-- grading outside `synthetic` at all: AI-072 has not resolved to enable, and
-- the instruction is to not create those SKUs before then. Store product ids
-- below are the product owner's intended identifiers (see instructions.md
-- §13); they must be confirmed against the actual App Store Connect/Play
-- Console listings before `storefront_listed` is ever flipped on for a
-- non-synthetic environment, tracked in docs/evidence/pay-071/README.md.

insert into public.store_products
  (feature_key, platform, environment, store_product_id, active, storefront_listed)
values
  ('parent_insights', 'app_store', 'synthetic', 'studafy_parent_insights_monthly', true, true),
  ('parent_insights', 'play_store', 'synthetic', 'studafy_parent_insights_monthly', true, true),
  ('student_notebook', 'app_store', 'synthetic', 'studafy_student_notebook_monthly', true, true),
  ('student_notebook', 'play_store', 'synthetic', 'studafy_student_notebook_monthly', true, true),
  ('student_ai', 'app_store', 'synthetic', 'studafy_student_ai_monthly', true, true),
  ('student_ai', 'play_store', 'synthetic', 'studafy_student_ai_monthly', true, true),
  ('teacher_ai_grading', 'app_store', 'synthetic', 'studafy_teacher_ai_grading_monthly', true, true),
  ('teacher_ai_grading', 'play_store', 'synthetic', 'studafy_teacher_ai_grading_monthly', true, true),

  ('student_notebook', 'app_store', 'development', 'studafy_student_notebook_monthly', true, true),
  ('student_notebook', 'play_store', 'development', 'studafy_student_notebook_monthly', true, true),
  ('parent_insights', 'app_store', 'development', 'studafy_parent_insights_monthly', true, false),
  ('parent_insights', 'play_store', 'development', 'studafy_parent_insights_monthly', true, false),

  ('student_notebook', 'app_store', 'staging', 'studafy_student_notebook_monthly', true, true),
  ('student_notebook', 'play_store', 'staging', 'studafy_student_notebook_monthly', true, true),
  ('parent_insights', 'app_store', 'staging', 'studafy_parent_insights_monthly', true, false),
  ('parent_insights', 'play_store', 'staging', 'studafy_parent_insights_monthly', true, false),

  ('student_notebook', 'app_store', 'production', 'studafy_student_notebook_monthly', true, true),
  ('student_notebook', 'play_store', 'production', 'studafy_student_notebook_monthly', true, true),
  ('parent_insights', 'app_store', 'production', 'studafy_parent_insights_monthly', true, false),
  ('parent_insights', 'play_store', 'production', 'studafy_parent_insights_monthly', true, false)
on conflict (platform, environment, store_product_id) do nothing;
