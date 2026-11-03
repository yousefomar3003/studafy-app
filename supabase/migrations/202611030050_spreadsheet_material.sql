-- Teachers can attach Excel and CSV; the AI reads them (DL-077, 2026-11-03).
--
-- 1. Lesson files (`lesson_resource`) and assignment material
--    (`assignment_material`) may be .xlsx workbooks and .csv files, as they
--    may be Word and PowerPoint (202610070001). Students' hand-ins
--    (`assignment_submission`) and every other purpose are unchanged.
--
--    The scan reads a workbook as it reads Word and PowerPoint - a bounded
--    ZIP walk that refuses macros (VBA and Excel 4.0 macro sheets), ActiveX,
--    embedded objects, links to other workbooks, data connections and web
--    queries, and anything but the plain workbook content type - and a CSV
--    as UTF-8 text with no NUL or other control bytes. Neither is ever run;
--    both are stored unchanged and delivered as downloads
--    (packages/domain/src/files/ooxml.ts, csv.ts).
--
-- 2. The storage bucket's own allow-list stays the union of what the enabled
--    purposes allow, exactly as 202610110001 set it, so the API cannot grant
--    a slot that Storage then refuses (supabase/tests/file050_upload.sql).
--
-- 3. The material index reads both types from lesson files: rows as text,
--    sheet names as headings, hidden sheets, rows and columns left out
--    (packages/infrastructure/src/material/spreadsheet.ts). No lesson file of
--    either type exists yet - none could be uploaded - so nothing is queued
--    here.

update public.file_purpose_policies p
set allowed_media_types = p.allowed_media_types || array(
      select t
      from unnest(array[
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv']) as t
      where not (t = any(p.allowed_media_types))),
    updated_at = now()
where p.purpose in ('lesson_resource', 'assignment_material');

update storage.buckets b
set allowed_mime_types = (
  select array_agg(distinct t order by t)
  from (
    select unnest(p.allowed_media_types) as t
    from public.file_purpose_policies p
    where p.enabled
    union
    select unnest(coalesce(b.allowed_mime_types, '{}'::text[]))
  ) types
)
where b.id = 'private-school-files';

-- The media types the material index reads.
create or replace function private.ai_material_readable_type(p_media text)
returns boolean language sql immutable set search_path = '' as $$
  select p_media in ('application/pdf', 'image/jpeg', 'image/png',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv');
$$;
