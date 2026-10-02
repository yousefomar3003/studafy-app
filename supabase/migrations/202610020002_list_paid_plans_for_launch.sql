-- Paid plans listed from launch (ADR-0034).
--
-- The owner decided on 2026-10-02 that Studafy Plus, Studafy Max and both
-- Family+ tiers are sold from the first release. Until now their staging and
-- production rows were unlisted (ADR-0029 kept them so until the store
-- products were confirmed), which means the catalogue offered nothing and a
-- new purchase of them was refused.
--
-- Listing them is safe before the store products exist: the app shows a
-- plan only with the price and terms the store itself returns, and the
-- server grants a plan only from a verified store receipt. Retired products
-- (student_notebook, student_ai, teacher_ai_grading, parent_insights) stay
-- unlisted.

update public.store_products
set storefront_listed = true, updated_at = now()
where feature_key in ('studafy_plus', 'studafy_max', 'family_plus', 'family_plus_large')
  and environment in ('staging', 'production')
  and active
  and not storefront_listed;
