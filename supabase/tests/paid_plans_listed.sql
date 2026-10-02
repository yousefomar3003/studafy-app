-- Paid plans listed from launch (202610020002, ADR-0034).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(4);

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
select is((select array_agg(distinct store_product_id order by store_product_id)
    from public.store_products
    where environment = 'production' and storefront_listed),
  array['studafy_family_plus_8_monthly', 'studafy_family_plus_monthly',
        'studafy_max_monthly', 'studafy_plus_monthly'],
  'production offers exactly the four launch subscriptions');

select * from finish();
rollback;
