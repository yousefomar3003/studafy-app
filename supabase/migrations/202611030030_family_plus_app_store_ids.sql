-- Family+ has its own product ids on the App Store.
--
-- The owner named the App Store products for the two Family+ tiers before
-- creating them in App Store Connect (2026-11-03):
--
--   * family_plus        (up to 4 children) -> studafy_family_4_monthly
--   * family_plus_large  (up to 8 children) -> studafy_family_8_monthly
--
-- Google Play keeps studafy_family_plus_monthly and
-- studafy_family_plus_8_monthly: those products already exist in Play
-- Console, and a store product id can never be renamed there. The catalogue
-- is per platform (unique on platform, environment, store_product_id), and
-- the app reads only its own platform's rows, so the two stores may name the
-- same plan differently; both lead to the same feature key.
--
-- The App Store rows are renamed in place rather than replaced. No App Store
-- product ever existed under the old ids, so nothing was bought with them,
-- and a purchase row points at the catalogue row by its uuid, never by the
-- store's id. Listing (storefront_listed) and active stay as they were.

update public.store_products
set store_product_id = case store_product_id
      when 'studafy_family_plus_monthly' then 'studafy_family_4_monthly'
      when 'studafy_family_plus_8_monthly' then 'studafy_family_8_monthly'
    end,
    updated_at = now()
where platform = 'app_store'
  and feature_key in ('family_plus', 'family_plus_large')
  and store_product_id in ('studafy_family_plus_monthly', 'studafy_family_plus_8_monthly');
