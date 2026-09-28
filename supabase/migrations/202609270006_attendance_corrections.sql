-- A register that has been taken can be corrected.
--
-- recordAttendance upserts each mark and, on a correction, sets recorded_by
-- and recorded_at to the teacher making it now. DB-021 had made both columns
-- immutable, so every correction raised inside the command and the API
-- answered 500: a teacher who marked a child absent and then saw them walk in
-- could never fix it.
--
-- What must not change about a mark is what it is *about* - which student,
-- which lesson, which school - and that stays locked. Who last recorded it
-- and when are what a correction is supposed to change; the full history of
-- who changed what, and when, is kept by the attendance_recorded audit event
-- every save writes.

drop trigger if exists db021_immutable_attendance_record on public.attendance_records;
create trigger db021_immutable_attendance_record
before update on public.attendance_records
for each row execute function private.reject_immutable_columns(
  'id', 'school_id', 'session_id', 'student_id'
);
