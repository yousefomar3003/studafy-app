-- MVP family consent: only the student account named by the record can decide.
alter function private.api042_query(text, uuid, jsonb) rename to api042_query_pre_student_family;
create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); ids jsonb; links jsonb;
begin
  if p_operation <> 'getStudentFamily' then
    return private.api042_query_pre_student_family(p_operation, p_resource_id, p_input);
  end if;
  if actor is null or not private.is_active_user() then return jsonb_build_object('outcome','forbidden'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'studafyId',s.studafy_id,'displayName',s.display_name) order by s.id),'[]') into ids
  from public.students s where s.user_id=actor and s.deleted_at is null;
  select coalesce(jsonb_agg(jsonb_build_object('id',g.id,'guardianId',g.guardian_id,'guardianName',p.display_name,'studentId',g.student_id,'relationship',g.relationship,'status',g.status) order by g.updated_at desc,g.id),'[]') into links
  from public.guardian_links g join public.students s on s.id=g.student_id
  join public.profiles p on p.id=g.guardian_id and p.status='active'
  where s.user_id=actor and s.deleted_at is null;
  return jsonb_build_object('studentIds',ids,'requests',links);
end;
$$;

alter function private.api042_command(text, uuid, jsonb, uuid, bigint) rename to api042_command_pre_student_family;
create or replace function private.api042_command(p_operation text,p_resource_id uuid,p_input jsonb,p_idempotency_id uuid,p_idempotency_generation bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); link public.guardian_links%rowtype;
  decision text := p_input->'body'->>'decision'; response jsonb; before_value jsonb;
  request_id text := nullif(current_setting('studafy.request_id',true),'');
  tenant uuid := nullif(current_setting('studafy.school_id',true),'')::uuid;
begin
  if p_operation <> 'decideGuardianLink' then
    return private.api042_command_pre_student_family(p_operation,p_resource_id,p_input,p_idempotency_id,p_idempotency_generation);
  end if;
  if actor is null or not private.is_active_user() or request_id is null then return jsonb_build_object('outcome','forbidden'); end if;
  perform 1 from public.idempotency_records r where r.id=p_idempotency_id and r.actor_id=actor
    and r.school_id is not distinct from tenant and r.generation=p_idempotency_generation and r.status='reserved' for update;
  if not found then return jsonb_build_object('outcome','forbidden'); end if;
  select g.* into link from public.guardian_links g join public.students s on s.id=g.student_id
    where g.id=p_resource_id and s.user_id=actor and s.deleted_at is null and g.guardian_id<>actor for update of g;
  if not found then return jsonb_build_object('outcome','not_found'); end if;
  if decision not in ('approve','decline','revoke') or decision is null then return jsonb_build_object('outcome','invalid'); end if;
  if (decision in ('approve','decline') and link.status<>'pending') or (decision='revoke' and link.status<>'verified') then return jsonb_build_object('outcome','invalid_state'); end if;
  if decision='approve' and not exists(select 1 from public.profiles where id=link.guardian_id and status='active') then return jsonb_build_object('outcome','invalid_state'); end if;
  before_value:=to_jsonb(link);
  if decision='approve' then
    update public.guardian_links set status='verified',verified_by=actor,verified_at=now(),expires_at=now()+interval '365 days',updated_at=now() where id=link.id;
  elsif decision='decline' then
    update public.guardian_links set status='declined',verified_by=null,verified_at=null,expires_at=null,updated_at=now() where id=link.id;
  else
    update public.guardian_links set status='revoked',expires_at=now(),updated_at=now() where id=link.id;
  end if;
  response:=private.api042_guardian_link_json(link.id);
  insert into public.audit_events(school_id,actor_id,action,entity_type,entity_id,before_value,after_value,request_id)
    values(link.school_id,actor,'guardian_link_student_'||decision,'guardian_link',link.id,before_value,response,request_id);
  if not private.api_idempotency_complete(p_idempotency_id,p_idempotency_generation,200,response) then raise exception 'FAMILY_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome','ok','response',response);
end;
$$;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
revoke all on function private.api042_query_pre_student_family(text,uuid,jsonb), private.api042_command_pre_student_family(text,uuid,jsonb,uuid,bigint) from public,anon,authenticated,service_role,studafy_worker_runtime,studafy_api_runtime;
revoke all on function private.api042_query(text,uuid,jsonb), private.api042_command(text,uuid,jsonb,uuid,bigint) from public,anon,authenticated,service_role,studafy_worker_runtime;
grant execute on function private.api042_query(text,uuid,jsonb), private.api042_command(text,uuid,jsonb,uuid,bigint) to studafy_api_runtime;
