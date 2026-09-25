-- Student Notebook is a store subscription: intended US reference price
-- $2.49/month, P1M introductory free trial for eligible new subscribers.
-- Stores own prices, eligibility and billing dates. No local trial timer or
-- client flag ever creates an entitlement.

-- One trusted environment per database. Configure development/staging on
-- their own databases; never accept this value from a request or a receipt.
create table private.notebook_runtime (
  singleton boolean primary key default true check (singleton),
  environment text not null check (environment in ('synthetic','development','staging','production'))
);
insert into private.notebook_runtime values (true, 'production');
revoke all on private.notebook_runtime from public, anon, authenticated, service_role,
  studafy_api_runtime, studafy_worker_runtime;

create function private.notebook_has_access()
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_active_user() and exists (
    select 1 from public.entitlements e
    join public.store_transactions st on st.id = e.source_transaction_id
    join private.notebook_runtime runtime on runtime.singleton
    where e.user_id = auth.uid() and e.feature_key = 'student_notebook'
      and e.status in ('active','grace_period')
      and e.starts_at <= now() and e.ends_at > now()
      and st.environment = runtime.environment
      and st.beneficiary_id = auth.uid()
  );
$$;

-- Staff/guardian access retains its existing authorization. A student needs
-- their own verified entitlement; another student's purchase never counts.
create function private.notebook_reader_allowed(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    not private.has_active_membership(p_school, array['student']::public.app_role[])
    or private.has_active_membership(p_school, array['teacher','school_admin','parent','guardian']::public.app_role[])
    or private.notebook_has_access()
  );
$$;

-- API list queries run as SECURITY DEFINER, so RLS alone is insufficient.
-- Keep the existing scoped query (including enrollment/publication checks).
alter function private.api041_query(text,uuid,jsonb) rename to api041_query_before_notebook;
create function private.api041_query(p_operation text,p_resource_id uuid,p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if p_operation = 'listResources' and not private.notebook_reader_allowed(
      nullif(current_setting('studafy.school_id',true),'')::uuid) then
    return jsonb_build_object('outcome','forbidden');
  end if;
  return private.api041_query_before_notebook(p_operation,p_resource_id,p_input);
end;
$$;
revoke all on function private.api041_query_before_notebook(text,uuid,jsonb)
  from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;
revoke all on function private.api041_query(text,uuid,jsonb)
  from public,anon,authenticated,service_role,studafy_worker_runtime;
grant execute on function private.api041_query(text,uuid,jsonb) to studafy_api_runtime;

-- Close direct REST/resource-version/publication and attachment-delivery
-- paths too. Existing RLS policies retain these function identities.

create or replace function private.can_view_resource_publication(
  target_publication uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.notebook_reader_allowed((select school_id from public.resource_publications where id = target_publication)) and exists (
    select 1
    from public.resource_publications rp
    join public.resource_versions rv
      on rv.id = rp.resource_version_id and rv.school_id = rp.school_id
    join public.resources r
      on r.id = rv.resource_id and r.school_id = rv.school_id
    left join public.file_objects f
      on f.id = rv.file_object_id and f.school_id = rv.school_id
    where rp.id = target_publication
      and (
        private.is_school_admin(rp.school_id)
        or private.has_active_membership(
          rp.school_id,
          array['teacher']::public.app_role[]
        )
        or (
          rp.state = 'published'
          and rp.published_at is not null
          and rp.withdrawn_at is null
          and r.state = 'published'
          and r.deleted_at is null
          and (rv.file_object_id is null or (
            f.scan_state = 'clean' and f.deleted_at is null
          ))
          and (
            (
              rp.audience in ('students', 'both')
              and (
                (rp.classroom_id is null and private.has_active_membership(
                  rp.school_id,
                  array['student']::public.app_role[]
                ))
                or exists (
                  select 1 from public.enrollments e
                  where e.classroom_id = rp.classroom_id
                    and private.is_enrolled_student(e.classroom_id, e.student_id)
                )
              )
            )
            or (
              rp.audience in ('guardians', 'both')
              and (
                (rp.classroom_id is null and private.has_active_membership(
                  rp.school_id,
                  array['parent', 'guardian']::public.app_role[]
                ))
                or exists (
                  select 1 from public.enrollments e
                  where e.classroom_id = rp.classroom_id
                    and private.is_verified_guardian(e.classroom_id, e.student_id)
                )
              )
            )
          )
        )
      )
  );
$$;

create or replace function private.can_view_resource_version(target_version uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.notebook_reader_allowed((select school_id from public.resource_versions where id = target_version)) and exists (
    select 1
    from public.resource_versions rv
    where rv.id = target_version
      and (
        private.is_school_admin(rv.school_id)
        or private.has_active_membership(
          rv.school_id,
          array['teacher']::public.app_role[]
        )
        or exists (
          select 1 from public.resource_publications rp
          where rp.resource_version_id = rv.id
            and private.can_view_resource_publication(rp.id)
        )
      )
  );
$$;

create or replace function private.can_view_resource(target_resource uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.notebook_reader_allowed((select school_id from public.resources where id = target_resource)) and exists (
    select 1
    from public.resources r
    where r.id = target_resource
      and (
        private.is_school_admin(r.school_id)
        or private.has_active_membership(
          r.school_id,
          array['teacher']::public.app_role[]
        )
        or exists (
          select 1
          from public.resource_versions rv
          where rv.resource_id = r.id
            and private.can_view_resource_version(rv.id)
        )
      )
  );
$$;

alter function private.notebook_has_access() owner to postgres;
alter function private.notebook_reader_allowed(uuid) owner to postgres;
alter function private.api041_query(text,uuid,jsonb) owner to postgres;
revoke all on function private.notebook_has_access(), private.notebook_reader_allowed(uuid)
  from public,anon,authenticated,service_role,studafy_api_runtime,studafy_worker_runtime;
