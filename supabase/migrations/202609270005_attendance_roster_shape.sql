-- The attendance register failed to load, every time, for every class.
--
-- listAttendanceRoster builds each row with to_jsonb over a subquery whose
-- first column is the student id, kept there for keyset paging. to_jsonb
-- carries that column into the row, so every item came back as
-- {id, student, record} against a V1AttendanceRosterItem that allows only
-- {student, record}. The API validates every response before sending it and
-- answers 500 when one does not match - so the register never opened.
--
-- The paging position is taken from the same subquery and does not depend on
-- the field, so it is removed from each item on the way out.

do $$ begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'api041_query_pre_roster_shape'
  ) then
    alter function private.api041_query(text, uuid, jsonb)
      rename to api041_query_pre_roster_shape;
  end if;
end $$;

create or replace function private.api041_query(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
begin
  result := private.api041_query_pre_roster_shape(p_operation, p_resource_id, p_input);
  if p_operation <> 'listAttendanceRoster' or result is null
    or jsonb_typeof(result->'items') <> 'array' then
    return result;
  end if;
  return jsonb_set(result, array['items'], (
    select coalesce(jsonb_agg(item - 'id' order by ordinality), '[]'::jsonb)
    from jsonb_array_elements(result->'items') with ordinality as t(item, ordinality)
  ));
end;
$$;

alter function private.api041_query(text, uuid, jsonb) owner to postgres;
alter function private.api041_query_pre_roster_shape(text, uuid, jsonb)
  owner to postgres;
revoke all on function private.api041_query_pre_roster_shape(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime,
  studafy_api_runtime;
revoke all on function private.api041_query(text, uuid, jsonb)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.api041_query(text, uuid, jsonb)
  to studafy_api_runtime;
