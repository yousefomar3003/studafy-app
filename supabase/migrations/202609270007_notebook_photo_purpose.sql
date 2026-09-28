-- A photo a student takes of the lesson whiteboard, for Studafy Plus to turn
-- into notebook notes.
--
-- Its own migration: a value added to an enum cannot be used in the
-- transaction that adds it, and the next migration uses it.
alter type public.file_purpose add value if not exists 'notebook_photo';
