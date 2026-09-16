-- SAFE-043 schema: communications safety and safeguarding tables. This is
-- the storage half only; none of it is reachable until
-- 202609170002_safe043_surface.sql extends the private.authz_authorize /
-- api042_query / api042_command chain, so an unextended database exposes no
-- report, block, moderation or legal-hold operation at all.
--
-- Same discipline as API-042 S4 (202609160005): RLS enabled, every direct
-- grant revoked from anon/authenticated/service_role/runtime roles, and all
-- access through SECURITY DEFINER functions. instructions.md section 15 and
-- Part 4D require that report/moderator/evidence access is narrow, audited,
-- least-privilege and time-bounded, so none of these tables is readable by
-- the client roles even when the SQL surface is extended.
--
-- Append-only relations (report_events, report_evidence) reuse
-- private.reject_append_only_mutation() the same way messages/audit_events
-- do; mutable lifecycle rows get private.reject_immutable_columns() pins for
-- their relationship columns and private.set_updated_at() for updated_at.

create type public.report_kind as enum ('message', 'conversation', 'user');

-- submitted -> queued (auto) -> under_review (triage) -> resolved | escalated
-- | on_hold. withdrawn is the reporter's own retraction path.
create type public.report_status as enum (
  'submitted', 'queued', 'under_review', 'on_hold', 'escalated', 'resolved',
  'withdrawn'
);

-- Only ever set together with status 'resolved'. An escalated report keeps a
-- null resolution until the school/platform closes it out explicitly.
create type public.report_resolution as enum (
  'upheld', 'not_upheld', 'partial', 'no_action'
);

create type public.report_event_kind as enum (
  'submitted', 'queued', 'triage', 'assign', 'resolve', 'escalate', 'hold',
  'release_hold', 'appeal', 'withdraw', 'evidence_added', 'reporter_alerted'
);

create type public.moderation_access_status as enum (
  'pending', 'approved', 'active', 'expired', 'revoked', 'denied'
);

-- Per-school safety configuration. A school with no row reads the
-- conservative defaults the dispatcher materialises (messaging off for the
-- surface's own gate, strict filtering, standard SLAs); the row is only
-- written when a school administrator changes something. school_id is the
-- natural key because configuration is per tenant, never global.
create table public.school_content_controls (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null unique references public.schools(id) on delete cascade,
  messaging_enabled boolean not null default false,
  content_filter_level text not null default 'strict'
    check (content_filter_level in ('off', 'moderate', 'strict')),
  -- Advisory classifier pre-flagging for the review queue. Never the sole
  -- basis for a disposition: every resolve/escalate is a human moderator
  -- action with an audit event (instructions.md section 15).
  classifier_assist_enabled boolean not null default false,
  -- Where a reporter and an appellant are told to direct a follow-up.
  support_contact text check (support_contact is null or length(support_contact) between 3 and 320),
  -- Partial overrides of the standard first-response SLAs, e.g.
  -- {"critical":4,"high":24,"medium":48,"low":72}. Null means the defaults.
  sla_hours jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Per-school keyword/phrase rule set. Seeded (lazily, per school) with the
-- baseline categories a school is expected to monitor; a school may add its
-- own rows. Rows are never deleted by the API, only deactivated, so the
-- filter history that produced an action remains answerable later.
create table public.safety_content_rules (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  name text not null check (length(name) between 1 and 200),
  category text not null check (
    category in (
      'bullying', 'harassment', 'self_harm', 'abuse', 'violence',
      'sexual_content', 'hate', 'personal_data', 'other'
    )
  ),
  pattern_type text not null default 'phrase'
    check (pattern_type in ('keyword', 'phrase')),
  pattern text not null check (length(pattern) between 1 and 500),
  severity text not null default 'high'
    check (severity in ('critical', 'high', 'medium', 'low')),
  action text not null default 'flag' check (action in ('flag', 'warn')),
  active boolean not null default true,
  -- true when seeded by the platform baseline rather than added by a school.
  system_rule boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name)
);

create index safety_content_rules_school_active_idx
  on public.safety_content_rules (school_id, active);

-- One report row per submitted concern. reported_by is the reporter and is
-- masked from the moderation queue by the query layer until an escalation
-- that explicitly unmasks it (with its own audit event); the row itself
-- keeps the identity so the escalation is answerable from the record.
-- evidence_snapshot is the reporter's account of the message/conversation as
-- captured at submission, so a later edit/delete of the underlying message
-- cannot erase what a moderator was shown.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  reported_by uuid not null references public.profiles(id) on delete restrict,
  kind public.report_kind not null,
  status public.report_status not null default 'submitted',
  resolution public.report_resolution,
  -- Exactly one primary subject reference per kind.
  subject_user_id uuid references public.profiles(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  details text not null check (length(details) between 10 and 5000),
  evidence_snapshot jsonb not null default '{}'::jsonb,
  -- Advisory signal only. Stored so the review record shows what the
  -- classifier said, never so it can decide anything on its own.
  classifier_confidence numeric(4, 3) check (
    classifier_confidence is null or classifier_confidence between 0 and 1
  ),
  aup_version text check (aup_version is null or length(aup_version) between 1 and 40),
  -- Reporter consents to the school contacting them about this report.
  contact_consent boolean not null default false,
  priority text not null default 'medium'
    check (priority in ('critical', 'high', 'medium', 'low')),
  assigned_to uuid references public.profiles(id) on delete set null,
  resolution_note text check (resolution_note is null or length(resolution_note) <= 2000),
  resolved_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind <> 'message' or message_id is not null),
  check (kind <> 'conversation' or conversation_id is not null),
  check (kind <> 'user' or subject_user_id is not null),
  check (reported_by <> subject_user_id),
  check (resolution is null or status = 'resolved'),
  check (resolved_at is null or status = 'resolved')
);

-- Queue read order: live states first, then priority, then oldest first.
create index reports_queue_idx
  on public.reports (school_id, status, priority, created_at);

create index reports_reporter_idx
  on public.reports (reported_by, created_at desc);

create index reports_subject_idx
  on public.reports (school_id, subject_user_id)
  where subject_user_id is not null;

create index reports_assigned_idx
  on public.reports (school_id, assigned_to)
  where assigned_to is not null;

-- Append-only timeline. The audit trail for a report, independent of the
-- global audit_events row each command also writes, so a queue entry can be
-- reconstructed without granting moderator access to the whole audit log.
create table public.report_events (
  id bigint generated always as identity primary key,
  school_id uuid not null references public.schools(id) on delete cascade,
  report_id uuid not null references public.reports(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  event public.report_event_kind not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index report_events_report_idx
  on public.report_events (report_id, created_at);

create index report_events_school_idx
  on public.report_events (school_id, created_at desc);

-- Evidence attached to a report: the message a report is about, an uploaded
-- file object, or a moderator's own note. A moderator snapshot is text only;
-- no surface ever copies a safeguarding_restricted wellbeing record here
-- (the command refuses it and the surface test asserts it), so restrictive
-- wellbeing visibility is never widened through the moderation queue.
create table public.report_evidence (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  report_id uuid not null references public.reports(id) on delete cascade,
  added_by uuid not null references public.profiles(id) on delete restrict,
  kind text not null check (kind in ('message', 'attachment', 'note')),
  message_id uuid references public.messages(id) on delete set null,
  attachment_file_id uuid references public.file_objects(id) on delete set null,
  note text check (note is null or length(note) between 1 and 4000),
  content_hash text check (content_hash is null or content_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  check (kind <> 'message' or message_id is not null),
  check (kind <> 'attachment' or attachment_file_id is not null),
  check (kind <> 'note' or note is not null),
  check (kind = 'note' or note is null)
);

create index report_evidence_report_idx
  on public.report_evidence (report_id, created_at);

-- Dedupe and rate-limit ledger for report submission. One row per
-- (school, reporter, digest) records how many times the same normalized
-- concern was submitted inside a rolling window and when that window ends.
-- A duplicate inside the window and an exhausted per-reporter budget are
-- both refusals, so a user cannot flood the queue with one concern or many.
create table public.report_attempts (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  digest text not null check (digest ~ '^[0-9a-f]{64}$'),
  count_this_window integer not null default 1 check (count_this_window > 0),
  window_started_at timestamptz not null default now(),
  window_expires_at timestamptz not null,
  unique (school_id, reporter_id, digest),
  check (window_expires_at > window_started_at)
);

create index report_attempts_reporter_idx
  on public.report_attempts (school_id, reporter_id, window_expires_at);

-- Directional block rows. Blocking is stored per (blocker, blocked) pair but
-- enforced symmetrically by the message surface: a new conversation or
-- message between any two users is refused when either direction exists
-- inside the same school. Existing reads are never retroactively hidden.
-- Blocks are day-bounded by expiration and scoped to messaging only -
-- announcements are not a participant-to-participant channel and are
-- unaffected.
create table public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  scope text not null default 'messages' check (scope in ('messages', 'all')),
  reason text check (reason is null or length(reason) between 1 and 2000),
  expires_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (blocker_id <> blocked_id),
  check (expires_at is null or expires_at > created_at),
  unique (school_id, blocker_id, blocked_id)
);

-- Lookup for "is either direction blocked between these users in this
-- school" walks both the (blocker, blocked) and (blocked, blocker) sides.
create index user_blocks_pair_forward_idx
  on public.user_blocks (school_id, blocker_id, blocked_id, expires_at);

create index user_blocks_pair_reverse_idx
  on public.user_blocks (school_id, blocked_id, blocker_id, expires_at);

-- Legal holds: an operator-applied retention instruction that outlives a
-- user's own deletion request and is recorded independently of it. A hold
-- may target an account, a user's data, or a specific report. Releasing a
-- hold is a separate state transition; the row is never deleted.
create table public.legal_holds (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  subject_user_id uuid references public.profiles(id) on delete set null,
  report_id uuid references public.reports(id) on delete set null,
  account_deletion_request_id uuid references public.account_deletion_requests(id) on delete set null,
  applied_to text not null default 'account'
    check (applied_to in ('account', 'user_data', 'report')),
  reason text not null check (length(reason) between 8 and 2000),
  ticket_ref text not null check (length(ticket_ref) between 1 and 200),
  status text not null default 'active' check (status in ('active', 'released')),
  granted_by uuid not null references public.profiles(id) on delete restrict,
  released_by uuid references public.profiles(id) on delete set null,
  released_reason text check (released_reason is null or length(released_reason) between 8 and 2000),
  expires_at timestamptz,
  released_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'released' or (released_at is not null and released_by is not null)),
  check ((applied_to <> 'report') or report_id is not null)
);

create index legal_holds_school_status_idx
  on public.legal_holds (school_id, status);

create index legal_holds_subject_idx
  on public.legal_holds (subject_user_id)
  where status = 'active';

-- Time-bounded, MFA-gated, two-person-approved moderator sessions. Mirrors
-- support_access_grants exactly (202609160009) but is a separate table on
-- purpose: moderation and vendor support are different trust contexts with
-- different approvers, and sharing a table would let one grant satisfy both.
-- A moderator session is the only thing that widens queue visibility beyond
-- a school administrator's own tenant, and it is always short and audited.
create table public.moderation_access_grants (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  approved_by uuid references public.profiles(id) on delete set null,
  reason text not null check (length(reason) between 8 and 2000),
  ticket_ref text not null check (length(ticket_ref) between 1 and 200),
  resource_scope jsonb not null default '{}'::jsonb,
  status public.moderation_access_status not null default 'pending',
  requires_second_approver boolean not null default true,
  mfa_verified_at timestamptz not null,
  expires_at timestamptz not null,
  started_at timestamptz,
  ended_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  revoked_reason text,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > created_at),
  check (approved_by is null or approved_by <> requested_by),
  check (status not in ('active', 'approved') or approved_by is not null)
);

create index moderation_access_grants_school_status_idx
  on public.moderation_access_grants (school_id, status);

-- Mutable lifecycle tables get the standard updated_at trigger.
do $safe043$
declare
  table_name text;
begin
  foreach table_name in array array[
    'school_content_controls', 'safety_content_rules', 'reports',
    'user_blocks', 'legal_holds', 'moderation_access_grants'
  ]
  loop
    execute format(
      'create trigger safe043_set_updated_at before update on public.%I '
      'for each row execute function private.set_updated_at()',
      table_name
    );
  end loop;
end
$safe043$;

-- Append-only relations: no update, no delete, ever.
do $safe043$
declare
  table_name text;
begin
  foreach table_name in array array['report_events', 'report_evidence']
  loop
    execute format(
      'create trigger safe043_reject_mutation before update or delete on public.%I '
      'for each row execute function private.reject_append_only_mutation()',
      table_name
    );
  end loop;
end
$safe043$;

-- Relationship columns are pinned; status/version/notes are the dispatcher's
-- to move, under expectedVersion checks.
create trigger safe043_immutable_report
before update on public.reports
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'reported_by', 'kind', 'message_id', 'conversation_id',
  'subject_user_id', 'created_at'
);
create trigger safe043_immutable_user_block
before update on public.user_blocks
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'blocker_id', 'blocked_id', 'created_at'
);
create trigger safe043_immutable_legal_hold
before update on public.legal_holds
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'subject_user_id', 'report_id',
  'account_deletion_request_id', 'granted_by', 'created_at'
);
create trigger safe043_immutable_moderation_grant
before update on public.moderation_access_grants
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'requested_by', 'created_at'
);
create trigger safe043_immutable_content_controls
before update on public.school_content_controls
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'created_at'
);

-- RLS on and every direct grant revoked, for every runtime role. The private
-- dispatcher functions are the only access path.
do $safe043$
declare
  table_name text;
begin
  foreach table_name in array array[
    'school_content_controls', 'safety_content_rules', 'reports',
    'report_events', 'report_evidence', 'report_attempts', 'user_blocks',
    'legal_holds', 'moderation_access_grants'
  ]
  loop
    execute format(
      'alter table public.%I enable row level security', table_name
    );
    execute format(
      'revoke all on table public.%I from anon, authenticated, service_role, '
      'studafy_api_runtime, studafy_worker_runtime',
      table_name
    );
  end loop;
end
$safe043$;

-- The two append-only tables' identity sequences are read by SECURITY
-- DEFINER helpers only; no runtime role ever uses them directly. The
-- service_role audit sequence grant (db021_grants.sql) is deliberately left
-- untouched.
revoke all on sequence public.report_events_id_seq, public.report_evidence_id_seq
from anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;
