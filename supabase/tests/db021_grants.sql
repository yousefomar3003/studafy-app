begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

select is(
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity),
  0::bigint,
  'every public application table has RLS enabled'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema='public' and grantee='anon'),
  0::bigint,
  'anonymous has no public application table grants'
);

select is(
  (select count(*) from information_schema.column_privileges
   where table_schema='public' and grantee='anon'),
  0::bigint,
  'anonymous has no public application column grants'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and has_function_privilege('anon',p.oid,'execute')),
  0::bigint,
  'anonymous can execute no public application RPC'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema='public' and grantee='authenticated'),
  0::bigint,
  'authenticated has no table-wide privileges'
);

select is(
  (select count(*) from information_schema.column_privileges
   where table_schema='public' and grantee='authenticated'
     and privilege_type <> 'SELECT'),
  0::bigint,
  'authenticated column grants are read-only'
);

select is(
  (select array_agg(distinct table_name order by table_name)
   from information_schema.column_privileges
   where table_schema='public' and grantee='authenticated'),
  array[
    'announcements','assessment_questions','assessments','assignments',
    'attendance_records','class_schedules','classroom_staff','classrooms',
    'consent_records','enrollments','grade_results','guardian_links',
    'lesson_materials','lesson_sessions','meeting_deliveries','meetings',
    'memberships','notifications','profiles',
    'resource_publications','resource_versions','resources','schools',
    'students','submissions','subscription_entitlements','terms',
    'wellbeing_events'
  ]::information_schema.sql_identifier[],
  'authenticated read tables exactly match the DB-021 allowlist'
);

select ok(
  not has_column_privilege('authenticated','public.lesson_materials','storage_path','select'),
  'storage paths are excluded from direct reads'
);
select ok(
  not has_column_privilege('authenticated','public.assessment_questions','preferred_answer','select'),
  'assessment answer keys are excluded from direct reads'
);
select ok(
  not has_column_privilege('authenticated','public.ai_grading_drafts','private_scan_path','select'),
  'AI private scan paths are excluded from direct reads'
);

select is(
  (select array_agg(p.proname order by p.proname)
   from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public'
     and has_function_privilege('authenticated',p.oid,'execute')),
  array['mark_notifications_read','record_policy_consent']::name[],
  'authenticated public RPC surface contains only two bounded commands'
);

select is(
  (select array_agg(distinct table_name order by table_name)
   from information_schema.role_table_grants
   where table_schema='public' and grantee='service_role'),
  array[
    'account_deletion_requests','assessment_questions',
    'audit_events','enrollments','grade_results','guardian_links',
    'meeting_deliveries','meetings','notifications',
    'students','subscription_entitlements'
  ]::information_schema.sql_identifier[],
  'service role table set exactly matches contained Edge Function use'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema='public' and grantee='service_role'
     and privilege_type in ('DELETE','TRUNCATE','REFERENCES','TRIGGER')),
  0::bigint,
  'service role has no destructive or ownership-changing table grants'
);

select is(
  (select array_agg(object_name order by object_name)
   from information_schema.usage_privileges
   where object_schema='public' and object_type='SEQUENCE'
     and grantee='service_role'),
  array['audit_events_id_seq']::information_schema.sql_identifier[],
  'service role can use only the audit identity sequence'
);
select ok(
  not has_sequence_privilege(
    'service_role','public.audit_events_id_seq','select'
  ),
  'service role receives sequence usage without sequence read access'
);

-- Superseded in part by AUTH-030, which activates studafy_api_runtime with
-- LOGIN and EXECUTE on the private auth_* function surface only. The DB-021
-- guarantees that matter — no inherited privilege, no RLS bypass, and no
-- table grant (asserted separately below) — are unchanged, and the worker
-- role remains entirely inactive. auth030_grants.sql asserts the exact new
-- surface.
select is(
  (select count(*) from pg_roles
   where rolname in ('studafy_api_runtime','studafy_worker_runtime')
     and not rolinherit and not rolbypassrls
     and rolcanlogin = (rolname = 'studafy_api_runtime')),
  2::bigint,
  'runtime roles never inherit or bypass RLS; only the API role is activated'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where grantee in ('studafy_api_runtime','studafy_worker_runtime')),
  0::bigint,
  'future runtime roles have no table grants'
);

select ok(
  not has_schema_privilege('anon','private','usage')
  and has_schema_privilege('authenticated','private','usage'),
  'private policy helpers are available only to authenticated policy evaluation'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname in (
     'is_school_member','is_class_teacher','can_access_student',
     'can_access_classroom','handle_new_auth_user','set_updated_at',
     'derive_school_id','reject_append_only_mutation'
   )),
  0::bigint,
  'policy and trigger helpers are absent from the public RPC schema'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='private'
     and p.proname in (
       'handle_new_auth_user','set_updated_at','derive_school_id',
       'reject_append_only_mutation','reject_immutable_columns'
     )
     and (has_function_privilege('anon',p.oid,'execute')
       or has_function_privilege('authenticated',p.oid,'execute'))),
  0::bigint,
  'trigger helpers cannot be directly executed by client roles'
);

select is(
  (select count(*) from pg_policies
   where schemaname='public' and cmd <> 'SELECT'),
  0::bigint,
  'public client policies authorize no direct mutations'
);

create table public.db021_default_table_probe (id bigint);
create sequence public.db021_default_sequence_probe;
create function public.db021_default_function_probe()
returns void language sql as $$select$$;

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema='public' and table_name='db021_default_table_probe'
     and grantee in ('PUBLIC','anon','authenticated','service_role')),
  0::bigint,
  'future public tables receive no client or service grants by default'
);

select ok(
  not has_sequence_privilege('anon','public.db021_default_sequence_probe','usage')
  and not has_sequence_privilege('authenticated','public.db021_default_sequence_probe','usage')
  and not has_sequence_privilege('service_role','public.db021_default_sequence_probe','usage'),
  'future public sequences receive no client or service grants by default'
);

select ok(
  not has_function_privilege('anon','public.db021_default_function_probe()','execute')
  and not has_function_privilege('authenticated','public.db021_default_function_probe()','execute')
  and not has_function_privilege('service_role','public.db021_default_function_probe()','execute'),
  'future public functions receive no client or service execution by default'
);

select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname in ('public','private') and p.prosecdef
     and not ('search_path=""' = any(coalesce(p.proconfig,array[]::text[])))),
  0::bigint,
  'every application SECURITY DEFINER function has an empty search_path'
);

select * from finish();
rollback;
