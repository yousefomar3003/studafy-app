-- DL-076: AI outputs can be reported (store policy).
--
-- Google Play's AI-Generated Content policy, and Apple's review, ask that a
-- person can flag an offensive AI answer from inside the app. The safety
-- reports (public.reports, createReport) are school-scoped, and a student
-- with no class has no school, so AI outputs get their own small path:
--
-- 1. private.ai_output_reports: who reported which AI feature's output, why,
--    their optional words, and the output itself (capped at 4,000
--    characters) so a reviewer can see what was said. Filed only through
--    private.ai_output_report_file, as the signed-in, active account.
-- 2. An alert queue, as for safety reports (202610150080): a trigger adds
--    one row per report and the worker sends the reviewers' Telegram chat a
--    message carrying only the report id, "AI output", the feature and the
--    reason. Never the output, the details, a name or an account id.
-- 3. Retention: reports are kept 180 days, purged by the worker's hourly
--    retention schedule. Deleting the account takes its reports with it;
--    the export lists them.

create table private.ai_output_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  feature text not null
    check (feature in ('tutor', 'notes', 'notebook', 'quiz', 'flashcards', 'summary')),
  reason text not null check (reason in ('offensive', 'harmful', 'wrong', 'other')),
  details text check (details is null
    or (char_length(details) between 1 and 1000 and details = btrim(details))),
  excerpt text not null check (char_length(excerpt) between 1 and 4000),
  status text not null default 'open' check (status in ('open', 'reviewed')),
  created_at timestamptz not null default now()
);

create index ai_output_reports_reporter_idx
  on private.ai_output_reports (reporter_id);
create index ai_output_reports_created_idx
  on private.ai_output_reports (created_at);

create table private.ai_output_report_alerts (
  report_id uuid primary key
    references private.ai_output_reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  -- A claim is a lease: another worker may take the row once it lapses.
  claimed_until timestamptz,
  sent_at timestamptz,
  -- A short error code from the sender (never a message body or a URL).
  last_error text check (last_error is null or last_error ~ '^[A-Z0-9_]{1,64}$')
);

create index ai_output_report_alerts_pending_idx
  on private.ai_output_report_alerts (created_at)
  where sent_at is null;

do $$
declare t text;
begin
  foreach t in array array['ai_output_reports', 'ai_output_report_alerts'] loop
    execute format('alter table private.%I enable row level security', t);
    execute format('revoke all on private.%I from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Filing a report: the API calls this as the user (request.jwt.claim.sub),
-- inside the request's idempotency reservation, which it completes in the
-- same transaction so a retried request files nothing twice.
-- ---------------------------------------------------------------------------
create or replace function private.ai_output_report_file(
  p_input jsonb,
  p_idempotency_id uuid,
  p_idempotency_generation bigint
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_feature text := p_input->>'feature';
  v_reason text := p_input->>'reason';
  v_details text := nullif(btrim(coalesce(p_input->>'details', '')), '');
  v_excerpt text := left(btrim(coalesce(p_input->>'excerpt', '')), 4000);
  v_id uuid;
  v_created timestamptz;
  response jsonb;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  if v_feature is null
     or v_feature not in ('tutor', 'notes', 'notebook', 'quiz', 'flashcards', 'summary')
     or v_reason is null
     or v_reason not in ('offensive', 'harmful', 'wrong', 'other')
     or v_excerpt = ''
     or char_length(coalesce(v_details, '')) > 1000 then
    return jsonb_build_object('outcome', 'invalid');
  end if;

  insert into private.ai_output_reports (reporter_id, feature, reason, details, excerpt)
  values (auth.uid(), v_feature, v_reason, v_details, v_excerpt)
  returning id, created_at into v_id, v_created;

  response := jsonb_build_object(
    'id', v_id,
    'createdAt', to_char(v_created at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'));
  if not private.api_idempotency_complete(
    p_idempotency_id, p_idempotency_generation, 201, response) then
    raise exception 'AI_OUTPUT_REPORT_IDEMPOTENCY_COMPLETION_FAILED';
  end if;
  return jsonb_build_object('outcome', 'ok', 'response', response);
exception when check_violation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;

-- ---------------------------------------------------------------------------
-- The alert queue (as private.report_alerts, 202610150080).
-- ---------------------------------------------------------------------------
create or replace function private.ai_output_alerts_enqueue()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into private.ai_output_report_alerts (report_id) values (new.id)
  on conflict (report_id) do nothing;
  return new;
end;
$$;

create trigger ai_output_reports_alert_on_insert
  after insert on private.ai_output_reports
  for each row execute function private.ai_output_alerts_enqueue();

-- Claims up to p_limit unsent alerts for p_lease_seconds. Returns only what
-- the alert may carry: no output, no details, no account.
create or replace function private.ai_output_alerts_claim(
  p_limit integer,
  p_lease_seconds integer
)
returns table (
  report_id uuid,
  feature text,
  reason text,
  reported_at timestamptz,
  attempts integer
)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
begin
  if p_limit is null or p_limit not between 1 and 100
     or p_lease_seconds is null or p_lease_seconds not between 10 and 3600 then
    raise exception 'AI_OUTPUT_ALERTS_INVALID_CLAIM';
  end if;
  return query
  with due as (
    select a.report_id
    from private.ai_output_report_alerts a
    where a.sent_at is null
      and (a.claimed_until is null or a.claimed_until <= now())
    order by a.created_at
    limit p_limit
    for update skip locked
  ), claimed as (
    update private.ai_output_report_alerts a
    set claimed_until = now() + make_interval(secs => p_lease_seconds),
        attempts = a.attempts + 1
    from due
    where a.report_id = due.report_id
    returning a.report_id, a.attempts
  )
  select c.report_id, r.feature, r.reason, r.created_at, c.attempts
  from claimed c
  join private.ai_output_reports r on r.id = c.report_id
  order by r.created_at;
end;
$$;

-- Records the outcome of one send. A failure is retried after a backoff
-- (1, 2, 4 ... minutes, at most 30), indefinitely.
create or replace function private.ai_output_alerts_finish(
  p_report uuid,
  p_sent boolean,
  p_error text
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_attempts integer;
begin
  if p_sent then
    update private.ai_output_report_alerts
    set sent_at = now(), claimed_until = null, last_error = null
    where report_id = p_report and sent_at is null;
    return found;
  end if;
  update private.ai_output_report_alerts
  set claimed_until = now() + make_interval(
        mins => least(30, power(2, greatest(attempts - 1, 0))::integer)),
      last_error = case
        when p_error ~ '^[A-Z0-9_]{1,64}$' then p_error else 'SEND_FAILED' end
  where report_id = p_report and sent_at is null
  returning attempts into v_attempts;
  return v_attempts is not null;
end;
$$;

-- Unsent alerts and the oldest one's age. Counts only.
create or replace function private.ai_output_alerts_backlog()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'unsent', count(*),
    'oldestSeconds', coalesce(
      extract(epoch from now() - min(a.created_at))::bigint, 0)
  )
  from private.ai_output_report_alerts a
  where a.sent_at is null;
$$;

-- ---------------------------------------------------------------------------
-- Retention and deletion.
-- ---------------------------------------------------------------------------

-- Reports are kept 180 days, then removed with their alerts. Bounded; the
-- worker's retention schedule calls it once an hour.
create or replace function private.ai_output_reports_purge(p_limit integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_reports int;
begin
  if p_limit is null or p_limit not between 1 and 50000 then
    raise exception 'AI_OUTPUT_REPORTS_INVALID_PURGE';
  end if;
  delete from private.ai_output_reports
  where id in (
    select r.id from private.ai_output_reports r
    where r.created_at < now() - interval '180 days'
    order by r.created_at
    limit p_limit
  );
  get diagnostics v_reports = row_count;
  return jsonb_build_object('ai_output_reports', v_reports);
end;
$$;

-- A deleted account takes its reports with it. Accounts are de-identified
-- rather than removed (DL-051), so the foreign key's cascade alone is not
-- enough.
create or replace function private.ai_output_reports_forget_deleted_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'deleted' and old.status is distinct from 'deleted' then
    delete from private.ai_output_reports where reporter_id = new.id;
  end if;
  return new;
end;
$$;
drop trigger if exists dl076_ai_output_reports_forget_deleted_profile on public.profiles;
create trigger dl076_ai_output_reports_forget_deleted_profile
after update of status on public.profiles
for each row execute function private.ai_output_reports_forget_deleted_profile();

-- The export gains one section: re-issued whole from 202610210060 with
-- only "aiOutputReports" added at the end.
create or replace function private.data_export_document(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'format', 'studafy-export/v2',
    'generatedAt', now(),
    'sections', jsonb_build_object(
      'about', jsonb_build_object(
        'scope', 'This account''s own data. A child account a parent manages has its own export: open the child''s account and choose Download my data.',
        'files', 'Files are listed by name, type, size and date; their contents are not in this document. Open them in the app, or write to hello@studafy.com for a copy.',
        'voiceNotes', 'Voice notes are message attachments with kind "voiceNote".',
        'onlineAssessments', 'Your own answers are always included. The questions, marks and feedback are included once your teacher releases the answers, as in the app.',
        'gradeHistory', 'Each mark as it was published, and every correction or withdrawal since, with the reason given.',
        'limits', 'messagesSent, messagesReceived, filesUploaded and aiUsage hold the newest 5,000 entries each. Write to hello@studafy.com for the rest.',
        'notIncluded', 'Study helper chats are kept only on your device. Wellbeing notes are the school''s records: write to hello@studafy.com and we will pass your request to the school.'),
      'profile', (
        select jsonb_build_object(
          'id', p.id, 'displayName', p.display_name, 'locale', p.locale,
          'status', p.status, 'createdAt', p.created_at,
          'gender', p.gender, 'studafyId', p.public_id,
          'email', (select u.email from auth.users u where u.id = p.id),
          'managedBy', (
            select g.display_name from private.managed_accounts m
            join public.profiles g on g.id = m.guardian_id
            where m.child_id = p.id)
        ) from public.profiles p where p.id = p_user),
      'managedChildAccounts', coalesce((
        select jsonb_agg(jsonb_build_object(
          'displayName', c.display_name, 'studafyId', c.public_id,
          'managedSince', m.created_at
        ) order by m.created_at)
        from private.managed_accounts m
        join public.profiles c on c.id = m.child_id
        where m.guardian_id = p_user and c.deleted_at is null), '[]'::jsonb),
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
              'assessment', a.title, 'mark', g.mark, 'score', g.score,
              'maximumScore', a.maximum_score, 'feedback', g.feedback,
              'publishedAt', g.published_at,
              'returnedFiles', private.data_export_files(p_grade_result => g.id)
            ) order by g.published_at)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            where g.student_id = st.id and g.state = 'published'), '[]'::jsonb),
          -- From publication on: what the student was shown, then each
          -- change to it. A draft before publication was never theirs to see.
          'gradeHistory', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assessment', a.title, 'change', e.event_type,
              'previousMark', case when e.event_type <> 'published' then e.previous_mark end,
              'previousScore', case when e.event_type <> 'published' then e.previous_score end,
              'previousFeedback', case when e.event_type <> 'published' then e.previous_feedback end,
              'mark', e.next_mark, 'score', e.next_score, 'feedback', e.next_feedback,
              'reason', case when e.event_type <> 'published' then e.reason end,
              'at', e.created_at
            ) order by e.created_at, e.id)
            from public.grade_results g
            join public.assessments a on a.id = g.assessment_id
            join public.grade_result_events e on e.grade_result_id = g.id
            where g.student_id = st.id
              and e.event_type in ('published', 'corrected', 'withdrawn')), '[]'::jsonb),
          'attendance', coalesce((
            select jsonb_agg(jsonb_build_object(
              'lesson', ls.title, 'lessonStartsAt', ls.starts_at,
              'state', ar.state, 'reason', ar.reason, 'recordedAt', ar.recorded_at
            ) order by ar.recorded_at)
            from public.attendance_records ar
            left join public.lesson_sessions ls on ls.id = ar.session_id
            where ar.student_id = st.id), '[]'::jsonb),
          'attendanceHistory', coalesce((
            select jsonb_agg(jsonb_build_object(
              'lesson', ls.title, 'lessonStartsAt', ls.starts_at,
              'previousState', r.previous_state, 'previousReason', r.previous_reason,
              'state', r.next_state, 'reason', r.next_reason,
              'changeReason', r.reason, 'at', r.created_at
            ) order by r.created_at, r.id)
            from public.attendance_record_revisions r
            left join public.lesson_sessions ls on ls.id = r.session_id
            where r.student_id = st.id), '[]'::jsonb),
          'submissions', coalesce((
            select jsonb_agg(jsonb_build_object(
              'assignment', asg.title, 'status', sb.status,
              'submittedAt', sb.submitted_at, 'excused', sb.excused,
              'attempts', coalesce((
                select jsonb_agg(jsonb_build_object(
                  'submittedAt', sa.submitted_at,
                  'text', nullif(sa.answer_text, ''),
                  'current', sa.id is not distinct from sb.current_attempt_id,
                  'handedInByParent', sa.submitted_by_guardian_id is not null,
                  'files', private.data_export_files(p_submission_attempt => sa.id)
                ) order by sa.created_at, sa.id)
                from public.submission_attempts sa
                where sa.submission_id = sb.id), '[]'::jsonb)
            ) order by sb.created_at)
            from public.submissions sb
            join public.assignments asg on asg.id = sb.assignment_id
            where sb.student_id = st.id), '[]'::jsonb),
          'onlineAssessments', coalesce((
            select jsonb_agg(jsonb_build_object(
                'assessment', a.title, 'attemptNumber', t.attempt_number,
                'submittedAt', t.submitted_at, 'answersReleased', rel.released,
                'answers', (
                  select coalesce(jsonb_agg(jsonb_build_object(
                      'questionNumber', q.position,
                      'answerText', nullif(aa.answer_text, ''),
                      'selectedOptionIds', case when jsonb_typeof(aa.selected) = 'array' then aa.selected end,
                      'choice', case when jsonb_typeof(aa.selected) = 'boolean' then aa.selected end)
                    || case when rel.released then jsonb_build_object(
                      'question', q.prompt,
                      'selectedOptions', case when jsonb_typeof(aa.selected) = 'array' then (
                        select coalesce(jsonb_agg(o->>'text' order by ord), '[]'::jsonb)
                        from jsonb_array_elements(q.options) with ordinality x(o, ord)
                        where aa.selected ? (o->>'id')) end,
                      'autoScore', aa.auto_score, 'awardedScore', aa.awarded_score,
                      'maximumScore', q.maximum_score, 'feedback', aa.feedback)
                      else '{}'::jsonb end
                    order by q.position), '[]'::jsonb)
                  from public.assessment_answers aa
                  join public.assessment_questions q on q.id = aa.question_id
                  where aa.attempt_id = t.id))
              || case when rel.released then jsonb_build_object(
                'awardedScore', t.awarded_score, 'feedback', t.feedback)
                else '{}'::jsonb end
              order by t.submitted_at, t.id)
            from public.assessment_attempts t
            join public.assessments a on a.id = t.assessment_id
            cross join lateral (
              select private.assessment_answers_released(a.id) as released) rel
            where t.student_id = st.id), '[]'::jsonb)
        ))
        from public.students st join public.schools s on s.id = st.school_id
        where st.user_id = p_user and st.deleted_at is null), '[]'::jsonb),
      'notebookEntries', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', n.title, 'body', n.body, 'source', n.source,
          'createdAt', n.created_at, 'updatedAt', n.updated_at
        ) order by n.created_at)
        from public.notebook_entries n
        where n.owner_id = p_user and n.deleted_at is null), '[]'::jsonb),
      'studyNotebooks', coalesce((
        select jsonb_agg(jsonb_build_object(
          'title', sn.title, 'subtitle', sn.subtitle, 'status', sn.status,
          'content', sn.content, 'personal', sn.personal,
          'createdAt', sn.created_at, 'updatedAt', sn.updated_at
        ) order by sn.created_at)
        from public.study_notebooks sn
        where sn.owner_id = p_user and sn.deleted_at is null), '[]'::jsonb),
      'devices', coalesce((
        select jsonb_agg(d.device order by d.seen desc)
        from (
          select jsonb_build_object(
              'kind', 'signIn', 'platform', ad.platform, 'appVersion', ad.app_version,
              'label', ad.display_label, 'firstSeenAt', ad.first_seen_at,
              'lastSeenAt', ad.last_seen_at, 'revokedAt', ad.revoked_at
            ) as device, ad.last_seen_at as seen
          from public.auth_devices ad where ad.user_id = p_user
          union all
          select jsonb_build_object(
              'kind', 'notifications', 'platform', pd.platform,
              'registeredAt', pd.created_at, 'lastSeenAt', pd.last_seen_at,
              'revokedAt', pd.revoked_at
            ), pd.last_seen_at
          from public.push_devices pd where pd.user_id = p_user
        ) d), '[]'::jsonb),
      'conversations', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', c.id, 'subject', c.subject,
          'joinedAt', cp.joined_at, 'leftAt', cp.left_at
        ) order by cp.joined_at, c.id)
        from public.conversation_participants cp
        join public.conversations c on c.id = cp.conversation_id
        where cp.user_id = p_user), '[]'::jsonb),
      'messagesSent', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'body', m.body, 'sentAt', m.created_at,
          'editedAt', m.edited_at,
          'attachments', private.data_export_files(p_message => m.id)
        ) order by m.created_at)
        from (
          select * from public.messages
          where sender_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) m), '[]'::jsonb),
      -- What the app shows the person: the conversations they are still in.
      'messagesReceived', coalesce((
        select jsonb_agg(jsonb_build_object(
          'conversationId', m.conversation_id, 'from', p.display_name,
          'body', m.body, 'sentAt', m.created_at, 'editedAt', m.edited_at,
          'attachments', private.data_export_files(p_message => m.id)
        ) order by m.created_at)
        from (
          select x.* from public.conversation_participants cp
          join public.messages x on x.conversation_id = cp.conversation_id
          where cp.user_id = p_user and cp.left_at is null
            and x.sender_id is distinct from p_user and x.deleted_at is null
          order by x.created_at desc limit 5000
        ) m
        left join public.profiles p on p.id = m.sender_id), '[]'::jsonb),
      'filesUploaded', coalesce((
        select jsonb_agg(private.data_export_file_json(f)
            || jsonb_build_object('purpose', f.purpose, 'scanState', f.scan_state)
          order by f.created_at)
        from (
          select * from public.file_objects
          where owner_id = p_user and deleted_at is null
          order by created_at desc limit 5000
        ) f), '[]'::jsonb),
      'aiUsage', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', u.feature, 'plan', u.plan, 'status', u.status,
          'inputTokens', u.input_tokens, 'outputTokens', u.output_tokens,
          'countedTokens', u.metered_tokens, 'model', u.model,
          'at', u.created_at
        ) order by u.created_at)
        from (
          select * from private.ai_usage
          where user_id = p_user
          order by created_at desc limit 5000
        ) u), '[]'::jsonb),
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
        where d.recipient_id = p_user), '[]'::jsonb),
      -- ADR-0046: a student's choice about suggested marks, and a teacher's
      -- Studafy AI Marking usage. Suggestions are drafts for the teacher and
      -- not included; marks are in grades.
      'aiMarking', jsonb_build_object(
        'about', 'A student''s choice about AI-suggested marks, and a teacher''s Studafy AI Marking usage. Suggestions are drafts for the teacher and are not included; your marks are in grades.',
        'optedOut', exists (select 1 from private.marking_opt_outs o where o.user_id = p_user),
        'usage', coalesce((
          select jsonb_agg(jsonb_build_object(
            'state', u.state, 'tokens', u.tokens, 'model', u.model, 'at', u.created_at)
            order by u.created_at)
          from (select * from private.marking_usage where user_id = p_user
                order by created_at desc limit 5000) u), '[]'::jsonb)),
      -- DL-076: AI answers the person reported, with what they wrote.
      'aiOutputReports', coalesce((
        select jsonb_agg(jsonb_build_object(
          'feature', r.feature, 'reason', r.reason, 'details', r.details,
          'excerpt', r.excerpt, 'status', r.status, 'filedAt', r.created_at
        ) order by r.created_at)
        from private.ai_output_reports r where r.reporter_id = p_user), '[]'::jsonb)
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- Grants: everything is owned by postgres and closed; the API files a report
-- and the worker runs the alert queue and the purge.
-- ---------------------------------------------------------------------------
do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.ai_output_report_file(jsonb, uuid, bigint)',
    'private.ai_output_alerts_enqueue()',
    'private.ai_output_alerts_claim(integer, integer)',
    'private.ai_output_alerts_finish(uuid, boolean, text)',
    'private.ai_output_alerts_backlog()',
    'private.ai_output_reports_purge(integer)',
    'private.ai_output_reports_forget_deleted_profile()',
    'private.data_export_document(uuid)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.ai_output_report_file(jsonb, uuid, bigint)
  to studafy_api_runtime;
grant execute on function private.ai_output_alerts_claim(integer, integer),
  private.ai_output_alerts_finish(uuid, boolean, text),
  private.ai_output_alerts_backlog(),
  private.ai_output_reports_purge(integer)
  to studafy_worker_runtime;
