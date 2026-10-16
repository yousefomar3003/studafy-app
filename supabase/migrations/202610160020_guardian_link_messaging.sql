-- A guardian's own links say whether messaging is on at the child's school.
--
-- The app must not offer messaging where the school has it switched off
-- (DL-049: private.school_messaging_enabled, enforced on every
-- createConversation and sendMessage). Members read the switch from
-- GET /v1/control-panel/content-controls/{schoolId}; a guardian holds no
-- membership, so that read is not theirs. Their own links already name each
-- child's school, so the switch travels with the link: one boolean, the same
-- one the server enforces, and nothing else from the school's safety
-- configuration.
--
-- Copied from 202609280002_flatten_school_operations_queries.sql with the
-- messagingEnabled field added.

CREATE OR REPLACE FUNCTION private.ops_query_my_guardian_links(p_operation text, p_resource_id uuid, p_input jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_actor uuid := auth.uid();
  result jsonb;
begin

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
      'expiresAt', gl.expires_at,
      'messagingEnabled', private.school_messaging_enabled(st.school_id)
    ) order by gl.updated_at desc, gl.id), '[]'::jsonb)
  into result
  from public.guardian_links gl
  join public.students st on st.id = gl.student_id and st.deleted_at is null
  join public.schools s on s.id = st.school_id
  where gl.guardian_id = v_actor;
  return jsonb_build_object('items', result);
end;
$function$;

revoke all on function private.ops_query_my_guardian_links(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;
