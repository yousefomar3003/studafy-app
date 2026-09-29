-- Voice notes in messages (2026-09-28).
--
-- A voice note is a message attachment of type audio/mp4: AAC in an MP4
-- container, which iOS and Android both record natively. It goes through
-- the same pipeline as every other file - quarantine, a structural scan
-- (packages/domain/src/files/mp4.ts: sound tracks only, no external data
-- references, nothing after the last box) and a deterministic rewrite that
-- neutralises metadata boxes - and is only ever delivered once clean.
--
-- Only message attachments take audio. The size ceiling stays at 5 MB,
-- which at the app's 64 kbit/s is well over the five minutes it records.

update public.file_purpose_policies
set allowed_media_types = array[
      'application/pdf', 'image/jpeg', 'image/png', 'audio/mp4'],
    policy_version = 'file050-v2-voice',
    updated_at = now()
where purpose = 'message_attachment';

-- The bucket's own allow-list is a second gate on the signed upload.
update storage.buckets
set allowed_mime_types = array[
      'application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'audio/mp4']
where id = 'private-school-files';
