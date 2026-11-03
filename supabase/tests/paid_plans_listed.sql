-- Paid plans listed from launch (202610020002, ADR-0034), and Studafy AI
-- Marking from launch too (202611030070, DL-079).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(7);

select is((select count(*)::int from public.store_products
    where feature_key in ('studafy_plus', 'studafy_max', 'family_plus', 'family_plus_large')
      and environment = 'production' and active and storefront_listed),
  8, 'Plus, Max and both Family+ tiers are listed in production on both stores');
select is((select count(*)::int from public.store_products
    where feature_key in ('studafy_plus', 'studafy_max', 'family_plus', 'family_plus_large')
      and environment = 'staging' and active and storefront_listed),
  8, 'and in staging');
select is((select count(*)::int from public.store_products
    where feature_key in ('student_notebook', 'student_ai', 'teacher_ai_grading', 'parent_insights')
      and environment in ('staging', 'production') and storefront_listed),
  0, 'retired products stay unlisted');
-- DL-079: the teachers' plan is sold from launch, on both stores.
select results_eq(
  $$select platform::text, environment, store_product_id from public.store_products
    where feature_key = 'studafy_ai_marking'
      and environment in ('staging', 'production') and active and storefront_listed
    order by environment, platform::text$$,
  $$values ('app_store', 'production', 'studafy_ai_marking_monthly'),
           ('play_store', 'production', 'studafy_ai_marking_monthly'),
           ('app_store', 'staging', 'studafy_ai_marking_monthly'),
           ('play_store', 'staging', 'studafy_ai_marking_monthly')$$,
  'Studafy AI Marking is listed in staging and production on both stores');
-- Exactly these, per store: Family+ is named differently on each
-- (202611030030).
select is((select array_agg(store_product_id order by store_product_id)
    from public.store_products
    where environment = 'production' and platform = 'app_store' and storefront_listed),
  array['studafy_ai_marking_monthly', 'studafy_family_4_monthly',
        'studafy_family_8_monthly', 'studafy_max_monthly', 'studafy_plus_monthly'],
  'the App Store in production offers exactly the five launch subscriptions');
select is((select array_agg(store_product_id order by store_product_id)
    from public.store_products
    where environment = 'production' and platform = 'play_store' and storefront_listed),
  array['studafy_ai_marking_monthly', 'studafy_family_plus_8_monthly',
        'studafy_family_plus_monthly', 'studafy_max_monthly', 'studafy_plus_monthly'],
  'Google Play in production offers exactly the five launch subscriptions');
select results_eq(
  $$select platform::text, feature_key, store_product_id from public.store_products
    where feature_key in ('family_plus', 'family_plus_large')
      and environment = 'production'
    order by platform::text, feature_key$$,
  $$values ('app_store', 'family_plus', 'studafy_family_4_monthly'),
           ('app_store', 'family_plus_large', 'studafy_family_8_monthly'),
           ('play_store', 'family_plus', 'studafy_family_plus_monthly'),
           ('play_store', 'family_plus_large', 'studafy_family_plus_8_monthly')$$,
  'Family+ uses its own ids on the App Store and keeps them on Google Play');

select * from finish();
rollback;
