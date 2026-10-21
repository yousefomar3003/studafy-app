-- Students in no class can buy Studafy Plus and Max (2026-10-21).
--
-- Found after ADR-0045: a student who skipped joining a class has no
-- student record and no school, and the self-purchase tail of
-- billing_resolve_beneficiary required both, so the store purchase was
-- verified and then refused (not_eligible, or student_purchase_disabled).
-- The account's kind (private.account_kind = 'student') is now enough, and
-- a school's opt-out still applies to students of that school - any school
-- they belong to that has turned self-purchase off.
--
-- Re-issued whole from 202610210010 with only the self-purchase tail
-- changed; every other branch (teacher, Family+, a parent naming a child)
-- is as it was.

create or replace function private.billing_resolve_beneficiary(p_purchaser uuid, p_feature_key text, p_beneficiary_student_id uuid, p_parental_gate_confirmed boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  student_row public.students%rowtype;
  guardian_link uuid;
  purchaser_school uuid;
begin
  if p_feature_key = 'teacher_ai_grading' then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.memberships m
      where m.user_id = p_purchaser and m.role = 'teacher'
        and m.active and m.status = 'active'
        and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  -- Family+ is the parent's own plan, covering their linked children up to
  -- the plan's size. It is held by the guardian who pays, so no child is
  -- named at purchase; only somebody who is already a verified guardian of
  -- at least one child may buy it.
  if p_feature_key in ('family_plus', 'family_plus_large') then
    if p_beneficiary_student_id is not null then
      return jsonb_build_object('ok', false, 'outcome', 'invalid_beneficiary');
    end if;
    if not exists (
      select 1 from public.guardian_links gl
      join public.students s on s.id = gl.student_id and s.deleted_at is null
      where gl.guardian_id = p_purchaser and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
    ) then
      return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
    );
  end if;

  if p_feature_key = 'parent_insights' and p_beneficiary_student_id is null then
    return jsonb_build_object('ok', false, 'outcome', 'beneficiary_required');
  end if;

  if p_beneficiary_student_id is not null then
    select * into student_row from public.students
    where id = p_beneficiary_student_id and deleted_at is null;
    if student_row.id is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    select gl.id into guardian_link
      from public.guardian_links gl
      where gl.student_id = student_row.id
        and gl.guardian_id = p_purchaser
        and gl.status = 'verified'
        and (gl.expires_at is null or gl.expires_at > now())
      limit 1;
    if guardian_link is null then
      return jsonb_build_object('ok', false, 'outcome', 'beneficiary_link_invalid');
    end if;
    return jsonb_build_object(
      'ok', true, 'beneficiaryId', student_row.user_id, 'guardianLinkId', guardian_link
    );
  end if;

  -- Self-purchase: a student buying their own plan. The store account on
  -- the phone pays; for a child, the store's own family controls (Family
  -- Link, Ask to Buy) are where a parent approves (DL-071).
  --
  -- A student account in no class (ADR-0045) has no student record and no
  -- school, so neither may be required: the account's kind says it is a
  -- student's. A school's opt-out still applies to its own students.
  select st.* into student_row from public.students st
  where st.user_id = p_purchaser and st.deleted_at is null
  limit 1;
  if student_row.id is null
     and private.account_kind(p_purchaser) is distinct from 'student' then
    return jsonb_build_object('ok', false, 'outcome', 'not_eligible');
  end if;
  if p_feature_key not in ('studafy_plus', 'studafy_max')
     and not p_parental_gate_confirmed then
    return jsonb_build_object('ok', false, 'outcome', 'parental_gate_required');
  end if;
  if exists (
    select 1 from public.memberships m
    join public.school_billing_settings s on s.school_id = m.school_id
    where m.user_id = p_purchaser and m.role = 'student'
      and m.active and m.status = 'active'
      and m.valid_from <= now() and (m.valid_until is null or m.valid_until > now())
      and not s.self_purchase_enabled
  ) then
    return jsonb_build_object('ok', false, 'outcome', 'student_purchase_disabled');
  end if;
  return jsonb_build_object(
    'ok', true, 'beneficiaryId', p_purchaser, 'guardianLinkId', null
  );
end;
$function$;

alter function private.billing_resolve_beneficiary(uuid, text, uuid, boolean)
  owner to postgres;
revoke all on function private.billing_resolve_beneficiary(uuid, text, uuid, boolean)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
