-- AI output is made once and reused (2026-09-29).
--
-- Quizzes and flashcards were already made once per lesson version and
-- shared (ADR-0029). Lesson notes and whiteboard notes were not: asking again
-- for notes on the same lesson, or sending the same whiteboard photo again,
-- called the provider again and charged the student's allowance again.
--
--   * Lesson notes are cached per lesson version, shared by every student
--     who can read that version, exactly like study sets. The text comes
--     from the teacher's lesson alone, so nothing of a student's is shared.
--     A revised lesson is a new version and gets new notes.
--   * The same whiteboard photo returns the note already made from it, while
--     that note exists. Nothing is kept once the student deletes the note:
--     the photo and the notes are the student's own.
--
-- The study helper's answers are not stored on the server at all: a chat is
-- kept on the student's device (StudyAssistantPage), and a repeated question
-- is answered from there.

create table if not exists private.lesson_notes_cache (
  resource_version_id uuid primary key
    references public.resource_versions(id) on delete cascade,
  body text not null check (length(body) between 1 and 20000),
  model text not null check (length(model) between 1 and 120),
  created_at timestamptz not null default now()
);
revoke all on private.lesson_notes_cache
  from public, anon, authenticated, service_role, studafy_api_runtime,
  studafy_worker_runtime;

-- Stores notes the API just generated, re-checking what the route checked:
-- a Plus or Max caller who can see this exact version of the lesson. The
-- first notes for a version win; later ones are dropped.
create or replace function private.lesson_notes_cache_put(
  p_resource_id uuid, p_version_id uuid, p_body text, p_model text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_lesson jsonb;
begin
  if auth.uid() is null or not private.is_active_user()
     or private.study_plan(auth.uid()) not in ('plus', 'max') then
    return false;
  end if;
  v_lesson := private.study_lesson(p_resource_id);
  if v_lesson is null or (v_lesson->>'versionId')::uuid is distinct from p_version_id then
    return false;
  end if;
  insert into private.lesson_notes_cache(resource_version_id, body, model)
  values (p_version_id, left(p_body, 20000), left(coalesce(nullif(p_model, ''), 'unknown'), 120))
  on conflict (resource_version_id) do nothing;
  return true;
end;
$$;
alter function private.lesson_notes_cache_put(uuid, uuid, text, text) owner to postgres;
revoke all on function private.lesson_notes_cache_put(uuid, uuid, text, text)
  from public, anon, authenticated, service_role, studafy_worker_runtime;
grant execute on function private.lesson_notes_cache_put(uuid, uuid, text, text)
  to studafy_api_runtime;

-- The notebooks surface, re-issued from 202609290003 with lessonForNotes
-- returning cached notes and a whiteboardEntry read added.
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
      -- Notes already made from this version of the lesson: reused, so the
      -- provider is not asked (or paid) twice for the same text.
      return jsonb_build_object('outcome', 'ok', 'lesson', v_lesson,
        'cachedNotes', (
          select c.body from private.lesson_notes_cache c
          where c.resource_version_id = (v_lesson->>'versionId')::uuid));

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

    when 'whiteboardEntry' then
      -- The caller's own live note already made from this photo, if any.
      -- A deleted note is not kept anywhere, so it is made afresh.
      return jsonb_build_object('outcome', 'ok', 'entry', (
        select private.notebook_entry_json(n.id) from public.notebook_entries n
        where n.photo_file_id = p_resource_id and n.owner_id = auth.uid()
          and n.source = 'whiteboard' and n.deleted_at is null
        order by n.created_at desc limit 1));

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
