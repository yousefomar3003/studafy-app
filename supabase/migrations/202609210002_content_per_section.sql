-- Content is filed against the section it was taught in (TEACH-055).
--
-- Two things the school asked for, and one it did not:
--
--   * resource_publications gains lesson_session_id, so content belongs to a
--     meeting of a class rather than only to the class;
--   * closeLessonSession refuses a section with nothing filed against it,
--     which is the "must upload the content of the section taken" rule;
--   * attendance is deliberately NOT gated on it. A teacher standing in
--     front of a class has to be able to mark a register whatever else is
--     outstanding, so the block lands at the end of the lesson, not the
--     start.
--
-- Forward-only: the command surface is replaced in full because INFRA-081
-- forbids editing a shipped migration.

alter table public.resource_publications
  add column if not exists lesson_session_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.resource_publications'::regclass
      and conname = 'resource_publications_lesson_session_fk'
  ) then
    alter table public.resource_publications
      add constraint resource_publications_lesson_session_fk
      foreign key (lesson_session_id)
      references public.lesson_sessions(id) on delete set null;
  end if;
end $$;

create index if not exists resource_publications_lesson_session
  on public.resource_publications (lesson_session_id)
  where lesson_session_id is not null;

CREATE OR REPLACE FUNCTION private.api041_command(p_operation text, p_resource_id uuid, p_input jsonb, p_idempotency_id uuid, p_idempotency_generation bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  tenant uuid := nullif(current_setting('studafy.school_id',true),'')::uuid;
  request_id text := nullif(current_setting('studafy.request_id',true),'');
  body jsonb := coalesce(p_input->'body','{}'::jsonb);
  response jsonb; before_value jsonb; after_value jsonb;
  entity_id uuid; entity_type text; audit_action text;
  class_id uuid; school_id uuid; term_id uuid; v_student_id uuid;
  version_value bigint; state_value text; idem_key text;
  new_id uuid; version_id uuid; publication_id uuid; v_submission_id uuid;
  attempt_id uuid; v_draft_id uuid; v_question_id uuid; grade_id uuid; v_session_id uuid;
  score_value numeric; max_score numeric; expected_count int; supplied_count int;
  slot jsonb; entry jsonb; answer jsonb; item jsonb;
  v_lesson_session uuid;
  v_filed_at timestamptz;
  outbox_template text; outbox_entity uuid; completed boolean;
  response_status int := coalesce((p_input->>'responseStatus')::int,200);
begin
  if auth.uid() is null or tenant is null or request_id is null then
    return jsonb_build_object('outcome','forbidden');
  end if;
  select r.idempotency_key into idem_key from public.idempotency_records r
  where r.id=p_idempotency_id and r.actor_id=auth.uid() and r.school_id=tenant
    and r.generation=p_idempotency_generation and r.status='reserved'
  for update;
  if idem_key is null then return jsonb_build_object('outcome','forbidden'); end if;
  if not private.has_active_membership(tenant) then return jsonb_build_object('outcome','forbidden'); end if;

  case p_operation
    when 'createClassroom' then
      school_id := (body->>'schoolId')::uuid;
      -- Teachers create their own classes. Studafy has no school
      -- administrator in practice: a teacher signs in, creates the class,
      -- then invites students to it. Limiting creation to is_school_admin
      -- left the teacher UI offering an action the surface always refused,
      -- and an AUTH-031 resource denial is concealed as 404, so a teacher
      -- creating their first class was told the record no longer exists.
      if school_id<>tenant
         or not private.has_active_membership(
              tenant, array['teacher','school_admin']::public.app_role[]) then
        return jsonb_build_object('outcome','forbidden');
      end if;
      select t.id into term_id from public.terms t where t.school_id=tenant and t.status in ('active','planned')
        order by (t.status='active') desc,t.starts_on limit 1;
      if term_id is null then return jsonb_build_object('outcome','invalid_state'); end if;
      insert into public.classrooms(school_id,term_id,name,grade,section,room,teacher_id,status,version)
      values(tenant,term_id,body->>'name',body->>'grade',body->>'section',body->>'room',auth.uid(),'active',1)
      returning id into entity_id;
      insert into public.classroom_staff(school_id,classroom_id,membership_id,user_id,role,status)
      select tenant,entity_id,m.id,auth.uid(),'lead_teacher','active' from public.memberships m
      where m.school_id=tenant and m.user_id=auth.uid() and m.active and m.status='active'
        and m.role in ('teacher','school_admin')
      -- The lead teacher must be recorded against the teaching membership.
      -- Nothing constrains classroom_staff.membership_id to a teaching role,
      -- so an account that is also a parent or student at the same school
      -- could otherwise be filed under whichever membership was created first.
      order by (m.role='teacher') desc, m.created_at limit 1;
      for slot in select value from jsonb_array_elements(coalesce(body->'schedule','[]')) loop
        insert into public.class_schedules(school_id,classroom_id,weekday,starts_at,ends_at,effective_from,effective_until)
        values(tenant,entity_id,(slot->>'weekday')::smallint,(slot->>'startsAt')::time,(slot->>'endsAt')::time,
          (slot->>'effectiveFrom')::date,nullif(slot->>'effectiveUntil','')::date);
      end loop;
      response:=private.api041_classroom_json(entity_id); entity_type:='classroom'; audit_action:='classroom_created';

    when 'updateClassroom' then
      select c.school_id,c.version,to_jsonb(c) into school_id,version_value,before_value from public.classrooms c where c.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(p_resource_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      update public.classrooms set name=body->>'name',grade=body->>'grade',section=body->>'section',room=body->>'room',
        version=version+1,updated_at=now() where id=p_resource_id;
      entity_id:=p_resource_id; response:=private.api041_classroom_json(entity_id); entity_type:='classroom'; audit_action:='classroom_updated';

    when 'replaceClassroomSchedule' then
      select c.school_id,c.version into school_id,version_value from public.classrooms c where c.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(p_resource_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      delete from public.class_schedules where classroom_id=p_resource_id;
      for slot in select value from jsonb_array_elements(coalesce(body->'schedule','[]')) loop
        insert into public.class_schedules(school_id,classroom_id,weekday,starts_at,ends_at,effective_from,effective_until)
        values(tenant,p_resource_id,(slot->>'weekday')::smallint,(slot->>'startsAt')::time,(slot->>'endsAt')::time,
          (slot->>'effectiveFrom')::date,nullif(slot->>'effectiveUntil','')::date);
      end loop;
      update public.classrooms set version=version+1,updated_at=now() where id=p_resource_id;
      entity_id:=p_resource_id; entity_type:='classroom'; audit_action:='classroom_schedule_replaced';
      response:=jsonb_build_object('classroom',private.api041_classroom_json(entity_id),'schedule',coalesce((
        select jsonb_agg(jsonb_build_object('id',cs.id,'weekday',cs.weekday,'startsAt',cs.starts_at,'endsAt',cs.ends_at,
          'effectiveFrom',cs.effective_from,'effectiveUntil',cs.effective_until) order by cs.weekday,cs.starts_at)
        from public.class_schedules cs where cs.classroom_id=entity_id),'[]'::jsonb));

    when 'createResource' then
      school_id:=(body->>'schoolId')::uuid; class_id:=nullif(body->>'classroomId','')::uuid;
      if school_id<>tenant or (class_id is not null and not private.api041_class_writer(class_id)) or
        (class_id is null and not private.is_school_admin(tenant)) then
        return jsonb_build_object('outcome','forbidden');
      end if;
      if class_id is not null and not exists(select 1 from public.classrooms c where c.id=class_id and c.school_id=tenant) then
        return jsonb_build_object('outcome','not_found');
      end if;
      insert into public.resources(school_id,title,resource_type,state,current_version,created_by)
      values(tenant,body->>'title',body->>'resourceType','draft',1,auth.uid()) returning id into entity_id;
      insert into public.resource_versions(school_id,resource_id,version,body,created_by)
      values(tenant,entity_id,1,body->>'body',auth.uid()) returning id into version_id;
      -- Content may name the meeting it was taught in. That link is what
      -- closeLessonSession checks, so a section cannot be closed with nothing
      -- filed against it.
      v_lesson_session := nullif(body->>'lessonSessionId','')::uuid;
      if v_lesson_session is not null and not exists(
        select 1 from public.lesson_sessions ls
        where ls.id=v_lesson_session and ls.classroom_id=class_id
      ) then
        return jsonb_build_object('outcome','not_found');
      end if;
      insert into public.resource_publications(school_id,resource_version_id,classroom_id,lesson_session_id,audience,state,created_by,version)
      values(tenant,version_id,class_id,v_lesson_session,(body->>'audience')::public.meeting_audience,'draft',auth.uid(),1);
      response:=private.api041_resource_json(entity_id); entity_type:='resource'; audit_action:='resource_created';

    when 'closeLessonSession' then
      -- The rule the school asked for: a section is not finished until the
      -- content taught in it has been filed. Attendance is deliberately not
      -- gated on this - a teacher must always be able to mark a register in
      -- front of the class - so the block lands here, at the end.
      select ls.classroom_id,ls.version,ls.filed_at into class_id,version_value,v_filed_at
      from public.lesson_sessions ls where ls.id=p_resource_id for update;
      if class_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if v_filed_at is not null then return jsonb_build_object('outcome','invalid_state'); end if;
      if not exists(
        select 1 from public.resource_publications rp
        where rp.lesson_session_id=p_resource_id and rp.school_id=tenant
      ) then
        -- Nothing was filed for this meeting, so there is nothing to close.
        return jsonb_build_object('outcome','window_closed');
      end if;
      update public.lesson_sessions
      set filed_at=now(),status='completed',version=version+1,updated_at=now()
      where id=p_resource_id;
      entity_id:=p_resource_id; entity_type:='lesson_session';
      audit_action:='lesson_session_closed';
      response:=jsonb_build_object('id',p_resource_id,'filedAt',now());

    when 'reviseResource' then
      select r.school_id,r.version,to_jsonb(r) into school_id,version_value,before_value from public.resources r where r.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      select rp.classroom_id into class_id from public.resource_publications rp join public.resource_versions rv on rv.id=rp.resource_version_id
        where rv.resource_id=p_resource_id order by rp.created_at desc limit 1;
      if school_id<>tenant or not (private.is_school_admin(tenant) or
        (select r.created_by=auth.uid() from public.resources r where r.id=p_resource_id) or
        (class_id is not null and private.api041_class_writer(class_id))) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      update public.resources set title=body->>'title',current_version=current_version+1,version=version+1,state='draft',updated_at=now() where id=p_resource_id returning current_version into version_value;
      insert into public.resource_versions(school_id,resource_id,version,body,created_by)
      values(tenant,p_resource_id,version_value,body->>'body',auth.uid()) returning id into version_id;
      insert into public.resource_publications(school_id,resource_version_id,classroom_id,audience,state,created_by,version)
      select tenant,version_id,class_id,rp.audience,'draft',auth.uid(),1 from public.resource_publications rp
        join public.resource_versions rv on rv.id=rp.resource_version_id where rv.resource_id=p_resource_id order by rp.created_at desc limit 1;
      entity_id:=p_resource_id; response:=private.api041_resource_json(entity_id); entity_type:='resource'; audit_action:='resource_revised';

    when 'publishResource','withdrawResource' then
      select r.school_id,r.version,r.state::text into school_id,version_value,state_value from public.resources r where r.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      select rp.classroom_id,rp.id into class_id,publication_id from public.resource_publications rp join public.resource_versions rv on rv.id=rp.resource_version_id
        join public.resources r on r.id=rv.resource_id and r.current_version=rv.version
        where rv.resource_id=p_resource_id order by rp.created_at desc limit 1;
      if school_id<>tenant or not (private.is_school_admin(tenant) or class_id is not null and private.api041_class_writer(class_id)) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      if (p_operation='publishResource' and state_value<>'draft') or (p_operation='withdrawResource' and state_value<>'published') then return jsonb_build_object('outcome','invalid_state'); end if;
      update public.resources set state=(case when p_operation='publishResource' then 'published' else 'withdrawn' end)::public.resource_state,
        version=version+1,updated_at=now() where id=p_resource_id;
      update public.resource_publications set state=(case when p_operation='publishResource' then 'published' else 'withdrawn' end)::public.resource_state,
        published_at=case when p_operation='publishResource' then now() else published_at end,
        withdrawn_at=case when p_operation='withdrawResource' then now() else null end,version=version+1,updated_at=now()
        where id=publication_id;
      entity_id:=p_resource_id; response:=private.api041_resource_json(entity_id); entity_type:='resource';
      audit_action:=case when p_operation='publishResource' then 'resource_published' else 'resource_withdrawn' end;
      if p_operation='publishResource' then outbox_template:='academic.resource_published'; outbox_entity:=entity_id; end if;

    when 'createAssignment' then
      class_id:=(body->>'classroomId')::uuid;
      select c.school_id into school_id from public.classrooms c where c.id=class_id;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if (body->>'closesAt') is not null and (body->>'closesAt')::timestamptz < (body->>'dueAt')::timestamptz then return jsonb_build_object('outcome','invalid'); end if;
      insert into public.assignments(school_id,classroom_id,title,instructions,due_at,closes_at,state,version,created_by)
      values(tenant,class_id,body->>'title',body->>'instructions',(body->>'dueAt')::timestamptz,nullif(body->>'closesAt','')::timestamptz,'draft',1,auth.uid()) returning id into entity_id;
      response:=private.api041_assignment_json(entity_id); entity_type:='assignment'; audit_action:='assignment_created';

    when 'publishAssignment','withdrawAssignment' then
      select a.school_id,a.classroom_id,a.version,a.state::text into school_id,class_id,version_value,state_value from public.assignments a where a.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      if (p_operation='publishAssignment' and state_value<>'draft') or (p_operation='withdrawAssignment' and state_value<>'published') then return jsonb_build_object('outcome','invalid_state'); end if;
      update public.assignments set state=(case when p_operation='publishAssignment' then 'published' else 'withdrawn' end)::public.publication_state,
        version=version+1,published_at=case when p_operation='publishAssignment' then now() else published_at end,updated_at=now() where id=p_resource_id;
      entity_id:=p_resource_id; response:=private.api041_assignment_json(entity_id); entity_type:='assignment';
      audit_action:=case when p_operation='publishAssignment' then 'assignment_published' else 'assignment_withdrawn' end;
      if p_operation='publishAssignment' then outbox_template:='academic.assignment_published'; outbox_entity:=entity_id; end if;

    when 'submitAssignment' then
      select a.school_id,a.classroom_id,a.state::text into school_id,class_id,state_value from public.assignments a where a.id=p_resource_id and a.deleted_at is null for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      select st.id into v_student_id from public.students st join public.enrollments e on e.student_id=st.id
        where st.user_id=auth.uid() and e.classroom_id=class_id and e.active and e.status='active';
      if school_id<>tenant or v_student_id is null then return jsonb_build_object('outcome','forbidden'); end if;
      if state_value<>'published' then return jsonb_build_object('outcome','invalid_state'); end if;
      if exists(select 1 from public.assignments a where a.id=p_resource_id and now()>coalesce(a.closes_at,a.due_at)) then return jsonb_build_object('outcome','window_closed'); end if;
      insert into public.submissions(school_id,assignment_id,student_id,submitted_at,excused,status,version)
      values(tenant,p_resource_id,v_student_id,now(),false,'submitted',1)
      on conflict(assignment_id,student_id) do update set submitted_at=now(),status='submitted',version=public.submissions.version+1,updated_at=now()
      returning id into v_submission_id;
      insert into public.submission_attempts(school_id,submission_id,operation_id,answer_text,submitted_at)
      values(tenant,v_submission_id,p_idempotency_id,body->>'answerText',now()) returning id into attempt_id;
      update public.submissions set current_attempt_id=attempt_id where id=v_submission_id;
      select jsonb_build_object('id',s.id,'assignmentId',s.assignment_id,'studentId',s.student_id,'status',s.status,
        'version',s.version,'answerText',sa.answer_text,'submittedAt',s.submitted_at) into response
      from public.submissions s join public.submission_attempts sa on sa.id=s.current_attempt_id where s.id=v_submission_id;
      entity_id:=v_submission_id; entity_type:='submission'; audit_action:='assignment_submitted';

    when 'createAssessment' then
      class_id:=(body->>'classroomId')::uuid;
      select c.school_id into school_id from public.classrooms c where c.id=class_id;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      select count(*),count(distinct (x->>'position')::int),coalesce(sum((x->>'maximumScore')::numeric),0)
        into supplied_count,expected_count,score_value from jsonb_array_elements(coalesce(body->'questions','[]')) x;
      if supplied_count<>expected_count or (supplied_count>0 and score_value<>(body->>'maximumScore')::numeric) then return jsonb_build_object('outcome','invalid'); end if;
      insert into public.assessments(school_id,classroom_id,title,category,maximum_score,scheduled_at,state,delivery,version,created_by)
      values(tenant,class_id,body->>'title',body->>'category',(body->>'maximumScore')::numeric,nullif(body->>'scheduledAt','')::timestamptz,
        'draft',body->>'delivery',1,auth.uid()) returning id into entity_id;
      for item in select value from jsonb_array_elements(coalesce(body->'questions','[]')) loop
        insert into public.assessment_questions(school_id,assessment_id,position,prompt,preferred_answer,maximum_score)
        values(tenant,entity_id,(item->>'position')::int,item->>'prompt',item->>'preferredAnswer',(item->>'maximumScore')::numeric);
      end loop;
      response:=private.api041_assessment_json(entity_id); entity_type:='assessment'; audit_action:='assessment_created';

    when 'publishAssessment','withdrawAssessment' then
      select a.school_id,a.classroom_id,a.version,a.state::text into school_id,class_id,version_value,state_value from public.assessments a where a.id=p_resource_id for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      if (p_operation='publishAssessment' and state_value<>'draft') or (p_operation='withdrawAssessment' and state_value<>'published') then return jsonb_build_object('outcome','invalid_state'); end if;
      update public.assessments set state=(case when p_operation='publishAssessment' then 'published' else 'withdrawn' end)::public.publication_state,
        version=version+1,published_at=case when p_operation='publishAssessment' then now() else published_at end,updated_at=now() where id=p_resource_id;
      if p_operation='publishAssessment' then
        insert into public.grade_results(school_id,assessment_id,student_id,score,state,version)
        select tenant,p_resource_id,e.student_id,null,'draft',1 from public.enrollments e
        where e.classroom_id=class_id and e.active and e.status='active' on conflict(assessment_id,student_id) do nothing;
        outbox_template:='academic.assessment_published'; outbox_entity:=p_resource_id;
      end if;
      entity_id:=p_resource_id; response:=private.api041_assessment_json(entity_id); entity_type:='assessment';
      audit_action:=case when p_operation='publishAssessment' then 'assessment_published' else 'assessment_withdrawn' end;

    when 'submitAssessment' then
      select a.school_id,a.classroom_id,a.state::text into school_id,class_id,state_value from public.assessments a where a.id=p_resource_id and a.delivery in ('online','practice') for update;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      select st.id into v_student_id from public.students st join public.enrollments e on e.student_id=st.id
        where st.user_id=auth.uid() and e.classroom_id=class_id and e.active and e.status='active';
      if school_id<>tenant or v_student_id is null then return jsonb_build_object('outcome','forbidden'); end if;
      if state_value<>'published' then return jsonb_build_object('outcome','invalid_state'); end if;
      select count(*) into expected_count from public.assessment_questions where assessment_id=p_resource_id;
      select count(*),count(distinct x->>'questionId') into supplied_count,version_value from jsonb_array_elements(body->'answers') x;
      if supplied_count<>expected_count or supplied_count<>version_value then return jsonb_build_object('outcome','invalid'); end if;
      if exists(select 1 from jsonb_array_elements(body->'answers') x where not exists(
        select 1 from public.assessment_questions q where q.assessment_id=p_resource_id and q.id=(x->>'questionId')::uuid)) then return jsonb_build_object('outcome','invalid'); end if;
      insert into public.assessment_attempts(school_id,assessment_id,student_id,operation_id)
      values(tenant,p_resource_id,v_student_id,p_idempotency_id) returning id into attempt_id;
      for answer in select value from jsonb_array_elements(body->'answers') loop
        insert into public.assessment_answers(school_id,attempt_id,question_id,answer_text)
        values(tenant,attempt_id,(answer->>'questionId')::uuid,answer->>'answerText');
      end loop;
      select jsonb_build_object('id',a.id,'assessmentId',a.assessment_id,'studentId',a.student_id,'submittedAt',a.submitted_at,'version',a.version)
        into response from public.assessment_attempts a where a.id=attempt_id;
      entity_id:=attempt_id; entity_type:='assessment_attempt'; audit_action:='assessment_submitted';

    when 'reviewGradeResult' then
      select g.school_id,a.classroom_id,g.version,g.state::text,a.maximum_score into school_id,class_id,version_value,state_value,max_score
      from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_resource_id for update of g;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      if state_value<>'draft' then return jsonb_build_object('outcome','invalid_state'); end if;
      score_value:=(body->>'score')::numeric;
      if score_value<0 or score_value>max_score then return jsonb_build_object('outcome','invalid'); end if;
      v_draft_id:=nullif(body->>'draftId','')::uuid;
      if v_draft_id is not null then
        if not exists(select 1 from public.ai_grading_drafts d where d.id=v_draft_id and d.grade_result_id=p_resource_id and d.school_id=tenant and d.status='ready') then return jsonb_build_object('outcome','invalid_state'); end if;
        select count(*) into expected_count from public.assessment_questions q join public.grade_results g on g.assessment_id=q.assessment_id where g.id=p_resource_id;
        select count(*),count(distinct x->>'questionId'),coalesce(sum((x->>'score')::numeric),0)
          into supplied_count,version_value,max_score from jsonb_array_elements(coalesce(body->'questionScores','[]')) x;
        if supplied_count<>expected_count or supplied_count<>version_value or max_score<>score_value then return jsonb_build_object('outcome','invalid'); end if;
        for item in select value from jsonb_array_elements(body->'questionScores') loop
          v_question_id:=(item->>'questionId')::uuid;
          select q.maximum_score into max_score from public.assessment_questions q join public.grade_results g on g.assessment_id=q.assessment_id
            where g.id=p_resource_id and q.id=v_question_id;
          if max_score is null or (item->>'score')::numeric<0 or (item->>'score')::numeric>max_score then return jsonb_build_object('outcome','invalid'); end if;
          if exists(select 1 from public.question_suggestions s where s.draft_id=v_draft_id and s.question_id=v_question_id
              and s.proposed_score<>(item->>'score')::numeric) and nullif(btrim(item->>'reason'),'') is null then return jsonb_build_object('outcome','invalid'); end if;
          update public.question_suggestions qs set teacher_score=(item->>'score')::numeric,
            override_reason=case when qs.proposed_score<>(item->>'score')::numeric then item->>'reason' else null end
            where qs.draft_id=v_draft_id and qs.question_id=v_question_id;
          if not found then return jsonb_build_object('outcome','invalid'); end if;
        end loop;
        update public.ai_grading_drafts set status='approved',version=version+1,updated_at=now() where id=v_draft_id;
      end if;
      update public.grade_results set score=score_value,feedback=body->>'feedback',state='reviewed',reviewed_by=auth.uid(),reviewed_at=now(),version=version+1,updated_at=now() where id=p_resource_id;
      entity_id:=p_resource_id; response:=private.api041_grade_json(entity_id); entity_type:='grade_result'; audit_action:='grade_reviewed';
      insert into public.grade_result_events(school_id,grade_result_id,actor_id,event_type,previous_state,next_state,idempotency_key)
      values(tenant,entity_id,auth.uid(),'reviewed','draft','reviewed',idem_key);

    when 'publishGradeResult','correctGradeResult','withdrawGradeResult' then
      select g.school_id,a.classroom_id,g.version,g.state::text,a.maximum_score into school_id,class_id,version_value,state_value,max_score
      from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_resource_id for update of g;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
      if (p_operation='publishGradeResult' and state_value<>'reviewed') or
         (p_operation='correctGradeResult' and state_value<>'published') or
         (p_operation='withdrawGradeResult' and state_value not in ('reviewed','published')) then return jsonb_build_object('outcome','invalid_state'); end if;
      if p_operation='correctGradeResult' then
        score_value:=(body->>'score')::numeric;
        if score_value<0 or score_value>max_score or nullif(btrim(body->>'reason'),'') is null then return jsonb_build_object('outcome','invalid'); end if;
        update public.grade_results set score=score_value,feedback=body->>'feedback',reviewed_by=auth.uid(),reviewed_at=now(),
          state='published',version=version+1,updated_at=now() where id=p_resource_id;
      elsif p_operation='publishGradeResult' then
        update public.grade_results set state='published',published_by=auth.uid(),published_at=now(),version=version+1,updated_at=now() where id=p_resource_id;
      else
        update public.grade_results set state='withdrawn',version=version+1,updated_at=now() where id=p_resource_id;
      end if;
      entity_id:=p_resource_id; response:=private.api041_grade_json(entity_id); entity_type:='grade_result';
      audit_action:=case p_operation when 'publishGradeResult' then 'grade_published' when 'correctGradeResult' then 'grade_corrected' else 'grade_withdrawn' end;
      insert into public.grade_result_events(school_id,grade_result_id,actor_id,event_type,previous_state,next_state,reason,idempotency_key)
      values(tenant,entity_id,auth.uid(),case p_operation when 'publishGradeResult' then 'published' when 'correctGradeResult' then 'corrected' else 'withdrawn' end,
        state_value::public.publication_state,(case when p_operation='withdrawGradeResult' then 'withdrawn' else 'published' end)::public.publication_state,
        case when p_operation='correctGradeResult' then body->>'reason' end,idem_key);
      if p_operation in ('publishGradeResult','correctGradeResult') then outbox_template:='academic.grade_published'; outbox_entity:=entity_id; end if;

    when 'recordAttendance' then
      class_id:=(body->>'classroomId')::uuid;
      select c.school_id into school_id from public.classrooms c where c.id=class_id;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if (body->>'endsAt')::timestamptz <= (body->>'startsAt')::timestamptz then return jsonb_build_object('outcome','invalid'); end if;
      select count(*),count(distinct x->>'studentId') into supplied_count,expected_count
      from jsonb_array_elements(body->'entries') x;
      if supplied_count<>expected_count then return jsonb_build_object('outcome','invalid'); end if;
      if not exists(select 1 from public.class_schedules cs join public.schools s on s.id=cs.school_id where cs.classroom_id=class_id
        and cs.weekday=extract(isodow from ((body->>'startsAt')::timestamptz at time zone s.timezone))
        and cs.starts_at=((body->>'startsAt')::timestamptz at time zone s.timezone)::time
        and ((body->>'startsAt')::timestamptz at time zone s.timezone)::date between cs.effective_from and coalesce(cs.effective_until,'infinity'::date))
        then return jsonb_build_object('outcome','invalid_state'); end if;
      select ls.id,ls.version into v_session_id,version_value from public.lesson_sessions ls
        where ls.classroom_id=class_id and ls.starts_at=(body->>'startsAt')::timestamptz for update;
      if v_session_id is null then
        if (body->>'expectedVersion')::bigint<>0 then return jsonb_build_object('outcome','version_conflict'); end if;
        insert into public.lesson_sessions(school_id,classroom_id,starts_at,ends_at,status,version)
        values(tenant,class_id,(body->>'startsAt')::timestamptz,(body->>'endsAt')::timestamptz,'completed',1)
        returning id,version into v_session_id,version_value;
      else
        if version_value<>(body->>'expectedVersion')::bigint then return jsonb_build_object('outcome','version_conflict'); end if;
        update public.lesson_sessions set ends_at=(body->>'endsAt')::timestamptz,status='completed',version=version+1,updated_at=now()
          where id=v_session_id returning version into version_value;
      end if;
      supplied_count:=0;
      for entry in select value from jsonb_array_elements(body->'entries') loop
        v_student_id:=(entry->>'studentId')::uuid;
        if not exists(select 1 from public.enrollments e where e.classroom_id=class_id and e.student_id=v_student_id and e.active and e.status='active') then return jsonb_build_object('outcome','invalid'); end if;
        insert into public.attendance_records(school_id,session_id,student_id,state,reason,recorded_by)
        values(tenant,v_session_id,v_student_id,(entry->>'state')::public.attendance_state,entry->>'reason',auth.uid())
        on conflict(session_id,student_id) do update set state=excluded.state,reason=excluded.reason,recorded_by=auth.uid(),recorded_at=now(),updated_at=now();
        supplied_count:=supplied_count+1;
      end loop;
      entity_id:=v_session_id; entity_type:='lesson_session'; audit_action:='attendance_recorded';
      response:=jsonb_build_object('sessionId',v_session_id,'version',version_value,'recorded',supplied_count);

    when 'createWellbeing' then
      class_id:=(body->>'classroomId')::uuid; v_student_id:=(body->>'studentId')::uuid;
      select c.school_id into school_id from public.classrooms c where c.id=class_id;
      if school_id is null then return jsonb_build_object('outcome','not_found'); end if;
      if school_id<>tenant or not private.api041_class_writer(class_id) then return jsonb_build_object('outcome','forbidden'); end if;
      if not exists(select 1 from public.enrollments e where e.classroom_id=class_id and e.student_id=v_student_id and e.active and e.status='active') then return jsonb_build_object('outcome','invalid'); end if;
      insert into public.wellbeing_events(school_id,student_id,classroom_id,kind,title,context,follow_up,created_by,visibility,severity,status)
      values(tenant,v_student_id,class_id,body->>'kind',body->>'title',body->>'context',body->>'followUp',auth.uid(),
        (body->>'visibility')::public.wellbeing_visibility,coalesce(body->>'severity','low'),'open') returning id into entity_id;
      select jsonb_build_object('id',w.id,'studentId',w.student_id,'classroomId',w.classroom_id,'kind',w.kind,'title',w.title,
        'context',w.context,'followUp',w.follow_up,'visibility',w.visibility,'severity',w.severity,'createdAt',w.created_at)
        into response from public.wellbeing_events w where w.id=entity_id;
      entity_type:='wellbeing_event'; audit_action:='wellbeing_created';
      if body->>'visibility' in ('guardian_shared','student_guardian_shared') then outbox_template:='academic.wellbeing_shared'; outbox_entity:=entity_id; end if;

    else return jsonb_build_object('outcome','invalid');
  end case;

  after_value:=jsonb_build_object('operation',p_operation,'version',response->'version','state',response->'state');
  insert into public.audit_events(school_id,actor_id,action,entity_type,entity_id,before_value,after_value,request_id)
  values(tenant,auth.uid(),audit_action,entity_type,entity_id,before_value,after_value,request_id);
  if outbox_template is not null then
    insert into public.notification_outbox(school_id,source_event_id,idempotency_key,channel,template_key,audience,payload)
    values(tenant,outbox_entity::text,idem_key,'in_app',outbox_template,
      jsonb_build_object('classroomId',class_id),jsonb_build_object('entityId',outbox_entity));
  end if;
  completed:=private.api_idempotency_complete(p_idempotency_id,p_idempotency_generation,response_status,response);
  if not completed then raise exception 'API041_IDEMPOTENCY_COMPLETION_FAILED'; end if;
  return jsonb_build_object('outcome','ok','response',response);
end;
$function$;

-- ---------------------------------------------------------------------------
-- AUTH-031 decision surface
-- ---------------------------------------------------------------------------
--
-- private.authz_authorize decides before any handler runs, and an action it
-- does not recognise is denied. Registering lesson_session.close here is what
-- makes the route reachable at all; without it the teacher would meet the
-- same concealed 404 that classroom.create produced.

create or replace function private.authz_authorize_pre_teach055(
  p_action text, p_resource_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare sid uuid; allowed boolean := false;
begin
  if p_action not in (
    'classJoinLink.create', 'classJoinLink.read', 'classJoinLink.revoke'
  ) then
    return private.authz_authorize_pre_join052(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  declare cls uuid;
  begin
    if p_action = 'classJoinLink.revoke' then
      select l.school_id, l.classroom_id into sid, cls
      from public.class_join_links l where l.id = p_resource_id;
    else
      select c.school_id, c.id into sid, cls
      from public.classrooms c where c.id = p_resource_id;
    end if;
    if cls is null then
      return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
    end if;
    allowed := private.is_class_staff(cls);
    return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
      'reason', case when allowed then 'allowed' else 'denied' end);
  end;
end;
$function$;

create or replace function private.authz_authorize(
  p_action text, p_resource_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare sid uuid; allowed boolean := false; cls uuid;
begin
  if p_action <> 'lesson_session.close' then
    return private.authz_authorize_pre_teach055(p_action, p_resource_id);
  end if;
  if auth.uid() is null or p_resource_id is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  -- Closing a section is a teaching act, bound to the classroom's own staff.
  select ls.school_id, ls.classroom_id into sid, cls
  from public.lesson_sessions ls where ls.id = p_resource_id;
  if cls is null then
    return jsonb_build_object('allowed', false, 'school_id', null, 'reason', 'invalid_resource');
  end if;
  allowed := private.is_class_staff(cls);
  return jsonb_build_object('allowed', coalesce(allowed, false), 'school_id', sid,
    'reason', case when allowed then 'allowed' else 'denied' end);
end;
$function$;
