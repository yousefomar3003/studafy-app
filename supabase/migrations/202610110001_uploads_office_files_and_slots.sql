-- Uploads that failed on the phone (2026-10-11).
--
-- 1. The storage bucket refused Word and PowerPoint. 202610070001 let
--    lessons and assignment material take .docx and .pptx, but the bucket's
--    own allow-list - a second gate on the signed upload - still named only
--    PDF, images and audio. The API granted the upload slot, then Storage
--    answered 415 "mime type not supported" when the phone sent the bytes.
--    The bucket now allows exactly the union of what the enabled purposes
--    allow (and keeps anything it already had), so the two cannot drift
--    apart silently again; supabase/tests/file050_upload.sql checks it.
--
-- 2. Students may hand in Word and PowerPoint files, as teachers may attach
--    them. The scan reads both formats (macro-free OOXML only).
--
-- 3. A person could hold only 3 unfinished uploads, and an abandoned one
--    counted until its signed link expired, two hours later. Three failed
--    Word files therefore blocked every upload, PDFs included, for two
--    hours. The limit is 10; the links themselves now last 30 minutes
--    (packages/infrastructure privateFileStorage.ts).

update public.file_purpose_policies
set allowed_media_types = array[
      'application/pdf', 'image/jpeg', 'image/png',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation'],
    updated_at = now()
where purpose = 'assignment_submission';

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

alter table public.file_quota_policies
  alter column user_active_sessions set default 10;

update public.file_quota_policies
set user_active_sessions = 10, updated_at = now()
where user_active_sessions < 10;
