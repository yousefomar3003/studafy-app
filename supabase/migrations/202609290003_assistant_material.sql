-- The study helper reads class material and photos (2026-09-29).
--
-- A student can point the helper at a lesson or one of their own notes, so
-- it answers from them without the student pasting them in, and can send it
-- a photo. Both reach the AI provider, so the API only calls this behind the
-- lesson-tools switch (ADR-0029); photos are Studafy Plus, like whiteboard
-- notes.

-- A helper photo: an image, like a whiteboard photo.
insert into public.file_purpose_policies(
  purpose, policy_version, maximum_size_bytes, allowed_media_types)
values ('assistant_attachment', 'assistant-attachment-v1', 10485760,
  array['image/jpeg', 'image/png'])
on conflict (purpose) do update set
  policy_version = excluded.policy_version,
  maximum_size_bytes = excluded.maximum_size_bytes,
  allowed_media_types = excluded.allowed_media_types,
  enabled = true,
  updated_at = now();

-- It is bound to no class, assignment or student.
alter table public.upload_sessions
  drop constraint if exists file050_upload_target_check;
alter table public.upload_sessions
  add constraint file050_upload_target_check check (
    policy_version='legacy' or case purpose
      when 'profile_image' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'lesson_resource' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      when 'assignment_material' then num_nonnulls(classroom_id,assignment_id)=1 and num_nonnulls(student_id,grade_result_id)=0
      when 'assignment_submission' then assignment_id is not null and student_id is not null and num_nonnulls(classroom_id,grade_result_id)=0
      when 'paper_scan' then grade_result_id is not null and num_nonnulls(classroom_id,assignment_id,student_id)=0
      when 'coach_attachment' then student_id is not null and num_nonnulls(classroom_id,assignment_id,grade_result_id)=0
      when 'message_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'announcement_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      when 'notebook_photo' then classroom_id is not null and num_nonnulls(assignment_id,student_id,grade_result_id)=0
      when 'assistant_attachment' then num_nonnulls(classroom_id,assignment_id,student_id,grade_result_id)=0
      else false end
  ) not valid;
alter table public.upload_sessions validate constraint file050_upload_target_check;

-- Who may upload one. The outermost function, redefined with a branch for
-- the new purpose - no rename, no new link in the chain (ADR-0030).
CREATE OR REPLACE FUNCTION private.file050_authorize_target(p_body jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_class uuid;
begin
  -- A photo for the study helper belongs to no class: standing in the school
  -- is enough, which is what a profile photo asks (202609290003).
  if p_body->>'purpose' = 'assistant_attachment' then
    return private.file050_authorize_target_pre_notebook(
      jsonb_set(p_body, array['purpose'], '"profile_image"'::jsonb));
  end if;
  if p_body->>'purpose' <> 'notebook_photo' then
    return private.file050_authorize_target_pre_notebook(p_body);
  end if;
  -- A student photographs the board of a class they are in.
  v_class := nullif(p_body->>'classroomId', '')::uuid;
  if v_class is null or not exists (
    select 1 from public.students s
    join public.enrollments e on e.student_id = s.id
      and e.classroom_id = v_class and e.active and e.status = 'active'
    where s.user_id = auth.uid() and s.deleted_at is null
      and s.school_id = nullif(p_body->>'schoolId', '')::uuid
  ) then
    return jsonb_build_object('allowed', false);
  end if;
  -- Standing in the school is what a profile photo already asks, so the
  -- membership the session is owned through is resolved the same way.
  return private.file050_authorize_target_pre_notebook(
    jsonb_set(p_body - 'classroomId', array['purpose'], '"profile_image"'::jsonb));
exception when invalid_text_representation then
  return jsonb_build_object('allowed', false);
end;
$function$;

-- The notebooks surface, with the helper's two reads added. Copied from
-- 202609290001 otherwise unchanged.
create or replace function private.api049_notebooks(
  p_operation text, p_resource_id uuid, p_input jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_lesson jsonb;
begin
  if auth.uid() is null or not private.is_active_user() then
    return jsonb_build_object('outcome', 'forbidden');
  end if;
  case p_operation
    when 'myNotebooks' then
      return jsonb_build_object('outcome', 'ok', 'classes', coalesce((
        select jsonb_agg(jsonb_build_object(
            'classroomId', c.id,
            'name', c.name,
            'archived', c.archived_at is not null,
            'entries', (
              select coalesce(jsonb_agg(private.notebook_entry_json(n.id)
                order by n.created_at desc), '[]'::jsonb)
              from public.notebook_entries n
              where n.owner_id = auth.uid() and n.classroom_id = c.id
                and n.deleted_at is null))
          order by (c.archived_at is not null), c.name)
        from public.classrooms c
        where exists (
          select 1 from public.notebook_entries n
          where n.owner_id = auth.uid() and n.classroom_id = c.id
            and n.deleted_at is null)
      ), '[]'::jsonb));

    when 'lessonForNotes' then
      -- Turning a lesson into study notes is Studafy Plus, like the
      -- whiteboard: only a lesson the caller can see, only its text.
      if private.study_plan(auth.uid()) not in ('plus', 'max') then
        return jsonb_build_object('outcome', 'plan_required');
      end if;
      v_lesson := private.study_lesson(p_resource_id);
      if v_lesson is null then return jsonb_build_object('outcome', 'not_found'); end if;
      return jsonb_build_object('outcome', 'ok', 'lesson', v_lesson);

    when 'references' then
      -- Class material a student points the study helper at: a lesson they
      -- can see, or a note of their own. Anything else is left out, not
      -- refused, so one stale choice does not sink the question.
      return jsonb_build_object('outcome', 'ok', 'items', coalesce((
        select jsonb_agg(x.item order by x.ord)
        from (
          select r.ord, case r.kind
            when 'lesson' then (
              select jsonb_build_object('kind', 'lesson', 'id', l->>'resourceId',
                'title', l->>'title', 'text', l->>'body')
              from (select private.study_lesson(r.id) as l) s
              where s.l is not null)
            when 'note' then (
              select jsonb_build_object('kind', 'note', 'id', n.id,
                'title', n.title, 'text', n.body)
              from public.notebook_entries n
              where n.id = r.id and n.owner_id = auth.uid()
                and n.deleted_at is null)
            end as item
          from (
            select e.value->>'kind' as kind, (e.value->>'id')::uuid as id,
              e.ordinality as ord
            from jsonb_array_elements(coalesce(p_input->'items', '[]'::jsonb))
              with ordinality as e
          ) r
        ) x
        where x.item is not null
      ), '[]'::jsonb));

    when 'assistantAttachment' then
      -- The caller's own photo for the helper, once the scan has cleared it.
      if not exists (
        select 1 from public.file_objects f
        where f.id = p_resource_id and f.owner_id = auth.uid()
          and f.purpose = 'assistant_attachment' and f.deleted_at is null
      ) then
        return jsonb_build_object('outcome', 'not_found');
      end if;
      return jsonb_build_object('outcome', 'ok',
        'object', private.file051_effective_object(p_resource_id));

    else
      return jsonb_build_object('outcome', 'invalid');
  end case;
exception when invalid_text_representation then
  return jsonb_build_object('outcome', 'invalid');
end;
$$;
