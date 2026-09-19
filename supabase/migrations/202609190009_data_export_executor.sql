-- Data export executor (DL-051). API-042 recorded export requests but
-- nothing produced an export, so a request stayed `pending` forever. The
-- worker now builds a machine-readable JSON document of the requester's own
-- data, stores it privately for seven days, and the API serves it only to
-- its owner. The document contains the requester's data only: messages they
-- sent (not messages others sent them), reports they filed (not who else
-- was named), and so on. Payloads are deleted when they expire.

create table public.data_export_payloads (
  request_id uuid primary key references public.data_export_requests(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  payload jsonb not null,
  byte_size integer not null check (byte_size > 0),
  created_at timestamptz not null default now()
);
alter table public.data_export_payloads enable row level security;
revoke all on public.data_export_payloads
  from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime;

-- Pending requests, oldest first. Building locks each row, so two workers
-- never build the same export.
create or replace function private.data_export_claim(p_limit integer default 5)
returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(id order by requested_at), '{}')
  from (
    select d.id, d.requested_at from public.data_export_requests d
    where d.status = 'pending'
    order by d.requested_at
    limit greatest(least(p_limit, 50), 1)
  ) due;
$$;

create or replace function private.data_export_document(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'format', 'studafy-export/v1',
    'generatedAt', now(),
    'sections', jsonb_build_object(
      'profile', (
        select jsonb_build_object(
          'id', p.id, 'displayName', p.display_name, 'locale', p.locale,
          'status', p.status, 'createdAt', p.created_at,
          'email', (select u.email from auth.users u where u.id = p.id)
        ) from public.profiles p where p.id = p_user),
      'memberships', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'role', m.role, 'status', m.status,
          'validFrom', m.valid_from, 'validUntil', m.valid_until
        ) order by m.created_at)
        from public.memberships m join public.schools s on s.id = m.school_id
        where m.user_id = p_user), '[]'::jsonb),
      'guardianLinks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'child', st.display_name, 'school', s.name, 'status', gl.status,
          'relationship', gl.relationship, 'verifiedAt', gl.verified_at
        ))
        from public.guardian_links gl
        join public.students st on st.id = gl.student_id
        join public.schools s on s.id = st.school_id
        where gl.guardian_id = p_user), '[]'::jsonb),
      'studentRecords', coalesce((
        select jsonb_agg(jsonb_build_object(
          'school', s.name, 'displayName', st.display_name,
          'studafyId', st.studafy_id,
          'publishedGrades', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assessment', a.title, 'score', g.score,
              'maximumScore', a.maximum_score, 'feedback', g.feedback,
              'publishedAt', g.published_at
            ) order by g.published_at)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            where g.student_id = st.id and g.state = 'published'), '[]'::jsonb),
          'attendance', coalesce((
            select jsonb_agg(jsonb_build_object(
              'state', ar.state, 'reason', ar.reason, 'recordedAt', ar.recorded_at
            ) order by ar.recorded_at)
            from public.attendance_records ar where ar.student_id = st.id), '[]'::jsonb),
          'submissions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assignment', asg.title, 'status', sb.status,
              'submittedAt', sb.submitted_at
            ) order by sb.created_at)
            from public.submissions sb
            join public.assignments asg on asg.id = sb.assignment_id
            where sb.student_id = st.id), '[]'::jsonb)
        ))
        from public.students st join public.schools s on s.id = st.school_id
        where st.user_id = p_user and st.deleted_at is null), '[]'::jsonb),
      'messagesSent', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'body', m.body, 'sentAt', m.created_at
        ) order by m.created_at)
        from (
          select * from public.messages
          where sender_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) m), '[]'::jsonb),
      'reportsFiled', coalesce((
        select jsonb_agg(jsonb_build_object(
          'kind', r.kind, 'status', r.status, 'details', r.details,
          'filedAt', r.created_at, 'resolvedAt', r.resolved_at
        ) order by r.created_at)
        from public.reports r where r.reported_by = p_user), '[]'::jsonb),
      'blocksMade', coalesce((
        select jsonb_agg(jsonb_build_object(
          'scope', b.scope, 'createdAt', b.created_at, 'expiresAt', b.expires_at
        ))
        from public.user_blocks b where b.blocker_id = p_user), '[]'::jsonb),
      'consents', coalesce((
        select jsonb_agg(jsonb_build_object(
          'purpose', c.purpose, 'policyVersion', c.policy_version,
          'acceptedAt', c.accepted_at, 'withdrawnAt', c.withdrawn_at
        ) order by c.accepted_at)
        from public.consent_records c where c.user_id = p_user), '[]'::jsonb),
      'purchases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'product', sp.feature_key, 'platform', t.platform, 'state', t.state,
          'purchasedAt', t.purchased_at, 'effectiveUntil', t.effective_until
        ) order by t.purchased_at)
        from public.store_transactions t
        join public.store_products sp on sp.id = t.product_id
        where t.purchaser_id = p_user), '[]'::jsonb),
      'entitlements', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', e.feature_key, 'status', e.status,
          'startsAt', e.starts_at, 'endsAt', e.ends_at
        ))
        from public.entitlements e where e.user_id = p_user), '[]'::jsonb),
      'notifications', coalesce((
        select jsonb_agg(jsonb_build_object(
          'template', o.template_key, 'deliveredAt', d.delivered_at,
          'readAt', d.read_at
        ) order by d.delivered_at)
        from public.notification_deliveries d
        join public.notification_outbox o on o.id = d.outbox_id
        where d.recipient_id = p_user), '[]'::jsonb)
    )
  );
$$;

create or replace function private.data_export_build(p_request_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  req public.data_export_requests%rowtype;
  doc jsonb;
begin
  select * into req from public.data_export_requests
  where id = p_request_id for update skip locked;
  if req.id is null then return 'busy_or_lost'; end if;
  if req.status <> 'pending' then return req.status; end if;
  doc := private.data_export_document(req.user_id);
  insert into public.data_export_payloads(request_id, user_id, payload, byte_size)
  values (req.id, req.user_id, doc, octet_length(doc::text))
  on conflict (request_id) do update set payload = excluded.payload,
    byte_size = excluded.byte_size, created_at = now();
  update public.data_export_requests
    set status = 'ready', ready_at = now(), expires_at = now() + interval '7 days'
    where id = req.id;
  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
  values (null, null, 'data_export_ready', 'data_export_request', req.id,
    jsonb_build_object('byteSize', octet_length(doc::text)),
    'data-export-' || req.id::text);
  return 'ready';
end;
$$;

-- Expired exports lose their payload; the request row stays as the record
-- that an export happened.
create or replace function private.data_export_expire()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  with gone as (
    update public.data_export_requests d
      set status = 'expired'
      where d.status = 'ready' and d.expires_at <= now()
      returning d.id
  )
  delete from public.data_export_payloads p using gone where p.request_id = gone.id;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- The owner's latest ready, unexpired export, or not_found.
alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_export_download;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  result jsonb;
begin
  if p_operation <> 'downloadDataExport' then
    return private.api042_query_pre_export_download(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select p.payload into result
  from public.data_export_requests d
  join public.data_export_payloads p on p.request_id = d.id
  where d.user_id = auth.uid() and d.status = 'ready' and d.expires_at > now()
  order by d.ready_at desc limit 1;
  if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
  return result;
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.data_export_claim(integer)',
    'private.data_export_document(uuid)',
    'private.data_export_build(uuid)',
    'private.data_export_expire()',
    'private.api042_query(text, uuid, jsonb)',
    'private.api042_query_pre_export_download(text, uuid, jsonb)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function
  private.data_export_claim(integer),
  private.data_export_build(uuid),
  private.data_export_expire()
to studafy_worker_runtime;
grant execute on function private.api042_query(text, uuid, jsonb) to studafy_api_runtime;
