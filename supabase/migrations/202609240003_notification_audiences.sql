-- Notifications reach the people an event is actually about.
--
-- Every outbox row in the product is written with one of two audiences:
-- {'classroomId': ...} or {'schoolId': ...}. api061_finish_notification
-- resolved the first to that classroom's staff and the second to the
-- school's admins and teachers, and to nobody else. So no student and no
-- guardian has ever received a single notification: publishing homework
-- notified other teachers, and a guardian whose link was verified was told
-- by no one. The parent Updates tab was not failing to load - there was
-- never anything addressed to a parent for it to show.
--
-- The audience column keeps exactly the shape the command functions write,
-- because who ought to hear about an event is a notification decision, and
-- it belongs in one place rather than spread across five command
-- dispatchers and every future one.

-- Resolves one outbox row to its in-app recipients.
--
-- Returns null for an audience this deployment cannot resolve, which is the
-- caller's signal to dead-letter the row; an empty array is a real answer
-- meaning "nobody to tell", and completes it.
create or replace function private.api061_notification_recipients(
  p_school uuid,
  p_template text,
  p_source text,
  p_audience jsonb
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_classroom uuid;
  v_source uuid;
  v_staff uuid[] := array[]::uuid[];
  v_family uuid[] := array[]::uuid[];
  v_students uuid[] := array[]::uuid[];
  -- Whether the child themselves hears about it, separately from their
  -- guardians. Almost always yes; a pastoral note shared with home is the
  -- exception the school explicitly asked for.
  v_tell_student boolean := true;
begin
  -- source_event_id is text, and not every producer writes a uuid into it.
  -- Casting it unconditionally raised inside the dispatcher, which fails the
  -- job rather than the row and eventually poisons the queue for everyone,
  -- so anything that is not a uuid is simply "no entity" here.
  if p_source ~ ('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
                 || '-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') then
    v_source := p_source::uuid;
  end if;

  -- The staff audience, unchanged from what this function has always done.
  -- Every existing template keeps exactly the recipients it had.
  if p_audience->>'classroomId' is not null then
    v_classroom := nullif(p_audience->>'classroomId', '')::uuid;
    if v_classroom is null then return null; end if;
    select coalesce(array_agg(m.user_id), array[]::uuid[]) into v_staff
    from public.memberships m
    join public.classroom_staff cs
      on cs.school_id = m.school_id and cs.user_id = m.user_id
    join public.profiles p on p.id = m.user_id and p.status = 'active'
    where m.school_id = p_school and m.active and m.status = 'active'
      and cs.classroom_id = v_classroom and cs.status = 'active'
      and cs.role in ('lead_teacher', 'co_teacher', 'assistant');
  elsif p_audience->>'schoolId' is not null
        and nullif(p_audience->>'schoolId', '')::uuid = p_school then
    select coalesce(array_agg(m.user_id), array[]::uuid[]) into v_staff
    from public.memberships m
    join public.profiles p on p.id = m.user_id and p.status = 'active'
    where m.school_id = p_school and m.active and m.status = 'active'
      and m.role in ('school_admin', 'teacher');
  else
    return null;
  end if;

  -- A guardian link concerns two named people, not a class. The requesting
  -- guardian is not verified yet, so they are read from the link row itself
  -- rather than through the verified-guardian join used everywhere else.
  -- Both sides are told about all three events: the student is the one who
  -- decides on a request, and the guardian is the one a verification or a
  -- revocation is about.
  if p_template like 'family.guardian_link_%' then
    select coalesce(array_agg(distinct x.user_id), array[]::uuid[])
      into v_family
    from (
      select gl.guardian_id as user_id
      from public.guardian_links gl
      where gl.id = v_source and gl.school_id = p_school
      union
      select s.user_id
      from public.guardian_links gl
      join public.students s
        on s.id = gl.student_id and s.deleted_at is null
      where gl.id = v_source and gl.school_id = p_school
        and s.user_id is not null
    ) x
    join public.profiles p on p.id = x.user_id and p.status = 'active';
    return (
      select coalesce(array_agg(distinct u), array[]::uuid[])
      from unnest(v_staff || v_family) as t(u)
    );
  end if;

  -- Which children the event is about. Left empty for every template that
  -- concerns staff alone, which is why those are untouched by this.
  if p_template in ('academic.assignment_published',
                    'academic.assessment_published',
                    'academic.resource_published')
  then
    -- Set for the whole class, so the whole class hears about it.
    select coalesce(array_agg(e.student_id), array[]::uuid[]) into v_students
    from public.enrollments e
    where e.school_id = p_school and e.classroom_id = v_classroom
      and e.active and e.status = 'active'
      and e.starts_on <= current_date
      and (e.ends_on is null or e.ends_on >= current_date);
  elsif p_template = 'academic.grade_published' then
    -- One child's mark. Announcing it to the class would be both noise and
    -- a statement about somebody else's child.
    select coalesce(array_agg(g.student_id), array[]::uuid[]) into v_students
    from public.grade_results g
    where g.id = v_source and g.school_id = p_school
      and g.state = 'published';
  elsif p_template = 'academic.wellbeing_shared' then
    -- Re-read the visibility here rather than trusting the template name:
    -- if a note has since been restricted, this must not announce it. A
    -- safeguarding-restricted note matches nothing and reaches no family.
    select coalesce(array_agg(w.student_id), array[]::uuid[]),
           bool_or(w.visibility = 'student_guardian_shared')
      into v_students, v_tell_student
    from public.wellbeing_events w
    where w.id = v_source and w.school_id = p_school
      and w.visibility in ('guardian_shared', 'student_guardian_shared');
    v_tell_student := coalesce(v_tell_student, false);
  end if;

  if cardinality(v_students) = 0 then
    return (
      select coalesce(array_agg(distinct u), array[]::uuid[])
      from unnest(v_staff) as t(u)
    );
  end if;

  select coalesce(array_agg(distinct x.user_id), array[]::uuid[])
    into v_family
  from (
    select s.user_id
    from public.students s
    where v_tell_student and s.id = any(v_students)
      and s.deleted_at is null and s.user_id is not null
    union
    -- An expired or revoked link is not a link. This is the same test the
    -- read paths use, so nobody is notified about a child whose record they
    -- could no longer open.
    select gl.guardian_id
    from public.guardian_links gl
    where gl.student_id = any(v_students) and gl.school_id = p_school
      and gl.status = 'verified'
      and (gl.expires_at is null or gl.expires_at > now())
  ) x
  join public.profiles p on p.id = x.user_id and p.status = 'active';

  return (
    select coalesce(array_agg(distinct u), array[]::uuid[])
    from unnest(v_staff || v_family) as t(u)
  );
end;
$$;

-- Unchanged except that the audience is resolved by the function above
-- instead of inline, so the two dead-letter paths and the single-transaction
-- completion stay exactly as they were.
create or replace function private.api061_finish_notification(
  p_outbox_id bigint
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  row_state public.notification_outbox%rowtype;
  recipients uuid[];
  failure_code text;
begin
  select * into row_state from public.notification_outbox where id = p_outbox_id for update;
  -- Already finished by a concurrent/duplicate run: idempotent no-op.
  if row_state.state = 'completed' then return 'completed'; end if;
  if row_state.state = 'dead_letter' then return 'terminal'; end if;
  if row_state.id is null or row_state.state <> 'processing' then
    return 'lost';
  end if;

  if row_state.channel <> 'in_app' then
    failure_code := 'UNSUPPORTED_CHANNEL';
  else
    recipients := private.api061_notification_recipients(
      row_state.school_id, row_state.template_key,
      row_state.source_event_id, row_state.audience);
    if recipients is null then failure_code := 'UNSUPPORTED_AUDIENCE'; end if;
  end if;

  if failure_code is not null then
    update public.notification_outbox
      set state = 'dead_letter', lease_token = null, lease_until = null,
          last_error_code = failure_code, updated_at = now()
      where id = row_state.id;
    insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, after_value, request_id)
    values (row_state.school_id, null, 'ops061_outbox_dead_letter', 'notification_outbox', null,
      jsonb_build_object('outboxId', row_state.id, 'templateKey', row_state.template_key,
        'errorCode', failure_code),
      'ops061-dlq-' || row_state.id || '-' || extract(epoch from now())::bigint);
    return 'terminal';
  end if;

  insert into public.notification_deliveries(
    school_id, outbox_id, recipient_id, channel, attempt, state, delivered_at
  )
  select row_state.school_id, row_state.id, m.user_id, row_state.channel, 1,
         'sent', now()
  from unnest(recipients) as m(user_id)
  on conflict (outbox_id, recipient_id, channel, attempt) do nothing;

  update public.notification_outbox
    set state = 'completed', lease_token = null, lease_until = null,
        last_error_code = null, updated_at = now()
    where id = row_state.id;
  return 'completed';
end;
$$;

alter function private.api061_notification_recipients(uuid, text, text, jsonb)
  owner to postgres;
alter function private.api061_finish_notification(bigint) owner to postgres;

-- The resolver is reachable only from inside the finisher, which runs as its
-- owner. No runtime role needs it directly.
revoke all on function
  private.api061_notification_recipients(uuid, text, text, jsonb)
  from public, anon, authenticated, service_role,
       studafy_api_runtime, studafy_worker_runtime;
revoke all on function private.api061_finish_notification(bigint)
  from public, anon, authenticated, service_role, studafy_api_runtime;
grant execute on function private.api061_finish_notification(bigint)
  to studafy_worker_runtime;
