-- Two new upload purposes: chat attachments and announcement attachments.
--
-- Alone in its own migration on purpose. Postgres allows ALTER TYPE ... ADD
-- VALUE inside a transaction, but the new label cannot be *used* until that
-- transaction commits - and the policy rows in the next migration cast to
-- public.file_purpose. Splitting them is the only way both can be
-- forward-only (INFRA-081).

alter type public.file_purpose add value if not exists 'message_attachment';
alter type public.file_purpose add value if not exists 'announcement_attachment';
