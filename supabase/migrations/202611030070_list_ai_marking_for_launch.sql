-- Studafy AI Marking is sold from launch (DL-079).
--
-- The owner decided on 2026-11-03 that the teachers' plan "Studafy AI
-- Marking" (DL-073, US$7.99 a month by DL-075, ADR-0046) is on in
-- production from the first release, alongside MARKING_SUGGESTIONS_ENABLED
-- in fly.api.toml and fly.worker.toml. Its staging and production rows were
-- created unlisted by 202610210060_marking_suggestions.sql, to be listed by
-- a later migration once the owner said so; this is that migration, in the
-- same form as 202610020002 for the student and family plans.
--
-- Listing it is safe before the store product is approved: the app shows a
-- plan only with the price and terms the store itself returns, and the
-- server grants it only from a verified store receipt. The product id is
-- studafy_ai_marking_monthly on both stores.

update public.store_products
set storefront_listed = true, updated_at = now()
where feature_key = 'studafy_ai_marking'
  and environment in ('staging', 'production')
  and active
  and not storefront_listed;
