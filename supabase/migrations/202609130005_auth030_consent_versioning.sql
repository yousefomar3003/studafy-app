-- AUTH-030 consent policy versioning.
--
-- The DB-021 RPC accepts any well-formed string as a policy version, so the
-- client constant in supabase_session_repository.dart is the only thing
-- deciding what a user is recorded as having accepted. DB-020 added
-- `consent_policies` and a `consent_records.policy_id` column for exactly
-- this, but nothing populated or enforced them.
--
-- This migration extends the DB-021 function; it does not revert it. Every
-- DB-021 control — SECURITY DEFINER with an empty search path, the active-user
-- check, the stable error codes, and the caller derived from auth.uid() — is
-- retained, and one further check is added.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  (
    'terms_and_privacy', '2026-09-09', 'en',
    'Studafy Terms of Use and Privacy Policy',
    encode(extensions.digest('terms_and_privacy:2026-09-09:en', 'sha256'), 'hex'),
    timestamptz '2026-09-09 00:00:00+00', timestamptz '2026-09-09 00:00:00+00'
  ),
  (
    'terms_and_privacy', '2026-09-09', 'ar',
    'شروط استخدام ستدافاي وسياسة الخصوصية',
    encode(extensions.digest('terms_and_privacy:2026-09-09:ar', 'sha256'), 'hex'),
    timestamptz '2026-09-09 00:00:00+00', timestamptz '2026-09-09 00:00:00+00'
  )
on conflict (purpose, policy_version, locale) do nothing;

-- `content_hash` above is derived from the identifier triple, not from a
-- published document: no document is hosted yet (REL-002/B5, blocked on D5).
-- Replacing it with the digest of the real text is a forward migration, and
-- bumping the client version without inserting the matching row fails closed.

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
  matched_policy uuid;
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

  -- AUTH-030: consent is only recordable against a published, effective,
  -- unretired policy row, so a client cannot invent a version string and have
  -- it accepted as though a document existed behind it.
  select p.id into matched_policy
  from public.consent_policies p
  where p.purpose = requested_purpose
    and p.policy_version = requested_version
    and p.locale = requested_locale
    and p.published_at <= now()
    and p.effective_at <= now()
    and (p.retired_at is null or p.retired_at > now());

  if matched_policy is null then
    raise exception using
      errcode = '22023',
      message = 'Unsupported consent policy version';
  end if;

  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
    policy_id
  ) values (
    caller,
    requested_purpose,
    requested_version,
    requested_locale,
    now(),
    null,
    matched_policy
  )
  on conflict (user_id, purpose, policy_version)
  do update set
    locale = excluded.locale,
    accepted_at = excluded.accepted_at,
    withdrawn_at = null,
    policy_id = excluded.policy_id;
end;
$$;

-- Replacing a function resets its ACL, so the DB-021 surface is re-asserted.
alter function public.record_policy_consent(text, text, text)
  owner to postgres;
revoke all on function public.record_policy_consent(text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.record_policy_consent(text, text, text)
  to authenticated;
