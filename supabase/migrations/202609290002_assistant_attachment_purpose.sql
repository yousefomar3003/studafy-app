-- A photo a student sends the study helper (2026-09-29). On its own because
-- a new enum value cannot be used in the transaction that adds it; the
-- policy and the rules that use it are in 202609290003.
alter type public.file_purpose add value if not exists 'assistant_attachment';
