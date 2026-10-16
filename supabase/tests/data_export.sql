-- DL-051: an export request becomes a document of the requester's own data,
-- downloadable only by them, and its payload is deleted when it expires.
-- DL-060: the document (v2) also carries exam answers, hand-ins and their
-- files, voice notes, messages received, mark and attendance history and AI
-- usage, and still nobody else's data beyond what the app shows them.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(39);

\set school_id '11111111-1111-4111-8111-111111111111'
\set teacher_user 'aaaa0000-0000-4000-8000-000000000001'
\set student_user 'bbbb0000-0000-4000-8000-000000000002'
\set guardian_user 'cccc0000-0000-4000-8000-000000000003'
\set co_teacher_user 'ffff0000-0000-4000-8000-000000000002'
\set second_student_user 'ffff0000-0000-4000-8000-000000000003'
\set classroom_id 'abcd0000-0000-4000-8000-000000000007'
\set student_id 'abcf0000-0000-4000-8000-000000000008'
\set second_student_id 'abcf0000-0000-4000-8000-000000000208'
\set published_assessment_id 'abd00000-0000-4000-8000-000000000009'
\set session_id 'abd20000-0000-4000-8000-00000000000b'
\set published_assignment_id 'abd40000-0000-4000-8000-000000000109'
\set submission_id 'abd50000-0000-4000-8000-00000000010b'
\set released_exam 'e0e00000-0000-4000-8000-0000000000a1'
\set open_exam 'e0e00000-0000-4000-8000-0000000000a2'
\set child_user 'e0e00000-0000-4000-8000-0000000000c9'

insert into public.conversations (id, school_id, subject, created_by) values
  ('e0e00000-0000-4000-8000-0000000000c1', :'school_id', 'Revision', :'teacher_user'),
  ('e0e00000-0000-4000-8000-0000000000c2', :'school_id', 'Staff room', :'teacher_user'),
  ('e0e00000-0000-4000-8000-0000000000c3', :'school_id', 'Old club', :'teacher_user');
insert into public.conversation_participants (school_id, conversation_id, user_id, joined_at, left_at) values
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'teacher_user', now() - interval '2 days', null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'student_user', now() - interval '2 days', null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c2', :'teacher_user', now() - interval '2 days', null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c2', :'co_teacher_user', now() - interval '2 days', null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c3', :'teacher_user', now() - interval '2 days', null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000c3', :'student_user', now() - interval '2 days', now() - interval '1 day');
insert into public.messages (id, school_id, conversation_id, sender_id, client_message_id, body) values
  ('e0e00000-0000-4000-8000-0000000000d1', :'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'student_user', gen_random_uuid(), 'my own words'),
  ('e0e00000-0000-4000-8000-0000000000d2', :'school_id', 'e0e00000-0000-4000-8000-0000000000c1', :'teacher_user', gen_random_uuid(), 'the teacher reply to me'),
  ('e0e00000-0000-4000-8000-0000000000d3', :'school_id', 'e0e00000-0000-4000-8000-0000000000c2', :'teacher_user', gen_random_uuid(), 'staff room private words'),
  ('e0e00000-0000-4000-8000-0000000000d4', :'school_id', 'e0e00000-0000-4000-8000-0000000000c3', :'teacher_user', gen_random_uuid(), 'said after I left');
-- 3.6b: the export also carries gender, notebooks and devices.
update public.profiles set gender = 'prefer_not_to_say' where id = :'student_user';
insert into public.push_devices (user_id, platform, token)
values (:'student_user', 'ios', repeat('e', 40));
insert into public.notebook_entries (school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'student_id', :'student_user', 'Revision page', 'my notebook words', 'typed');

-- DL-060 fixtures. Files: a voice note on the teacher's reply, a file on
-- the student's hand-in, a helper photo, and the teacher's own upload.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name) values
  ('e0e00000-0000-4000-8000-0000000000f1', :'school_id', 'legacy', 'files/export-voice', :'teacher_user', 2048,
    'audio/mp4', repeat('a', 64), 'clean', now(), :'teacher_user', 'message_attachment', 'Voice note.m4a'),
  ('e0e00000-0000-4000-8000-0000000000f2', :'school_id', 'legacy', 'files/export-handin', :'student_user', 4096,
    'application/pdf', repeat('b', 64), 'clean', now(), :'student_user', 'assignment_submission', 'My essay.pdf'),
  ('e0e00000-0000-4000-8000-0000000000f3', :'school_id', 'legacy', 'files/export-helper', :'student_user', 1024,
    'image/jpeg', repeat('c', 64), 'clean', now(), :'student_user', 'assistant_attachment', 'Homework photo.jpg'),
  ('e0e00000-0000-4000-8000-0000000000f4', :'school_id', 'legacy', 'files/export-teacher', :'teacher_user', 512,
    'application/pdf', repeat('d', 64), 'clean', now(), :'teacher_user', 'lesson_resource', 'Teacher plans.pdf');
insert into public.file_bindings (school_id, file_object_id, message_id)
values (:'school_id', 'e0e00000-0000-4000-8000-0000000000f1', 'e0e00000-0000-4000-8000-0000000000d2');

-- Hand-ins: the student's two attempts, the second with a file; the
-- classmate's own hand-in to the same work.
insert into public.submission_attempts (id, school_id, submission_id, operation_id, answer_text, submitted_at, created_at) values
  ('e0e00000-0000-4000-8000-0000000000b1', :'school_id', :'submission_id', gen_random_uuid(), 'my first draft words', now() - interval '2 days', now() - interval '2 days'),
  ('e0e00000-0000-4000-8000-0000000000b2', :'school_id', :'submission_id', gen_random_uuid(), 'my final essay words', now() - interval '1 day', now() - interval '1 day');
update public.submissions set current_attempt_id = 'e0e00000-0000-4000-8000-0000000000b2'
  where id = :'submission_id';
insert into public.file_bindings (school_id, file_object_id, submission_attempt_id)
values (:'school_id', 'e0e00000-0000-4000-8000-0000000000f2', 'e0e00000-0000-4000-8000-0000000000b2');
insert into public.submissions (id, school_id, assignment_id, student_id, submitted_at, status)
values ('e0e00000-0000-4000-8000-0000000000b9', :'school_id', :'published_assignment_id', :'second_student_id', now(), 'submitted');
insert into public.submission_attempts (school_id, submission_id, operation_id, answer_text, submitted_at)
values (:'school_id', 'e0e00000-0000-4000-8000-0000000000b9', gen_random_uuid(), 'classmate essay words', now());

-- Online exams: one closed with answers released, one still open.
insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state, delivery,
  created_by, published_at, opens_at, closes_at, answer_release) values
  (:'released_exam', :'school_id', :'classroom_id', 'Released exam', 'quiz', 5, 'published', 'online',
    :'teacher_user', now() - interval '3 days', now() - interval '3 days', now() - interval '1 day', 'after_close'),
  (:'open_exam', :'school_id', :'classroom_id', 'Open exam', 'quiz', 5, 'published', 'online',
    :'teacher_user', now() - interval '3 days', now() - interval '3 days', now() + interval '1 day', 'after_close');
insert into public.assessment_questions (id, school_id, assessment_id, position, prompt, maximum_score, kind, options, answer_key) values
  ('e0e00000-0000-4000-8000-0000000000a3', :'school_id', :'released_exam', 1, 'Which gas do plants take in?', 5,
    'single_choice', '[{"id":"a","text":"Carbon dioxide"},{"id":"b","text":"Helium"}]', '["a"]'),
  ('e0e00000-0000-4000-8000-0000000000a4', :'school_id', :'open_exam', 1, 'Explain photosynthesis in full', 5,
    'essay', '[]', null);
insert into public.assessment_attempts (id, school_id, assessment_id, student_id, operation_id, submitted_at,
  attempt_number, awarded_score, feedback) values
  ('e0e00000-0000-4000-8000-0000000000a5', :'school_id', :'released_exam', :'student_id', gen_random_uuid(), now() - interval '2 days',
    1, 5, 'Released praise'),
  ('e0e00000-0000-4000-8000-0000000000a6', :'school_id', :'open_exam', :'student_id', gen_random_uuid(), now() - interval '2 days',
    1, 4, 'Unreleased attempt note'),
  ('e0e00000-0000-4000-8000-0000000000a7', :'school_id', :'released_exam', :'second_student_id', gen_random_uuid(), now() - interval '2 days',
    1, 0, null);
insert into public.assessment_answers (school_id, attempt_id, question_id, answer_text, selected, auto_score, awarded_score, feedback) values
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000a5', 'e0e00000-0000-4000-8000-0000000000a3', '', '["a"]', 5, null, null),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000a6', 'e0e00000-0000-4000-8000-0000000000a4', 'Plants make sugar from light', null, null, 4, 'Unreleased answer note'),
  (:'school_id', 'e0e00000-0000-4000-8000-0000000000a7', 'e0e00000-0000-4000-8000-0000000000a3', 'classmate exam words', '["b"]', 0, null, null);

-- Mark history: a draft the student never saw, the publication, a
-- correction. Attendance: a change with its reason.
insert into public.grade_result_events (school_id, grade_result_id, actor_id, event_type, previous_state, next_state,
  previous_score, next_score, reason, idempotency_key, created_at)
select :'school_id', g.id, :'teacher_user', e.t, e.ps::public.publication_state, e.ns::public.publication_state,
  e.prev, e.next, e.reason, 'export:' || e.t, now() - e.ago
from public.grade_results g,
  (values ('reviewed', 'draft', 'reviewed', null::numeric, 3::numeric, null, interval '3 days'),
          ('published', 'reviewed', 'published', 3, 7, null, interval '2 days'),
          ('corrected', 'published', 'published', 7, 8, 'Recounted page two', interval '1 day')) e(t, ps, ns, prev, next, reason, ago)
where g.assessment_id = :'published_assessment_id' and g.student_id = :'student_id';
insert into public.attendance_record_revisions (school_id, attendance_record_id, session_id, student_id,
  previous_state, previous_recorded_at, next_state, next_reason, actor_id, reason, operation_id)
select :'school_id', a.id, a.session_id, a.student_id, 'absent', now() - interval '1 day',
  'late', 'Bus', :'teacher_user', 'Arrived after the register', gen_random_uuid()
from public.attendance_records a where a.session_id = :'session_id' and a.student_id = :'student_id';

-- AI usage, for the student and for another account.
insert into private.ai_usage (user_id, feature, plan, month, status, reserved_micro_usd, cost_micro_usd,
  input_tokens, output_tokens, metered_tokens, model, request_key) values
  (:'student_user', 'ask', 'free', date_trunc('month', now())::date, 'settled', 0, 777123,
    120, 80, 200, 'student-model', 'student-request-key'),
  (:'teacher_user', 'notes', 'free', date_trunc('month', now())::date, 'settled', 0, 0,
    10, 10, 20, 'teacher-model', null);

-- A child account the guardian manages (ADR-0031).
insert into auth.users (id, email, aud, role, created_at, updated_at, instance_id,
  raw_app_meta_data, raw_user_meta_data)
values (:'child_user', 'child-export@managed.studafy.invalid', 'authenticated', 'authenticated', now(), now(),
  '00000000-0000-0000-0000-000000000000', '{}'::jsonb, '{"full_name":"Managed Kid"}'::jsonb);
insert into private.managed_accounts (child_id, guardian_id) values (:'child_user', :'guardian_user');
insert into private.ai_usage (user_id, feature, plan, month, status, reserved_micro_usd, model)
values (:'child_user', 'ask', 'free', date_trunc('month', now())::date, 'settled', 0, 'child-model');

insert into public.data_export_requests (id, user_id, status)
values ('e0e00000-0000-4000-8000-0000000000e1', :'student_user', 'pending');

select ok(has_function_privilege('studafy_worker_runtime', 'private.data_export_build(uuid)', 'execute'),
  'the worker can build exports');
select ok(not has_function_privilege('studafy_api_runtime', 'private.data_export_build(uuid)', 'execute'),
  'the API cannot build exports');
select ok('e0e00000-0000-4000-8000-0000000000e1'::uuid = any(private.data_export_claim(50)),
  'a pending request is claimed');
select is(private.data_export_build('e0e00000-0000-4000-8000-0000000000e1'), 'ready',
  'the export is built');
select is(private.data_export_build('e0e00000-0000-4000-8000-0000000000e1'), 'ready',
  'building again is a no-op');

select set_config('request.jwt.claim.sub', :'student_user', true);
create temp table export_doc on commit drop as
  select private.api042_query('downloadDataExport', null, '{}') as d;
create temp table export_record on commit drop as
  select d->'sections'->'studentRecords'->0 as r from export_doc;

select is((select d->>'format' from export_doc), 'studafy-export/v2',
  'the owner downloads a versioned document');
select ok((select (d->'sections'->'messagesSent')::text like '%my own words%' from export_doc),
  'the document contains messages the owner sent');
select is((select d->'sections'->'profile'->>'displayName' from export_doc), 'Seed Student',
  'the document includes the profile');
select is((select d->'sections'->'profile'->>'gender' from export_doc), 'prefer_not_to_say',
  'the document includes the gender the owner gave');
select ok((select (d->'sections'->'notebookEntries')::text like '%my notebook words%' from export_doc),
  'the document includes the owner''s notebook');
select ok((select (d->'sections'->'devices')::text like '%"notifications"%'
    and d::text not like '%eeeeeeeeee%' from export_doc),
  'the document lists devices without the push token');

-- Messages received, with voice notes.
select ok((select d->'sections'->'messagesReceived' @> jsonb_build_array(jsonb_build_object(
    'from', 'Seed Teacher', 'body', 'the teacher reply to me')) from export_doc),
  'messages received are included, with the sender''s display name');
select ok((select d->'sections'->'messagesReceived'->0->'attachments' @> '[{"kind":"voiceNote","displayName":"Voice note.m4a","sizeBytes":2048}]'
    from export_doc),
  'a voice note on a received message is listed by name, kind and size');
select ok((select d::text not like '%staff room private words%' from export_doc),
  'messages in conversations the owner is not in are never included');
select ok((select d::text not like '%said after I left%' from export_doc),
  'nor are messages in a conversation they have left, which the app no longer shows');
select ok((select d->'sections'->'conversations' @> '[{"subject":"Revision"},{"subject":"Old club"}]'
    and d::text not like '%Staff room%' from export_doc),
  'the conversations they are or were in are listed, and no others');

-- Hand-ins.
select is((select jsonb_array_length(r->'submissions'->0->'attempts') from export_record), 2,
  'every hand-in attempt is included');
select ok((select r->'submissions'->0->'attempts' @> jsonb_build_array(jsonb_build_object(
    'text', 'my final essay words', 'current', true, 'handedInByParent', false,
    'files', jsonb_build_array(jsonb_build_object('displayName', 'My essay.pdf', 'sizeBytes', 4096,
      'mediaType', 'application/pdf'))))
  from export_record),
  'with its text and its files');
select ok((select d::text not like '%classmate essay words%' from export_doc),
  'a classmate''s hand-in is never included');
select ok((select d::text not like '%files/export-%' and d::text not like '%' || repeat('b', 64) || '%' from export_doc),
  'files are described, never located: no storage key or hash');
select ok((select d->'sections'->'about'->>'files' like '%not in this document%' from export_doc),
  'the document says file contents are not in it, and how to get them');

-- Online exams.
select ok((select r->'onlineAssessments' @> '[{"assessment":"Released exam","answersReleased":true,"awardedScore":5,"feedback":"Released praise"}]'
    from export_record),
  'a released exam carries the attempt''s mark and feedback');
select ok((select r->'onlineAssessments' @> '[{"assessment":"Released exam","answers":[{"question":"Which gas do plants take in?","selectedOptions":["Carbon dioxide"],"autoScore":5}]}]'
    from export_record),
  'and each question with the owner''s answer and its mark');
select ok((select r->'onlineAssessments' @> '[{"assessment":"Open exam","answersReleased":false,"answers":[{"questionNumber":1,"answerText":"Plants make sugar from light"}]}]'
    from export_record),
  'an unreleased exam still carries the owner''s own answers');
select ok((select d::text not like '%Explain photosynthesis%' and d::text not like '%Unreleased%' from export_doc),
  'but not its questions, marks or feedback until they are released, as in the app');
select ok((select d::text not like '%classmate exam words%' and d::text not like '%correctOptionIds%' from export_doc),
  'a classmate''s exam answers, and answer keys, are never included');

-- Mark and attendance history.
select is((select jsonb_agg(e->>'change' order by e->>'at') from export_record, jsonb_array_elements(r->'gradeHistory') e),
  '["published", "corrected"]'::jsonb,
  'mark history starts at publication: a draft the student never saw is left out');
select ok((select r->'gradeHistory' @> '[{"change":"corrected","previousScore":7,"score":8,"reason":"Recounted page two"}]'
    from export_record),
  'a correction carries the previous and new mark and its reason');
select ok((select r->'attendanceHistory' @> '[{"previousState":"absent","state":"late","changeReason":"Arrived after the register","lesson":"Seed Session"}]'
    from export_record),
  'attendance history carries every change and its reason');

-- AI usage and the owner's files.
select ok((select d->'sections'->'aiUsage' @> '[{"feature":"ask","countedTokens":200,"model":"student-model"}]'
    and jsonb_array_length(d->'sections'->'aiUsage') = 1 from export_doc),
  'the owner''s AI usage is included, and nobody else''s');
select ok((select d::text not like '%student-request-key%' and d::text not like '%777123%' from export_doc),
  'without the request key or the cost');
select ok((select d->'sections'->'filesUploaded' @> '[{"displayName":"Homework photo.jpg","kind":"helperPhoto","purpose":"assistant_attachment"}]'
    and d::text not like '%Teacher plans.pdf%' from export_doc),
  'every file the owner uploaded is listed, helper photos included, and no one else''s');

-- A parent's export lists the child accounts they manage, not the child's
-- data; the child's own export names who manages it.
select ok(private.data_export_document(:'guardian_user')->'sections'->'managedChildAccounts'
    @> '[{"displayName":"Managed Kid"}]',
  'a parent''s export lists the child accounts they manage');
select ok(private.data_export_document(:'guardian_user')::text not like '%child-model%',
  'but not the child''s own data, which the child''s account exports');
select is(private.data_export_document(:'child_user')->'sections'->'profile'->>'managedBy', 'Seed Guardian',
  'a child account''s export names who manages it');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select is(private.api042_query('downloadDataExport', null, '{}')->>'outcome', 'not_found',
  'nobody else can download it');

update public.data_export_requests set expires_at = now() - interval '1 minute'
  where id = 'e0e00000-0000-4000-8000-0000000000e1';
select ok(private.data_export_expire() >= 1, 'expired exports are swept');
select is((select count(*) from public.data_export_payloads
  where request_id = 'e0e00000-0000-4000-8000-0000000000e1'), 0::bigint,
  'the expired payload is deleted');

select ok(not has_function_privilege('studafy_api_runtime', 'private.data_export_document(uuid)', 'execute')
  and not has_function_privilege('studafy_worker_runtime', 'private.data_export_files(uuid, uuid, uuid)', 'execute')
  and not has_function_privilege('authenticated', 'private.data_export_file_json(public.file_objects)', 'execute'),
  'the document and its helpers are callable only through the build');

select * from finish();
rollback;
