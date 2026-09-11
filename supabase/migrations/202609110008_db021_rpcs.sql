-- DB-021 bounded client commands and exposed-function reduction.

create or replace function public.record_policy_consent(
  requested_purpose text,
  requested_version text,
  requested_locale text default 'en'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;
  if not private.is_active_user() then
    raise exception using
      errcode = '42501',
      message = 'Active account required';
  end if;
  if requested_purpose is null
     or requested_purpose not in ('terms_and_privacy', 'ai_features') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported consent purpose';
  end if;
  if requested_locale is null or requested_locale not in ('en', 'ar') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported locale';
  end if;
  if requested_version is null
     or requested_version <> btrim(requested_version)
     or char_length(requested_version) not between 1 and 128 then
    raise exception using
      errcode = '22023',
      message = 'Invalid policy version';
  end if;

  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at
  ) values (
    caller,
    requested_purpose,
    requested_version,
    requested_locale,
    now(),
    null
  )
  on conflict (user_id, purpose, policy_version)
  do update set
    locale = excluded.locale,
    accepted_at = excluded.accepted_at,
    withdrawn_at = null;
end;
$$;

alter function public.record_policy_consent(text, text, text)
  owner to postgres;
revoke all on function public.record_policy_consent(text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.record_policy_consent(text, text, text)
  to authenticated;

create or replace function public.mark_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  affected integer;
begin
  if caller is null or not private.is_active_user() then
    raise exception using
      errcode = '42501',
      message = 'Active authenticated account required';
  end if;

  update public.notifications
  set read_at = now()
  where user_id = caller and read_at is null;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

alter function public.mark_notifications_read() owner to postgres;
revoke all on function public.mark_notifications_read()
  from public, anon, authenticated, service_role;
grant execute on function public.mark_notifications_read()
  to authenticated;

-- Trigger helpers are not application RPCs. Moving them keeps PostgREST's
-- public function inventory limited to intentional commands. Trigger OIDs
-- remain valid when their functions move schemas.
alter function public.handle_new_auth_user() set schema private;
alter function public.set_updated_at() set schema private;
alter function public.sync_membership_lifecycle() set schema private;
alter function public.sync_term_lifecycle() set schema private;
alter function public.sync_enrollment_lifecycle() set schema private;
alter function public.sync_classroom_lifecycle() set schema private;
alter function public.sync_submission_lifecycle() set schema private;
alter function public.sync_grade_publication_actor() set schema private;
alter function public.derive_school_id() set schema private;
alter function public.validate_grade_result_score() set schema private;
alter function public.validate_assessment_maximum() set schema private;
alter function public.reject_append_only_mutation() set schema private;

alter function private.handle_new_auth_user() set search_path = '';
alter function private.set_updated_at() set search_path = '';

revoke all on function private.handle_new_auth_user(),
  private.set_updated_at(),
  private.sync_membership_lifecycle(),
  private.sync_term_lifecycle(),
  private.sync_enrollment_lifecycle(),
  private.sync_classroom_lifecycle(),
  private.sync_submission_lifecycle(),
  private.sync_grade_publication_actor(),
  private.derive_school_id(),
  private.validate_grade_result_score(),
  private.validate_assessment_maximum(),
  private.reject_append_only_mutation()
from public, anon, authenticated, service_role;
