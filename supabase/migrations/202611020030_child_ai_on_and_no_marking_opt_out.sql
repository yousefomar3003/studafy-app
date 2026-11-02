-- Two owner decisions (2026-11-02, DL-074), with the texts of 202611020020.
--
-- 1. The AI study tools are on from the start for a child account a parent
--    creates. Until now a managed child had no AI until the parent agreed on
--    the child's card (ADR-0043); now creating the child records the
--    parent's agreement to the current AI notice, given as 'guardian', and
--    the parent turns it off on the same card (withdraw), as before.
--    TODO(legal): consent that is on unless the parent turns it off is not
--    the clear affirmative act GDPR Art. 4(11)/7 and the Planet49 ruling
--    expect for consent; counsel to confirm the basis (DPIA, counsel
--    questions 11). Recorded as the owner's accepted risk in DL-074.
--
--    Children that already exist get the same, unless their parent turned
--    the tools off (their latest AI record is withdrawn). A new AI notice
--    version later asks the parent again, as for everyone.
--
-- 2. AI-suggested marks have no student opt-out any more (DL-073 is amended):
--    nobody opts out, the teacher decides whether to ask and decides every
--    mark. Existing opt-outs are removed, and a new one is refused, so an
--    older app's switch fails instead of seeming to work.

-- ---------------------------------------------------------------------------
-- 1. AI on for a new managed child.
-- ---------------------------------------------------------------------------
create or replace function private.managed_child_ai_on()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_version text := private.ai_consent_version();
  v_locale text;
  v_policy uuid;
begin
  if v_version is null then return new; end if;
  select case when p.locale in ('en', 'ar') then p.locale else 'en' end
    into v_locale
  from public.profiles p where p.id = new.guardian_id;
  v_locale := coalesce(v_locale, 'en');
  select pol.id into v_policy from public.consent_policies pol
  where pol.purpose = 'ai_features' and pol.policy_version = v_version
    and pol.locale = v_locale;
  if v_policy is null then return new; end if;
  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
    policy_id, given_by, given_as, withdrawn_by)
  values (new.child_id, 'ai_features', v_version, v_locale, now(), null,
    v_policy, new.guardian_id, 'guardian', null)
  on conflict (user_id, purpose, policy_version) do nothing;
  return new;
end;
$$;

drop trigger if exists dl074_managed_child_ai_on on private.managed_accounts;
create trigger dl074_managed_child_ai_on
after insert on private.managed_accounts
for each row execute function private.managed_child_ai_on();

-- Existing children, unless their parent turned the tools off.
insert into public.consent_records (
  user_id, purpose, policy_version, locale, accepted_at, withdrawn_at,
  policy_id, given_by, given_as, withdrawn_by)
select m.child_id, 'ai_features', pol.policy_version, pol.locale, now(), null,
  pol.id, m.guardian_id, 'guardian', null
from private.managed_accounts m
join public.profiles child on child.id = m.child_id and child.deleted_at is null
left join public.profiles g on g.id = m.guardian_id
join public.consent_policies pol
  on pol.purpose = 'ai_features'
 and pol.policy_version = private.ai_consent_version()
 and pol.locale = case when g.locale in ('en', 'ar') then g.locale else 'en' end
where not exists (
  select 1 from public.consent_records c
  where c.user_id = m.child_id and c.purpose = 'ai_features'
    and c.withdrawn_at is not null
    and c.accepted_at = (select max(c2.accepted_at) from public.consent_records c2
      where c2.user_id = m.child_id and c2.purpose = 'ai_features'))
on conflict (user_id, purpose, policy_version) do nothing;

-- ---------------------------------------------------------------------------
-- 2. No opt-out from AI-suggested marks.
-- ---------------------------------------------------------------------------
delete from private.marking_opt_outs;

create or replace function private.marking_opt_out_refused()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'AI-suggested marks have no opt-out (DL-074)'
    using errcode = '23514';
end;
$$;

drop trigger if exists dl074_no_marking_opt_out on private.marking_opt_outs;
create trigger dl074_no_marking_opt_out
before insert on private.marking_opt_outs
for each row execute function private.marking_opt_out_refused();

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.managed_child_ai_on()',
    'private.marking_opt_out_refused()'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;
