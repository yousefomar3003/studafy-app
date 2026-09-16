-- SAFE-043 surface: the report/block/moderation/legal-hold operations layered
-- onto the existing chain, exactly the way each API-042 slice extended it.
-- private.authz_authorize, private.api042_query and private.api042_command
-- are renamed and re-wrapped; every operation this file does not claim is
-- delegated to the previous generation, so no earlier slice changes
-- behaviour.
--
-- Messaging is gated by this migration itself: a block in either direction
-- refuses new conversations/messages, and there is no environment flag to
-- turn that off (a deployment-state switch that weakened a safeguarding
-- control would be worse than none — see ADR-0021). Reads of already-
-- delivered messages keep working. Nothing here widens wellbeing
-- visibility: no function in this file reads public.wellbeing_events, so a
-- safeguarding_restricted record has no code path into the moderation queue
-- or the evidence table.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function private.safe043_is_blocked_pair(
  p_school uuid,
  p_a uuid,
  p_b uuid
)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_blocks b
    where b.school_id = p_school
      and (b.expires_at is null or b.expires_at > now())
      and (
        (b.blocker_id = p_a and b.blocked_id = p_b)
        or (b.blocker_id = p_b and b.blocked_id = p_a)
      )
  );
$$;

create or replace function private.safe043_has_active_grant(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.moderation_access_grants g
    where g.school_id = p_school and g.status = 'active'
      and g.expires_at > now() and g.requested_by = auth.uid()
  );
$$;

-- A school administrator always has their own tenant's queue; anyone else
-- needs a live, MFA-gated, two-person-approved moderation session.
create or replace function private.safe043_can_access_reports(p_school uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_school_admin(p_school)
    or private.safe043_has_active_grant(p_school);
$$;

-- A single report is visible to a school administrator or to a live grant's
-- holder, and only inside the report scope the grant was approved for. A
-- grant with no reportIds restricts to nothing narrower than the whole
-- school; a grant carrying reportIds restricts to exactly those reports.
create or replace function private.safe043_can_access_report(
  p_school uuid,
  p_report uuid
)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when private.is_school_admin(p_school) then true
    when not private.safe043_has_active_grant(p_school) then false
    else (
      select coalesce(
        scope is null
        or jsonb_typeof(scope->'reportIds') <> 'array'
        or jsonb_array_length(scope->'reportIds') = 0
        or exists (
          select 1 from jsonb_array_elements_text(scope->'reportIds') e
          where e::uuid = p_report
        ),
        true
      )
      from (
        select g.resource_scope as scope
        from public.moderation_access_grants g
        where g.school_id = p_school and g.status = 'active'
          and g.expires_at > now() and g.requested_by = auth.uid()
        order by g.created_at desc limit 1
      ) s
    )
  end;
$$;

create or replace function private.safe043_is_second_approver(p_grant uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_operator() and exists (
    select 1 from public.moderation_access_grants g
    where g.id = p_grant and g.requested_by <> auth.uid()
  );
$$;

create or replace function private.lazily_expire_moderation_access(p_school uuid)
returns void language sql security definer set search_path = '' as $$
  update public.moderation_access_grants set status = 'expired', updated_at = now()
  where school_id = p_school and status in ('pending', 'approved', 'active')
    and expires_at <= now();
$$;

-- Default configuration and baseline rule set, materialised on first use so a
-- newly provisioned school has a reviewable rule set without a tenant-specific
-- seed step. Idempotent.
create or replace function private.ensure_school_safety_defaults(p_school uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  baseline text[][] := array[
    array['bullying', 'bullying', 'phrase', 'bullying', 'high', 'flag'],
    array['harassment', 'harassment', 'phrase', 'harassment', 'high', 'flag'],
    array['threats of violence', 'violence', 'phrase', 'hurt you', 'critical', 'flag'],
    array['self-harm language', 'self_harm', 'phrase', 'kill myself', 'critical', 'flag'],
    array['sexual content', 'sexual_content', 'keyword', 'nude', 'high', 'flag'],
    array['hate speech', 'hate', 'phrase', 'hate you', 'high', 'flag'],
    array['personal data sharing', 'personal_data', 'phrase', 'my address is', 'medium', 'warn']
  ];
  rule text[];
begin
  insert into public.school_content_controls(school_id)
  values (p_school)
  on conflict (school_id) do nothing;

  foreach rule slice 1 in array baseline loop
    insert into public.safety_content_rules(
      school_id, name, category, pattern_type, pattern, severity, action,
      system_rule
    ) values (
      p_school, rule[1], rule[2]::text, rule[3], rule[4], rule[5], rule[6], true
    )
    on conflict (school_id, name) do nothing;
  end loop;
end;
$$;

create or replace function private.safe043_sla_hours(p_school uuid, p_priority text)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(
    (cc.sla_hours->>p_priority)::int,
    case p_priority
      when 'critical' then 4 when 'high' then 24
      when 'medium' then 48 else 72
    end
  )
  from (select jsonb_build_object(
    'critical', 4, 'high', 24, 'medium', 48, 'low', 72
  ) || coalesce(
    (select c.sla_hours from public.school_content_controls c where c.school_id = p_school),
    '{}'::jsonb
  ) as sla_hours) cc;
$$;

-- Rule-based priority pre-flag (never a disposition). Highest matching active
-- rule severity wins; anything else is the neutral default.
create or replace function private.safe043_rule_priority(p_school uuid, p_details text)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce((
    select r.severity from public.safety_content_rules r
    where r.school_id = p_school and r.active
      and position(lower(r.pattern) in lower(p_details)) > 0
    order by case r.severity
      when 'critical' then 1 when 'high' then 2
      when 'medium' then 3 else 4 end
    limit 1
  ), 'medium');
$$;

create or replace function private.safe043_content_controls_json(p_school uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'schoolId', s.id,
    'messagingEnabled', coalesce(cc.messaging_enabled, false),
    'contentFilterLevel', coalesce(cc.content_filter_level, 'strict'),
    'classifierAssistEnabled', coalesce(cc.classifier_assist_enabled, false),
    'supportContact', cc.support_contact,
    'slaHours', jsonb_build_object(
      'critical', 4, 'high', 24, 'medium', 48, 'low', 72
    ) || coalesce(cc.sla_hours, '{}'::jsonb),
    'version', coalesce(cc.version, 1),
    'updatedAt', cc.updated_at
  )
  from public.schools s
  left join public.school_content_controls cc on cc.school_id = s.id
  where s.id = p_school;
$$;

-- Reporter-facing report: their own words and the status timeline only. No
-- moderator identity, no moderator notes, no other reporter's data.
create or replace function private.safe043_reporter_report_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', r.id, 'schoolId', r.school_id, 'kind', r.kind, 'status', r.status,
    'resolution', r.resolution, 'details', r.details,
    'priority', r.priority, 'contactConsent', r.contact_consent,
    'subjectUserId', case when r.kind = 'user' then r.subject_user_id else null end,
    'conversationId', r.conversation_id, 'messageId', r.message_id,
    'aupVersion', r.aup_version,
    'createdAt', r.created_at, 'updatedAt', r.updated_at, 'version', r.version,
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'event', e.event, 'at', e.created_at,
        'resolution', case when e.event = 'resolve' then e.detail->>'resolution' else null end
      ) order by e.created_at, e.id)
      from public.report_events e where e.report_id = r.id
    ), '[]'::jsonb)
  )
  from public.reports r
  where r.id = p_id and r.reported_by = auth.uid();
$$;

-- Moderation-facing report. Reporter identity is withheld unless the report
-- is escalated (the explicit unmask path) and moderator-only detail is
-- included. Wellbeing data is never among it.
create or replace function private.safe043_moderation_report_json(
  p_id uuid,
  p_unmask boolean
)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', r.id, 'schoolId', r.school_id, 'kind', r.kind, 'status', r.status,
    'resolution', r.resolution, 'priority', r.priority,
    'assignedTo', r.assigned_to, 'details', r.details,
    'evidenceSnapshot', r.evidence_snapshot,
    'classifierConfidence', r.classifier_confidence,
    'aupVersion', r.aup_version, 'contactConsent', r.contact_consent,
    'subjectUserId', r.subject_user_id, 'conversationId', r.conversation_id,
    'messageId', r.message_id,
    'reporterId', case when p_unmask then r.reported_by else null end,
    'createdAt', r.created_at, 'updatedAt', r.updated_at, 'version', r.version,
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'event', e.event, 'at', e.created_at,
        'note', e.detail->>'note',
        'resolution', e.detail->>'resolution'
      ) order by e.created_at, e.id)
      from public.report_events e where e.report_id = r.id
    ), '[]'::jsonb),
    'evidence', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'kind', v.kind, 'messageId', v.message_id,
        'attachmentFileId', v.attachment_file_id, 'note', v.note,
        'addedBy', v.added_by, 'createdAt', v.created_at
      ) order by v.created_at, v.id)
      from public.report_evidence v where v.report_id = r.id
    ), '[]'::jsonb)
  )
  from public.reports r
  where r.id = p_id;
$$;

create or replace function private.safe043_block_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', b.id, 'schoolId', b.school_id, 'blockerId', b.blocker_id,
    'blockedId', b.blocked_id, 'scope', b.scope, 'reason', b.reason,
    'expiresAt', b.expires_at, 'createdAt', b.created_at, 'version', b.version
  ) from public.user_blocks b where b.id = p_id;
$$;

create or replace function private.safe043_moderation_grant_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', g.id, 'schoolId', g.school_id, 'requestedBy', g.requested_by,
    'approvedBy', g.approved_by, 'reason', g.reason, 'ticketRef', g.ticket_ref,
    'resourceScope', g.resource_scope, 'status', g.status,
    'requiresSecondApprover', g.requires_second_approver,
    'expiresAt', g.expires_at, 'startedAt', g.started_at, 'endedAt', g.ended_at,
    'version', g.version
  ) from public.moderation_access_grants g where g.id = p_id;
$$;

create or replace function private.safe043_legal_hold_json(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', h.id, 'schoolId', h.school_id, 'subjectUserId', h.subject_user_id,
    'reportId', h.report_id,
    'accountDeletionRequestId', h.account_deletion_request_id,
    'appliedTo', h.applied_to, 'reason', h.reason, 'ticketRef', h.ticket_ref,
    'status', h.status, 'grantedBy', h.granted_by, 'releasedBy', h.released_by,
    'releasedReason', h.released_reason, 'expiresAt', h.expires_at,
    'releasedAt', h.released_at, 'createdAt', h.created_at, 'version', h.version
  ) from public.legal_holds h where h.id = p_id;
$$;

-- ---------------------------------------------------------------------------
-- Authorization decision surface
-- ---------------------------------------------------------------------------

alter function private.authz_authorize(text, uuid)
  rename to authz_authorize_pre_safe043;

create or replace function private.authz_authorize(p_action text, p_resource_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare target_school uuid; permitted boolean := false;
begin
  if p_action not in (
    'content_controls.read', 'content_controls.write',
    'moderation.overview.read', 'moderation.queue.read',
    'moderation.report.read', 'moderation.triage', 'moderation.resolve',
    'moderation.escalate', 'moderation.evidence.write', 'moderation.hold',
    'moderation.access.approve', 'moderation.access.start',
    'moderation.access.revoke', 'moderation.access.list'
  ) then
    return private.authz_authorize_pre_safe043(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;

  case
    when p_action = 'content_controls.read' then
      select s.id,
        (private.has_active_membership(s.id) or private.is_school_admin(s.id)
          or private.is_platform_operator())
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action = 'content_controls.write' then
      select s.id, private.is_school_admin(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action in ('moderation.overview.read', 'moderation.queue.read') then
      select s.id, private.safe043_can_access_reports(s.id)
      into target_school, permitted from public.schools s where s.id = p_resource_id;

    when p_action in (
      'moderation.report.read', 'moderation.triage', 'moderation.resolve',
      'moderation.escalate', 'moderation.evidence.write'
    ) then
      select r.school_id, private.safe043_can_access_report(r.school_id, r.id)
      into target_school, permitted from public.reports r where r.id = p_resource_id;

    -- The same action authorizes both ends of a hold: the report id when
    -- applying, and the legal-hold id when releasing. A school admin may
    -- release a user-scoped hold of their own school (spec), anything else
    -- needs a platform operator.
    when p_action = 'moderation.hold' then
      select h.school_id,
        (private.is_platform_operator()
           or (h.applied_to = 'account' and private.is_school_admin(h.school_id)))
      into target_school, permitted from public.legal_holds h where h.id = p_resource_id;
      if target_school is null then
        select r.school_id, private.safe043_can_access_report(r.school_id, r.id)
        into target_school, permitted from public.reports r where r.id = p_resource_id;
      end if;

    when p_action = 'moderation.access.approve' then
      select g.school_id, private.safe043_is_second_approver(g.id)
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.start' then
      select g.school_id, (g.requested_by = auth.uid())
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.revoke' then
      select g.school_id,
        (private.is_platform_operator() or private.is_school_admin(g.school_id))
      into target_school, permitted from public.moderation_access_grants g where g.id = p_resource_id;

    when p_action = 'moderation.access.list' then
      select s.id, (private.is_platform_operator() or private.is_school_admin(s.id))
      into target_school, permitted from public.schools s where s.id = p_resource_id;
  end case;

  return jsonb_build_object('allowed', coalesce(permitted, false), 'school_id', target_school,
    'reason', case when target_school is null then 'invalid_resource' when permitted then 'allowed' else 'denied' end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Query surface
-- ---------------------------------------------------------------------------

alter function private.api042_query(text, uuid, jsonb)
  rename to api042_query_pre_safe043;

create or replace function private.api042_query(p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  limit_rows int; result jsonb; next_pos text;
  pos_text text := nullif(p_input->>'position', '');
  pos uuid; target_school uuid;
begin
  if p_operation not in (
    'getContentControls', 'listReports', 'getReport', 'listBlocks',
    'getModerationOverview', 'listModerationQueue', 'getModerationReport',
    'listModerationAccess'
  ) then
    return private.api042_query_pre_safe043(p_operation, p_resource_id, p_input);
  end if;
  if auth.uid() is null then return jsonb_build_object('outcome', 'forbidden'); end if;
  limit_rows := least(greatest(coalesce((p_input->>'pageSize')::int, 50), 1), 100);

  case p_operation
    when 'getContentControls' then
      if not (
        private.has_active_membership(p_resource_id)
        or private.is_school_admin(p_resource_id)
        or private.is_platform_operator()
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      select private.safe043_content_controls_json(p_resource_id) into result;
      if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return result;

    when 'listReports' then
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(
        private.safe043_reporter_report_json(x.id) order by x.id
      ), '[]'), max(x.id::text)
        into result, next_pos from (
        select r.id from public.reports r
        where r.reported_by = auth.uid()
          and (nullif(p_input->>'schoolId', '') is null
            or r.school_id = (p_input->>'schoolId')::uuid)
          and (pos is null or r.id > pos)
        order by r.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getReport' then
      select private.safe043_reporter_report_json(p_resource_id) into result;
      if result is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return result;

    when 'listBlocks' then
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(private.safe043_block_json(x.id) order by x.id), '[]'),
        max(x.id::text)
        into result, next_pos from (
        select b.id from public.user_blocks b
        where (b.blocker_id = auth.uid() or b.blocked_id = auth.uid())
          and (nullif(p_input->>'schoolId', '') is null
            or b.school_id = (p_input->>'schoolId')::uuid)
          and (pos is null or b.id > pos)
        order by b.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getModerationOverview' then
      if not private.safe043_can_access_reports(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      select jsonb_build_object(
        'schoolId', p_resource_id,
        'submitted', count(*) filter (where r.status in ('submitted', 'queued')),
        'underReview', count(*) filter (where r.status = 'under_review'),
        'onHold', count(*) filter (where r.status = 'on_hold'),
        'escalated', count(*) filter (where r.status = 'escalated'),
        'resolved', count(*) filter (where r.status = 'resolved'),
        'slaBreaches', count(*) filter (
          where r.status in ('submitted', 'queued', 'under_review', 'on_hold', 'escalated')
            and r.created_at < now() - make_interval(
              hours => private.safe043_sla_hours(p_resource_id, r.priority)
            )
        ),
        'activeModeratorSessions', (
          select count(*) from public.moderation_access_grants g
          where g.school_id = p_resource_id and g.status = 'active' and g.expires_at > now()
        )
      ) into result
      from public.reports r where r.school_id = p_resource_id;
      return result;

    when 'listModerationQueue' then
      if not private.safe043_can_access_reports(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      select coalesce(jsonb_agg(
        private.safe043_moderation_report_json(
          x.id, x.status = 'escalated'
        ) order by
          case x.priority when 'critical' then 1 when 'high' then 2
            when 'medium' then 3 else 4 end,
          x.enqueue_seq
      ), '[]'), max(x.enqueue_seq::text)
        into result, next_pos from (
        select r.id, r.status, r.priority, r.enqueue_seq
        from public.reports r
        where r.school_id = p_resource_id
          and r.status not in ('resolved', 'withdrawn')
          and (nullif(p_input->>'status', '') is null or r.status::text = p_input->>'status')
          and (nullif(p_input->>'priority', '') is null or r.priority = p_input->>'priority')
          and (nullif(p_input->>'position', '') is null
            or r.enqueue_seq > (p_input->>'position')::bigint)
        order by r.enqueue_seq limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    when 'getModerationReport' then
      select r.school_id into target_school from public.reports r where r.id = p_resource_id;
      if target_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(target_school, p_resource_id) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      select private.safe043_moderation_report_json(
        p_resource_id, exists (
          select 1 from public.reports r where r.id = p_resource_id and r.status = 'escalated'
        )
      ) into result;
      return result;

    when 'listModerationAccess' then
      if not (private.is_platform_operator() or private.is_school_admin(p_resource_id)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(p_resource_id);
      pos := nullif(pos_text, '')::uuid;
      select coalesce(jsonb_agg(private.safe043_moderation_grant_json(x.id) order by x.id), '[]'),
        max(x.id::text)
        into result, next_pos from (
        select g.id from public.moderation_access_grants g
        where g.school_id = p_resource_id and (pos is null or g.id > pos)
        order by g.id limit limit_rows
      ) x;
      return jsonb_build_object('items', result,
        'nextPosition', case when jsonb_array_length(result) = limit_rows then next_pos end);

    else return jsonb_build_object('outcome', 'not_found');
  end case;
end;
$$;

-- ---------------------------------------------------------------------------
-- Command surface
-- ---------------------------------------------------------------------------

alter function private.api042_command(text, uuid, jsonb, uuid, bigint)
  rename to api042_command_pre_safe043;

create or replace function private.api042_command(
  p_operation text,
  p_resource_id uuid,
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tenant uuid := nullif(current_setting('studafy.school_id', true), '')::uuid;
  request_id text := nullif(current_setting('studafy.request_id', true), '');
  req_body jsonb := coalesce(p_input->'body', '{}'::jsonb);
  response jsonb; before_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  idem_key text; resolved_school uuid; existing_status text; existing_version bigint;
  v_user uuid; v_digest text; v_priority text; v_message public.messages%rowtype;
  v_conversation public.conversations%rowtype; v_subject uuid; v_target uuid;
  v_attempt public.report_attempts%rowtype; v_count int; v_note text;
  v_resolution public.report_resolution; v_kind text; v_hold public.legal_holds%rowtype;
  v_applied text; v_for_user uuid; v_deletion public.account_deletion_requests%rowtype;
  v_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int, 200);
begin
  -- Block enforcement backstop for the messaging surface: a block in either
  -- direction refuses a new conversation or a new message, while reads of
  -- already-delivered messages are untouched. Delegated commands other than
  -- these two take the normal path below.
  if p_operation in ('sendMessage', 'createConversation') then
    declare
      v_school uuid;
      v_actor uuid := auth.uid();
      v_members uuid[];
    begin
      if v_actor is not null then
        if p_operation = 'sendMessage' then
          select c.school_id,
            array_agg(cp.user_id) filter (where cp.left_at is null)
          into v_school, v_members
          from public.conversations c
          join public.conversation_participants cp on cp.conversation_id = c.id
          where c.id = p_resource_id
          group by c.school_id;
        else
          v_school := nullif(req_body->>'schoolId', '')::uuid;
          select array_agg(distinct x)::uuid[] into v_members
          from jsonb_array_elements_text(coalesce(req_body->'participantIds', '[]'::jsonb)) x;
          v_members := coalesce(v_members, '{}'::uuid[]) || v_actor;
        end if;
        if v_school is not null and exists (
          select 1 from unnest(coalesce(v_members, array[v_actor])) as av(a),
            unnest(coalesce(v_members, array[v_actor])) as bv(b)
          where av.a < bv.b and private.safe043_is_blocked_pair(v_school, av.a, bv.b)
        ) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
      end if;
    end;
    return private.api042_command_pre_safe043(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;

  if p_operation not in (
    'updateContentControls', 'createReport', 'appealReport', 'createBlock',
    'unblockUser', 'triageReport', 'resolveReport', 'escalateReport',
    'addReportEvidence', 'holdReport', 'releaseLegalHold',
    'requestModerationAccess', 'approveModerationAccess',
    'startModerationAccess', 'revokeModerationAccess'
  ) then
    return private.api042_command_pre_safe043(
      p_operation, p_resource_id, p_input, p_idempotency_id, p_idempotency_generation
    );
  end if;
  if auth.uid() is null or request_id is null then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id = p_idempotency_id and r.actor_id = auth.uid()
    and r.school_id is not distinct from tenant
    and r.generation = p_idempotency_generation and r.status = 'reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome', 'forbidden'); end if;

  case p_operation
    when 'updateContentControls' then
      if not private.is_school_admin(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.ensure_school_safety_defaults(p_resource_id);
      select to_jsonb(c) into before_value from public.school_content_controls c where c.school_id = p_resource_id;
      if before_value is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if (before_value->>'version')::bigint <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.school_content_controls set
        messaging_enabled = coalesce((req_body->>'messagingEnabled')::boolean, messaging_enabled),
        content_filter_level = coalesce(nullif(req_body->>'contentFilterLevel', ''), content_filter_level),
        classifier_assist_enabled = coalesce(
          (req_body->>'classifierAssistEnabled')::boolean, classifier_assist_enabled),
        support_contact = case when req_body ? 'supportContact'
          then nullif(req_body->>'supportContact', '') else support_contact end,
        sla_hours = coalesce(req_body->'slaHours', sla_hours),
        updated_by = auth.uid(), version = version + 1, updated_at = now()
      where school_id = p_resource_id;
      resolved_school := p_resource_id;
      entity_id := (before_value->>'id')::uuid;
      entity_type := 'school_content_controls'; audit_action := 'safety_controls_updated';
      response := private.safe043_content_controls_json(p_resource_id);

    when 'createReport' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      if not exists (
        select 1 from public.schools s where s.id = resolved_school and s.status = 'active'
      ) then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.can_message_in_school(auth.uid(), resolved_school) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.ensure_school_safety_defaults(resolved_school);
      v_kind := req_body->>'kind';
      if v_kind not in ('message', 'conversation', 'user') then
        return jsonb_build_object('outcome', 'invalid');
      end if;

      if v_kind = 'message' then
        select m.* into v_message from public.messages m
        where m.id = (req_body->>'messageId')::uuid and m.school_id = resolved_school;
        if v_message.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
        if not (private.is_conversation_participant(v_message.conversation_id)
          or private.is_school_admin(resolved_school)) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
        select jsonb_build_object(
          'messageBody', v_message.body, 'senderId', v_message.sender_id,
          'createdAt', v_message.created_at, 'conversationId', v_message.conversation_id
        ) into before_value;
      elsif v_kind = 'conversation' then
        select c.* into v_conversation from public.conversations c
        where c.id = (req_body->>'conversationId')::uuid and c.school_id = resolved_school;
        if v_conversation.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
        if not (private.is_conversation_participant(v_conversation.id)
          or private.is_school_admin(resolved_school)) then
          return jsonb_build_object('outcome', 'forbidden');
        end if;
        select jsonb_build_object(
          'subject', v_conversation.subject, 'state', v_conversation.state,
          'createdAt', v_conversation.created_at
        ) into before_value;
      else
        v_subject := nullif(req_body->>'subjectUserId', '')::uuid;
        if v_subject is null or v_subject = auth.uid() then
          return jsonb_build_object('outcome', 'invalid');
        end if;
        if not (
          private.has_active_membership(resolved_school)
          and exists (
            select 1 from public.memberships m
            where m.user_id = v_subject and m.school_id = resolved_school and m.active
          )
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
        before_value := '{}'::jsonb;
      end if;

      -- Dedupe: the same normalized concern inside a live window is refused.
      v_digest := encode(extensions.digest(
        lower(btrim(regexp_replace(req_body->>'details', '\s+', ' ', 'g'))), 'sha256'
      ), 'hex');
      select a.* into v_attempt from public.report_attempts a
      where a.school_id = resolved_school and a.reporter_id = auth.uid()
        and a.digest = v_digest and a.window_expires_at > now()
      for update;
      if v_attempt.id is not null then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      select count(*) into v_count from public.report_attempts a
      where a.school_id = resolved_school and a.reporter_id = auth.uid()
        and a.window_expires_at > now();
      if v_count >= 20 then return jsonb_build_object('outcome', 'window_closed'); end if;

      v_priority := private.safe043_rule_priority(resolved_school, req_body->>'details');
      insert into public.reports(
        school_id, reported_by, kind, status, subject_user_id, conversation_id,
        message_id, details, evidence_snapshot, classifier_confidence,
        aup_version, contact_consent, priority
      ) values (
        resolved_school, auth.uid(), v_kind::public.report_kind, 'queued',
        case when v_kind = 'user' then v_subject end,
        case when v_kind = 'conversation' then v_conversation.id
          when v_kind = 'message' then v_message.conversation_id end,
        case when v_kind = 'message' then v_message.id end,
        req_body->>'details', coalesce(before_value, '{}'::jsonb),
        (req_body->>'classifierConfidence')::numeric,
        nullif(req_body->>'aupVersion', ''),
        coalesce((req_body->>'contactConsent')::boolean, false),
        v_priority
      ) returning id into entity_id;
      insert into public.report_attempts(
        school_id, reporter_id, digest, count_this_window, window_started_at, window_expires_at
      ) values (
        resolved_school, auth.uid(), v_digest, 1, now(), now() + interval '24 hours'
      );
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, entity_id, auth.uid(), 'submitted',
        jsonb_build_object('kind', v_kind, 'priority', v_priority)),
        (resolved_school, entity_id, auth.uid(), 'queued',
        jsonb_build_object('priority', v_priority));
      tenant := resolved_school;
      response := private.safe043_reporter_report_json(entity_id);
      entity_type := 'report'; audit_action := 'report_submitted';

    when 'appealReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null or v_user <> auth.uid() then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if existing_status <> 'resolved' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'under_review', resolution = null,
        resolved_at = null, version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'appeal',
        jsonb_build_object('note', nullif(req_body->>'reason', '')));
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_appealed';
      tenant := resolved_school;
      response := private.safe043_reporter_report_json(entity_id);

    when 'createBlock' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      v_target := nullif(req_body->>'blockedUserId', '')::uuid;
      if v_target is null or v_target = auth.uid() then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      if not private.can_message_in_school(auth.uid(), resolved_school)
         or not private.can_message_in_school(v_target, resolved_school) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      insert into public.user_blocks(
        school_id, blocker_id, blocked_id, scope, reason, expires_at
      ) values (
        resolved_school, auth.uid(), v_target,
        coalesce(nullif(req_body->>'scope', ''), 'messages'),
        nullif(req_body->>'reason', ''),
        case when (req_body->>'durationHours') is not null
          then now() + make_interval(hours => greatest((req_body->>'durationHours')::int, 1)) end
      )
      on conflict (school_id, blocker_id, blocked_id) do update set
        scope = excluded.scope, reason = excluded.reason, expires_at = excluded.expires_at,
        version = public.user_blocks.version + 1, updated_at = now()
      returning id into entity_id;
      tenant := resolved_school;
      response := private.safe043_block_json(entity_id);
      entity_type := 'user_block'; audit_action := 'user_blocked';

    when 'unblockUser' then
      select b.school_id, b.blocker_id, to_jsonb(b)
        into resolved_school, v_user, before_value
      from public.user_blocks b where b.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not (v_user = auth.uid() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      delete from public.user_blocks where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'user_block'; audit_action := 'user_unblocked';
      tenant := resolved_school;
      response := before_value;

    when 'triageReport' then
      select r.school_id, r.status, r.version, to_jsonb(r)
        into resolved_school, existing_status, existing_version, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('submitted', 'queued') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'under_review',
        priority = coalesce(nullif(req_body->>'priority', ''), priority),
        assigned_to = coalesce(nullif(req_body->>'assignedTo', '')::uuid, assigned_to),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'triage',
        jsonb_build_object('note', nullif(req_body->>'note', '')));
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_triaged';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, false);

    when 'resolveReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('under_review', 'on_hold') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      v_resolution := (req_body->>'resolution')::public.report_resolution;
      update public.reports set status = 'resolved', resolution = v_resolution,
        resolution_note = nullif(req_body->>'note', ''), resolved_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'resolve',
        jsonb_build_object('resolution', v_resolution, 'note', nullif(req_body->>'note', '')));
      perform private.notify_recipient(
        resolved_school, v_user, 'safety.report_resolved',
        jsonb_build_object('reportId', p_resource_id, 'resolution', v_resolution),
        'report:' || p_resource_id, 'safety.report_resolved:' || p_resource_id
      );
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_resolved';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, false);

    when 'escalateReport' then
      select r.school_id, r.status, r.version, r.reported_by, to_jsonb(r)
        into resolved_school, existing_status, existing_version, v_user, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status in ('resolved', 'withdrawn') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.reports set status = 'escalated',
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'escalate',
        jsonb_build_object('note', nullif(req_body->>'note', '')));
      perform private.notify_recipient(
        resolved_school, v_user, 'safety.report_escalated',
        jsonb_build_object('reportId', p_resource_id),
        'report:' || p_resource_id, 'safety.report_escalated:' || p_resource_id
      );
      entity_id := p_resource_id; entity_type := 'report'; audit_action := 'report_escalated';
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(entity_id, true);

    when 'addReportEvidence' then
      select r.school_id, r.status, r.version, to_jsonb(r)
        into resolved_school, existing_status, existing_version, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_can_access_report(resolved_school, p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      v_kind := req_body->>'kind';
      if v_kind = 'message' then
        if not exists (
          select 1 from public.messages m
          where m.id = (req_body->>'messageId')::uuid and m.school_id = resolved_school
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
      elsif v_kind = 'attachment' then
        if not exists (
          select 1 from public.file_objects f
          where f.id = (req_body->>'attachmentFileId')::uuid and f.school_id = resolved_school
        ) then return jsonb_build_object('outcome', 'invalid'); end if;
      elsif v_kind is null or v_kind <> 'note' then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      insert into public.report_evidence(
        school_id, report_id, added_by, kind, message_id, attachment_file_id,
        note, content_hash
      ) values (
        resolved_school, p_resource_id, auth.uid(), v_kind,
        case when v_kind = 'message' then (req_body->>'messageId')::uuid end,
        case when v_kind = 'attachment' then (req_body->>'attachmentFileId')::uuid end,
        case when v_kind = 'note' then req_body->>'note' end,
        nullif(req_body->>'contentHash', '')
      ) returning id into entity_id;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'evidence_added',
        jsonb_build_object('evidenceId', entity_id, 'kind', v_kind));
      tenant := resolved_school;
      response := private.safe043_moderation_report_json(p_resource_id, false);
      entity_type := 'report'; audit_action := 'report_evidence_added';

    when 'holdReport' then
      select r.school_id, r.status, r.subject_user_id, to_jsonb(r)
        into resolved_school, existing_status, v_subject, before_value
      from public.reports r where r.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.is_platform_operator() then return jsonb_build_object('outcome', 'forbidden'); end if;
      v_applied := coalesce(nullif(req_body->>'appliedTo', ''), 'report');
      v_for_user := coalesce(nullif(req_body->>'subjectUserId', '')::uuid, v_subject);
      if v_applied = 'account' and v_for_user is null then
        return jsonb_build_object('outcome', 'invalid');
      end if;
      -- Applying an account hold to a live deletion request is what makes the
      -- hold actually retain data: the existing deletion constraint refuses to
      -- complete a request flagged as held.
      if v_applied = 'account' then
        select d.* into v_deletion from public.account_deletion_requests d
        where d.user_id = v_for_user and d.state in ('grace_period', 'executing')
        for update;
        if v_deletion.id is not null then
          update public.account_deletion_requests
          set legal_hold = true,
            legal_hold_reason = coalesce(legal_hold_reason, req_body->>'reason')
          where id = v_deletion.id;
        end if;
      end if;
      insert into public.legal_holds(
        school_id, subject_user_id, report_id, account_deletion_request_id,
        applied_to, reason, ticket_ref, granted_by, expires_at
      ) values (
        resolved_school, v_for_user, p_resource_id, v_deletion.id,
        v_applied, req_body->>'reason', req_body->>'ticketRef', auth.uid(),
        case when (req_body->>'expiresAt') is not null
          then greatest((req_body->>'expiresAt')::timestamptz, now() + interval '1 hour')
          else null end
      ) returning id into entity_id;
      if existing_status in ('submitted', 'queued', 'under_review', 'escalated') then
        update public.reports set status = 'on_hold', version = version + 1, updated_at = now()
        where id = p_resource_id;
      end if;
      insert into public.report_events(school_id, report_id, actor_id, event, detail)
      values (resolved_school, p_resource_id, auth.uid(), 'hold',
        jsonb_build_object('holdId', entity_id, 'appliedTo', v_applied));
      tenant := resolved_school;
      response := private.safe043_legal_hold_json(entity_id);
      entity_type := 'legal_hold'; audit_action := 'legal_hold_applied';
      v_template := 'safety.report_held'; outbox_entity := entity_id;

    when 'releaseLegalHold' then
      select h.* into v_hold from public.legal_holds h
      where h.id = p_resource_id for update;
      if v_hold.id is null then return jsonb_build_object('outcome', 'not_found'); end if;
      -- A platform operator may release any hold; a school admin only a
      -- user-scoped hold of their own school (the account-deletion pause is
      -- theirs to lift; the report scoping is a platform responsibility).
      if not (
        private.is_platform_operator()
        or (v_hold.applied_to = 'account' and private.is_school_admin(v_hold.school_id))
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      if v_hold.status <> 'active' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if v_hold.version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      before_value := to_jsonb(v_hold);
      update public.legal_holds set status = 'released', released_by = auth.uid(),
        released_reason = coalesce(nullif(req_body->>'reason', ''), 'released'),
        released_at = now(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      if v_hold.applied_to = 'account' and v_hold.account_deletion_request_id is not null then
        if not exists (
          select 1 from public.legal_holds h2
          where h2.id <> p_resource_id and h2.status = 'active'
            and h2.applied_to = 'account'
            and h2.subject_user_id = v_hold.subject_user_id
        ) then
          update public.account_deletion_requests
          set legal_hold = false
          where id = v_hold.account_deletion_request_id;
        end if;
      end if;
      resolved_school := v_hold.school_id;
      entity_id := p_resource_id; entity_type := 'legal_hold'; audit_action := 'legal_hold_released';
      response := private.safe043_legal_hold_json(entity_id);

    when 'requestModerationAccess' then
      resolved_school := nullif(req_body->>'schoolId', '')::uuid;
      if not exists (select 1 from public.schools s where s.id = resolved_school) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      if not (private.is_platform_operator() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if not coalesce((p_input->>'aal2')::boolean, false) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      insert into public.moderation_access_grants(
        school_id, requested_by, reason, ticket_ref, resource_scope, status,
        requires_second_approver, mfa_verified_at, expires_at, version
      ) values (
        resolved_school, auth.uid(), req_body->>'reason', req_body->>'ticketRef',
        coalesce(req_body->'resourceScope', '{}'::jsonb), 'pending',
        coalesce((req_body->>'requiresSecondApprover')::boolean, true), now(),
        now() + make_interval(mins => least(greatest(
          coalesce((req_body->>'durationMinutes')::int, 60), 1), 480)),
        1
      ) returning id into entity_id;
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);
      entity_type := 'moderation_access_grant'; audit_action := 'moderation_access_requested';

    when 'approveModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not private.safe043_is_second_approver(p_resource_id) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if not coalesce((p_input->>'aal2')::boolean, false) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      select status, version into existing_status, existing_version
      from public.moderation_access_grants where id = p_resource_id;
      if existing_status <> 'pending' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'approved',
        approved_by = auth.uid(), version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_approved';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    when 'startModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not exists (
        select 1 from public.moderation_access_grants g
        where g.id = p_resource_id and g.requested_by = auth.uid()
      ) then return jsonb_build_object('outcome', 'forbidden'); end if;
      perform private.lazily_expire_moderation_access(resolved_school);
      select status, version into existing_status, existing_version
      from public.moderation_access_grants where id = p_resource_id;
      if existing_status <> 'approved' then return jsonb_build_object('outcome', 'invalid_state'); end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'active', started_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_started';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    when 'revokeModerationAccess' then
      select g.school_id, g.status, g.version, to_jsonb(g)
        into resolved_school, existing_status, existing_version, before_value
      from public.moderation_access_grants g where g.id = p_resource_id for update;
      if resolved_school is null then return jsonb_build_object('outcome', 'not_found'); end if;
      if not (private.is_platform_operator() or private.is_school_admin(resolved_school)) then
        return jsonb_build_object('outcome', 'forbidden');
      end if;
      if existing_status not in ('pending', 'approved', 'active') then
        return jsonb_build_object('outcome', 'invalid_state');
      end if;
      if existing_version <> (req_body->>'expectedVersion')::bigint then
        return jsonb_build_object('outcome', 'version_conflict');
      end if;
      update public.moderation_access_grants set status = 'revoked', revoked_by = auth.uid(),
        revoked_reason = nullif(req_body->>'reason', ''), ended_at = now(),
        version = version + 1, updated_at = now()
      where id = p_resource_id;
      entity_id := p_resource_id; entity_type := 'moderation_access_grant';
      audit_action := 'moderation_access_revoked';
      tenant := resolved_school;
      response := private.safe043_moderation_grant_json(entity_id);

    else return jsonb_build_object('outcome', 'invalid');
  end case;

  insert into public.audit_events(school_id, actor_id, action, entity_type, entity_id, before_value, after_value, request_id)
  values (tenant, auth.uid(), audit_action, entity_type, entity_id, before_value, response, request_id);
  if v_template is not null then
    insert into public.notification_outbox(school_id, source_event_id, idempotency_key, channel, template_key, audience, payload)
    values (tenant, outbox_entity::text, idem_key, 'in_app', v_template,
      jsonb_build_object('schoolId', tenant), coalesce(response, '{}'::jsonb));
  end if;
  completed := private.api_idempotency_complete(p_idempotency_id, p_idempotency_generation, response_status, response);
  if not completed then raise exception 'API042_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
end;
$$;

-- Queue pagination needs a submission-ordered monotonic key independent of the
-- random uuid primary key. Added here rather than in the schema migration so
-- the identity is created by the migration that first relies on it.
alter table public.reports
  add column if not exists enqueue_seq bigint generated always as identity;
create index if not exists reports_enqueue_idx
  on public.reports (school_id, enqueue_seq);

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

alter function private.safe043_is_blocked_pair(uuid, uuid, uuid) owner to postgres;
alter function private.safe043_has_active_grant(uuid) owner to postgres;
alter function private.safe043_can_access_reports(uuid) owner to postgres;
alter function private.safe043_can_access_report(uuid, uuid) owner to postgres;
alter function private.safe043_is_second_approver(uuid) owner to postgres;
alter function private.lazily_expire_moderation_access(uuid) owner to postgres;
alter function private.ensure_school_safety_defaults(uuid) owner to postgres;
alter function private.safe043_sla_hours(uuid, text) owner to postgres;
alter function private.safe043_rule_priority(uuid, text) owner to postgres;
alter function private.safe043_content_controls_json(uuid) owner to postgres;
alter function private.safe043_reporter_report_json(uuid) owner to postgres;
alter function private.safe043_moderation_report_json(uuid, boolean) owner to postgres;
alter function private.safe043_block_json(uuid) owner to postgres;
alter function private.safe043_moderation_grant_json(uuid) owner to postgres;
alter function private.safe043_legal_hold_json(uuid) owner to postgres;
alter function private.api042_query(text, uuid, jsonb) owner to postgres;
alter function private.api042_command(text, uuid, jsonb, uuid, bigint) owner to postgres;
alter function private.authz_authorize(text, uuid) owner to postgres;

revoke all on function
  private.safe043_is_blocked_pair(uuid, uuid, uuid),
  private.safe043_has_active_grant(uuid),
  private.safe043_can_access_reports(uuid),
  private.safe043_can_access_report(uuid, uuid),
  private.safe043_is_second_approver(uuid),
  private.lazily_expire_moderation_access(uuid),
  private.ensure_school_safety_defaults(uuid),
  private.safe043_sla_hours(uuid, text),
  private.safe043_rule_priority(uuid, text),
  private.safe043_content_controls_json(uuid),
  private.safe043_reporter_report_json(uuid),
  private.safe043_moderation_report_json(uuid, boolean),
  private.safe043_block_json(uuid),
  private.safe043_moderation_grant_json(uuid),
  private.safe043_legal_hold_json(uuid),
  private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime;
revoke all on function private.api042_query_pre_safe043(text, uuid, jsonb)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.api042_command_pre_safe043(text, uuid, jsonb, uuid, bigint)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize_pre_safe043(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime, studafy_api_runtime;
revoke all on function private.authz_authorize(text, uuid)
from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.authz_authorize(text, uuid),
  private.api042_query(text, uuid, jsonb),
  private.api042_command(text, uuid, jsonb, uuid, bigint)
to studafy_api_runtime;

revoke all privileges on all tables in schema public from studafy_api_runtime;
revoke all privileges on all sequences in schema public from studafy_api_runtime;
