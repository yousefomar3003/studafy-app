-- The data export covers what the account can see, and helper photos get a
-- retention period (DL-060; DPIA draft §12, D6 and D13).
--
-- 1. Export (privacy policy §11: access and portability). The document
--    becomes studafy-export/v2. It keeps every v1 section and adds:
--
--      * online exam answers: the student's own answers to every attempt,
--        always; the questions, marks and feedback only once the teacher has
--        released the answers (private.assessment_answers_released), which
--        is when the app shows them. Answer keys are never included;
--      * hand-in contents: every attempt's text, whether a parent handed it
--        in, and its files;
--      * files as a list (name, type, size, date, and "voiceNote" for a
--        voice note). The export is one JSON document, so the bytes are not
--        in it; sections.about says so and how to get them;
--      * attachments, voice notes included, on messages sent and received;
--      * messages received, in conversations the person is still in - which
--        is what the app shows them - with the sender's display name, and the
--        conversations they are or were in (subject, joined, left);
--      * mark history: each published mark as published, and every
--        correction or withdrawal since, with its reason. Drafts the student
--        never saw, and who made the change, are left out;
--      * attendance history: every change to an attendance mark, with its
--        reason, and the lesson each mark belongs to;
--      * marks returned with a published grade (file list), and the mark
--        kind (scored, absent, excused) beside the score;
--      * the AI usage ledger: feature, plan, tokens, model and date per
--        request, never the cost or the request key;
--      * every file the account owns (filesUploaded), helper photos and
--        notebook photos included;
--      * for a parent, the child accounts they manage (name, Studafy ID,
--        since when); for a child account, who manages it. A child's own
--        data is exported from the child's account, which the parent opens
--        (privacy policy §11; ADR-0031), as deletion also treats a child as
--        its own account.
--
--    Still the requester's data only. Nothing here shows another person's
--    data that the app does not already show the requester: a sender's
--    display name, a conversation's subject, a file's name on a message.
--    Wellbeing notes stay out: they are the school's safeguarding records,
--    which the app does not show students, and §11 sends such a request to
--    the school. Messages, files and AI usage hold the newest 5,000 entries
--    each, as messagesSent already did.
--
-- 2. Retention (privacy policy §10; DL-057). A photo sent with a study
--    helper question has been read by the model by the time the answer
--    arrives, and the chat keeps its own small copy on the device. It is
--    now due for deletion 30 days after upload: the schedule marks it, and
--    the FILE-051 sweep deletes the bytes as it does for every other file
--    (holds, dedupe groups and live references still apply). A person under
--    a legal hold keeps theirs. Runs with the other purges, behind
--    RETENTION_SCHEDULE_ENABLED. TODO(legal): counsel to confirm 30 days.
--
-- Forward-only (ADR-0030): one function is replaced with the same
-- signature, three are new; owners and grants are restated below.

-- ---------------------------------------------------------------------------
-- 1. Export helpers.
-- ---------------------------------------------------------------------------

-- What the export says about one file: never its location or hash.
create or replace function private.data_export_file_json(f public.file_objects)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'displayName', f.display_name,
    'kind', case
      when coalesce(f.detected_media_type, f.declared_media_type) = 'audio/mp4' then 'voiceNote'
      when f.purpose = 'assistant_attachment' then 'helperPhoto'
      else 'file' end,
    'mediaType', coalesce(f.detected_media_type, f.declared_media_type),
    'sizeBytes', f.size_bytes,
    'uploadedAt', f.created_at);
$$;

-- The files on one hand-in attempt, message or grade, as the app lists them:
-- attached and not deleted. Metadata only.
create or replace function private.data_export_files(
  p_submission_attempt uuid default null,
  p_message uuid default null,
  p_grade_result uuid default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(private.data_export_file_json(f) order by f.created_at, f.id), '[]'::jsonb)
  from public.file_bindings b
  join public.file_objects f on f.id = b.file_object_id
  where f.deleted_at is null and b.detached_at is null
    and (p_submission_attempt is not null and b.submission_attempt_id = p_submission_attempt
      or p_message is not null and b.message_id = p_message
      or p_grade_result is not null and b.grade_result_id = p_grade_result);
$$;

-- ---------------------------------------------------------------------------
-- 2. The document, v2.
-- ---------------------------------------------------------------------------

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
        where d.recipient_id = p_user), '[]'::jsonb)
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Helper photos: due for deletion 30 days after upload.
-- ---------------------------------------------------------------------------

create index if not exists retention_helper_photos_idx
  on public.file_objects (created_at)
  where purpose = 'assistant_attachment' and deleted_at is null;

create or replace function private.retention_expire_helper_photos(p_limit integer default 5000)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  lim integer := least(greatest(coalesce(p_limit, 5000), 1), 50000);
  n integer;
begin
  -- TODO(legal): 30 days is the owner's proposed default (DL-060).
  update public.file_objects f
    set retention_until = now()
    where f.id in (
      select x.id from public.file_objects x
      where x.purpose = 'assistant_attachment' and x.deleted_at is null
        and x.created_at <= now() - interval '30 days'
        and not x.legal_hold
        and (x.retention_until is null or x.retention_until > now())
        and not exists (
          select 1 from public.legal_holds h
          where h.subject_user_id = coalesce(x.owner_id, x.uploader_id)
            and h.status = 'active' and (h.expires_at is null or h.expires_at > now()))
      order by x.created_at
      limit lim);
  get diagnostics n = row_count;
  return jsonb_build_object('helper_photos', n);
end;
$$;

do $grants$
declare fn text;
begin
  foreach fn in array array[
    'private.data_export_files(uuid, uuid, uuid)',
    'private.data_export_file_json(public.file_objects)',
    'private.data_export_document(uuid)',
    'private.retention_expire_helper_photos(integer)'
  ] loop
    execute format('alter function %s owner to postgres', fn);
    execute format('revoke all on function %s from public, anon, authenticated, service_role, studafy_api_runtime, studafy_worker_runtime', fn);
  end loop;
end
$grants$;

grant execute on function private.retention_expire_helper_photos(integer) to studafy_worker_runtime;
