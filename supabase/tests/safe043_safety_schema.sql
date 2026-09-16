begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(24);

-- ---------------------------------------------------------------------------
-- SAFE-043 relations exist with the expected shape.
-- ---------------------------------------------------------------------------

select ok(
  (select count(*) from pg_tables
   where schemaname = 'public' and table_name in (
     'school_content_controls','safety_content_rules','reports','report_events',
     'report_evidence','report_attempts','user_blocks','legal_holds',
     'moderation_access_grants')) = 9::bigint,
  'all nine SAFE-043 tables exist'
);

select ok(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname in (
     'school_content_controls','safety_content_rules','reports','report_events',
     'report_evidence','report_attempts','user_blocks','legal_holds',
     'moderation_access_grants') and not c.relrowsecurity) = 0::bigint,
  'every SAFE-043 table has row level security enabled'
);

select is(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public'
     and table_name in (
       'school_content_controls','safety_content_rules','reports','report_events',
       'report_evidence','report_attempts','user_blocks','legal_holds',
       'moderation_access_grants')
     and grantee in ('anon','authenticated','service_role','studafy_api_runtime','studafy_worker_runtime')),
  0::bigint,
  'no runtime role has a direct table grant on any SAFE-043 table'
);

select is(
  (select count(*) from information_schema.column_privileges
   where table_schema = 'public'
     and table_name in (
       'school_content_controls','safety_content_rules','reports','report_events',
       'report_evidence','report_attempts','user_blocks','legal_holds',
       'moderation_access_grants')),
  0::bigint,
  'no column privileges exist on SAFE-043 tables'
);

-- The append-only sequences are closed to runtime roles but the audit
-- sequence grant expected by db021_grants.sql survives.
select ok(
  not has_sequence_privilege('service_role', 'public.report_events_id_seq', 'usage,select,update')
  and not has_sequence_privilege('authenticated', 'public.report_events_id_seq', 'usage')
  and not has_sequence_privilege('studafy_api_runtime', 'public.report_evidence_id_seq', 'usage'),
  'append-only identity sequences are closed to runtime roles'
);

select has_column('public', 'reports', 'enqueue_seq',
  'reports gains the queue cursor sequence');
select has_column('public', 'reports', 'evidence_snapshot',
  'reports records the submitted evidence snapshot');
select has_column('public', 'reports', 'classifier_confidence',
  'reports records the advisory classifier signal');

select ok(
  (select data_type from information_schema.columns
   where table_schema = 'public' and table_name = 'reports'
     and column_name = 'classifier_confidence') = 'numeric',
  'classifier confidence is numeric (bounded by check, never a vote)'
);

-- ---------------------------------------------------------------------------
-- Mutability guards
-- ---------------------------------------------------------------------------

select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_reject_mutation_report_events'),
  'report_events is append-only'
);
select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_reject_mutation_report_evidence'),
  'report_evidence is append-only'
);
select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_immutable_reports'),
  'report identity columns are immutable'
);
select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_immutable_block'),
  'block identity columns are immutable'
);
select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_immutable_legal_hold'),
  'legal hold identity columns are immutable'
);
select ok(
  exists (select 1 from pg_trigger
          where tgname = 'safe043_immutable_moderation_grant'),
  'moderation grant identity columns are immutable'
);

-- ---------------------------------------------------------------------------
-- Enum values are the reviewed, stable contract
-- ---------------------------------------------------------------------------

select is(
  (select array_agg(enumlabel::text order by enumlabel)
   from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'report_status'),
  array['escalated','on_hold','queued','resolved','submitted','under_review','withdrawn'],
  'report_status enum matches the timeline contract'
);

select is(
  (select array_agg(enumlabel::text order by enumlabel)
   from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'report_resolution'),
  array['no_action','not_upheld','partial','upheld'],
  'report_resolution enum matches the disposition contract'
);

select is(
  (select array_agg(enumlabel::text order by enumlabel)
   from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'report_event_kind'),
  array[
    'appeal','assign','evidence_added','escalate','hold','queued','release_hold',
    'reporter_alerted','resolve','submitted','triage','withdraw'
  ],
  'report_event_kind enum matches the auditable timeline contract'
);

select is(
  (select array_agg(enumlabel::text order by enumlabel)
   from pg_enum e join pg_type t on t.oid = e.enumtypid
   where t.typname = 'moderation_access_status'),
  array['active','approved','denied','expired','pending','revoked'],
  'moderation_access_status enum matches the grant lifecycle contract'
);

-- ---------------------------------------------------------------------------
-- Indexes the queue path needs
-- ---------------------------------------------------------------------------

select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'reports'
            and indexname = 'reports_queue_idx'),
  'reports_queue_idx exists for the moderation queue'
);
select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'reports'
            and indexname = 'reports_enqueue_idx'),
  'reports_enqueue_idx exists for queue cursor pagination'
);
select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'user_blocks'
            and indexname = 'user_blocks_pair_forward_idx'),
  'forward block-pair lookup is indexed'
);
select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'user_blocks'
            and indexname = 'user_blocks_pair_reverse_idx'),
  'reverse block-pair lookup is indexed (symmetric enforcement)'
);
select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'legal_holds'
            and indexname = 'legal_holds_subject_idx'),
  'active legal holds on a subject are indexed'
);
select ok(
  exists (select 1 from pg_indexes
          where schemaname = 'public' and tablename = 'report_attempts'
            and indexname = 'report_attempts_reporter_idx'),
  'report dedupe window lookups are indexed'
);