-- Safety reports with one reviewer (DL-063).
--
-- A platform operator reads a safety report only under an active moderation
-- grant (SAFE-043; 202610150080), and a grant had to be approved by a
-- second, different platform operator (private.safe043_is_second_approver).
-- Messaging launches with one reviewer, the owner (DL-063), so no grant
-- could ever be approved and no report read. This adds single-reviewer mode:
--
-- * A setting, private.safety_review_settings.single_reviewer. It is on
--   from this migration, as DL-063 decided. Changing it is an out-of-band,
--   service-role SQL operation, like adding a platform operator, and every
--   change writes an audit event (safety_single_reviewer_changed).
-- * The mode applies only while the setting is on AND exactly one platform
--   operator exists. Adding a second operator ends it by itself: the
--   two-person approval is back, whatever the setting says.
-- * In the mode, the requester may approve their own grant, but only one
--   requested with requiresSecondApprover false, so the grant itself
--   records that it was not meant to have a second approver. A grant
--   requested with the default (true) still needs someone else, and the
--   table's check constraint still refuses its requester as approver.
--
-- Nothing else changes. Requesting and approving still need a fresh MFA
-- step (aal2) through the API; only the requester starts the grant; grants
-- expire and can be revoked; every request, approval, start, revocation,
-- report read (report_review_opened/_refused) and resolution is audited as
-- before; the Telegram alert for each report is untouched. No school
-- administrator path is added: approving needs a platform operator.

create table private.safety_review_settings (
  singleton boolean primary key default true check (singleton),
  single_reviewer boolean not null default false,
  note text,
  updated_at timestamptz not null default now()
);

comment on table private.safety_review_settings is
  'One row. single_reviewer: while on and exactly one platform operator '
  'exists, that operator may approve their own moderation grant when it was '
  'requested with requiresSecondApprover false (DL-063; '
  'docs/security/safe043-operator-runbook.md).';

alter table private.safety_review_settings enable row level security;
revoke all on table private.safety_review_settings
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Every change to the setting is audited, whoever makes it.
create function private.safety_review_settings_audit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.updated_at := now();
  if tg_op = 'UPDATE'
     and new.single_reviewer is not distinct from old.single_reviewer then
    return new;
  end if;
  insert into public.audit_events (
    school_id, actor_id, action, entity_type, entity_id,
    before_value, after_value
  ) values (
    null, auth.uid(), 'safety_single_reviewer_changed',
    'safety_review_settings', null,
    case when tg_op = 'UPDATE'
      then jsonb_build_object('singleReviewer', old.single_reviewer) end,
    jsonb_build_object('singleReviewer', new.single_reviewer, 'note', new.note)
  );
  return new;
end;
$$;

create trigger safety_review_settings_audit
before insert or update on private.safety_review_settings
for each row execute function private.safety_review_settings_audit();

insert into private.safety_review_settings (singleton, single_reviewer, note)
values (true, true,
  'DL-063: messaging launches with one report reviewer, the owner.');

-- True while single-reviewer mode applies: the setting is on and there is
-- exactly one platform operator.
create function private.safety_single_reviewer_mode()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
      (select s.single_reviewer from private.safety_review_settings s
       where s.singleton),
      false)
    and (select count(*) from public.platform_operators) = 1;
$$;

-- Who may approve a moderation grant (approveModerationAccess and its
-- authorization, moderation.access.approve). A platform operator who is not
-- the requester, as before; or, in single-reviewer mode, the requester of a
-- grant requested with requiresSecondApprover false.
create or replace function private.safe043_is_second_approver(p_grant uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_operator() and exists (
    select 1 from public.moderation_access_grants g
    where g.id = p_grant
      and (
        g.requested_by <> auth.uid()
        or (not g.requires_second_approver
            and private.safety_single_reviewer_mode())
      )
  );
$$;

-- The table's own backstop said a grant's approver is never its requester.
-- It now says so for every grant that requires a second approver, which is
-- every grant except one requested with requiresSecondApprover false.
do $constraint$
declare
  v_name text;
begin
  select c.conname into strict v_name
  from pg_constraint c
  where c.conrelid = 'public.moderation_access_grants'::regclass
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid)
      = 'CHECK (((approved_by IS NULL) OR (approved_by <> requested_by)))';
  execute format(
    'alter table public.moderation_access_grants drop constraint %I', v_name);
end
$constraint$;

alter table public.moderation_access_grants
  add constraint moderation_access_grants_second_approver check (
    approved_by is null or approved_by <> requested_by
    or not requires_second_approver
  );

alter function private.safety_review_settings_audit() owner to postgres;
alter function private.safety_single_reviewer_mode() owner to postgres;
alter function private.safe043_is_second_approver(uuid) owner to postgres;
revoke all on function
  private.safety_review_settings_audit(),
  private.safety_single_reviewer_mode(),
  private.safe043_is_second_approver(uuid)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
