-- AUTH-030 account deletion lifecycle.
--
-- Two corrections to the DB-020 shape, both forward-only:
--
-- 1. `unique (user_id, state)` makes a second request impossible once a first
--    has been cancelled, because the cancelled row permanently occupies
--    (user_id, 'cancelled'). Apple 5.1.1(v) and Play both require a working
--    in-app deletion path, and a user who cancels must be able to ask again.
--    The constraint is replaced by a partial unique index that constrains only
--    what actually needs constraining: one live request per user.
--
-- 2. The request carried no impact summary, no cancellation record, and no
--    education-record classification, so nothing recorded what a user was told
--    would be deleted or why some records survive.

alter table public.account_deletion_requests
  drop constraint account_deletion_requests_user_id_state_key;

create unique index account_deletion_requests_live_idx
  on public.account_deletion_requests (user_id)
  where state in ('grace_period', 'executing');

alter table public.account_deletion_requests
  add column reason_code text
    check (
      reason_code is null or reason_code in (
        'no_longer_using', 'changing_schools', 'privacy_concern',
        'duplicate_account', 'undisclosed'
      )
    ),
  add column requested_via text not null default 'in_app'
    check (requested_via in ('in_app', 'support', 'school_admin')),
  -- What the user was shown at the moment they confirmed. Stored so a later
  -- dispute is answered from the record rather than from current code.
  add column impact_snapshot jsonb,
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references public.profiles(id) on delete set null,
  add column legal_hold boolean not null default false,
  add column legal_hold_reason text,
  add column education_record_classification text not null default 'pending_review'
    check (
      education_record_classification in (
        'pending_review', 'school_owned_retained', 'personal_deletable', 'mixed'
      )
    ),
  add constraint account_deletion_cancelled_state
    check ((cancelled_at is null) = (state <> 'cancelled')),
  add constraint account_deletion_legal_hold_reason
    check (not legal_hold or legal_hold_reason is not null),
  -- A record under legal hold may not silently complete.
  add constraint account_deletion_hold_blocks_completion
    check (not legal_hold or state <> 'completed');

-- The DB-021 immutability trigger already pins id and user_id. Requested and
-- execute times are equally not the caller's to rewrite after the fact.
drop trigger db021_immutable_account_deletion_request
  on public.account_deletion_requests;

create trigger db021_immutable_account_deletion_request
before update on public.account_deletion_requests
for each row execute function private.reject_immutable_columns(
  'id', 'user_id', 'requested_at', 'requested_via'
);
