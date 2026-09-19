-- MOB-070 parent slice (DL-050). A guardian had commands to request,
-- verify and revoke links but no way to list their own children, so no
-- parent screen could start in a real build. listMyGuardianLinks returns the
-- caller's own links (pending, verified, declined or revoked) with the
-- child's display name and school, most recently changed first. It never lists anyone
-- else's links and never reveals a child the caller has no link row for.

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_guardian_reads;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  result jsonb;
begin
  if p_operation <> 'listMyGuardianLinks' then
    return private.api042_query_pre_guardian_reads(p_operation, p_resource_id, p_input);
  end if;
  if v_actor is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', gl.id,
      'schoolId', st.school_id,
      'schoolName', s.name,
      'studentId', st.id,
      'studentName', st.display_name,
      'relationship', gl.relationship,
      'status', gl.status,
      'expiresAt', gl.expires_at
    ) order by gl.updated_at desc, gl.id), '[]'::jsonb)
  into result
  from public.guardian_links gl
  join public.students st on st.id = gl.student_id and st.deleted_at is null
  join public.schools s on s.id = st.school_id
  where gl.guardian_id = v_actor;
  return jsonb_build_object('items', result);
end;
$$;

alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_query_pre_guardian_reads(text, uuid, jsonb) owner to postgres;
revoke all on function private.api042_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_guardian_reads(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
grant execute on function private.api042_query(text, uuid, jsonb) to studafy_api_runtime;
