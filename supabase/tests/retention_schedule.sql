-- The retention schedule (DL-057, 202610140001): timed purges past the
-- append-only guards, class closure, inactive accounts, and helper photos
-- (DL-060, 202610150070). Transactional fixtures: leaves local data intact.
begin;
\set auth031_fixture_only true
\ir rls_access_seed.sql
\unset auth031_fixture_only
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(54);

\set gone_user 'f0000000-0000-4000-8000-000000000001'
\set idle_student 'f0000000-0000-4000-8000-000000000002'
\set idle_loner 'f0000000-0000-4000-8000-000000000003'
\set idle_child 'f0000000-0000-4000-8000-000000000004'
\set leaving_teacher 'f0000000-0000-4000-8000-000000000005'
\set other_teacher 'f0000000-0000-4000-8000-000000000006'
\set second_class 'f0000000-0000-4000-8000-0000000000c2'
\set class_chat 'f0000000-0000-4000-8000-0000000000d1'
\set staff_chat 'f0000000-0000-4000-8000-0000000000d2'
\set reported_chat 'f0000000-0000-4000-8000-0000000000d3'
\set work_id 'f0000000-0000-4000-8000-0000000000e1'
\set old_tx 'f0000000-0000-4000-8000-0000000000f1'
\set answer_file 'f0000000-0000-4000-8000-0000000000b1'
\set lesson_file 'f0000000-0000-4000-8000-0000000000b2'
\set lesson_id 'f0000000-0000-4000-8000-0000000000b3'
\set lesson_v1 'f0000000-0000-4000-8000-0000000000b4'
\set newer_tx 'f0000000-0000-4000-8000-0000000000f2'

insert into auth.users (id, email, aud, role, created_at, updated_at, last_sign_in_at,
  instance_id, raw_app_meta_data, raw_user_meta_data)
select u.id::uuid, u.id || '@synthetic.studafy.test', 'authenticated', 'authenticated',
  now() - u.age, now() - u.age, now() - u.age,
  '00000000-0000-0000-0000-000000000000', '{}'::jsonb,
  jsonb_build_object('full_name', 'Retention ' || u.n)
from (values
  (:'gone_user', 'Gone', interval '8 years'),
  (:'idle_student', 'Idle student', interval '23 months 5 days'),
  (:'idle_loner', 'Idle loner', interval '23 months 5 days'),
  (:'idle_child', 'Idle child', interval '23 months 5 days'),
  (:'leaving_teacher', 'Leaving teacher', interval '1 day'),
  (:'other_teacher', 'Other teacher', interval '1 day')
) as u(id, n, age);

update public.profiles set status = 'deleted', deleted_at = now() - interval '7 years'
where id = :'gone_user';
insert into public.memberships (school_id, user_id, role, active) values
  (:'school_id', :'leaving_teacher', 'teacher', true),
  (:'school_id', :'other_teacher', 'teacher', true);
insert into public.students (school_id, user_id, studafy_id, display_name, provisional, created_by)
values (:'school_id', :'idle_student', 'STU-RET-0002', 'Idle student', false, :'teacher_user');
insert into private.managed_accounts (child_id, guardian_id) values (:'idle_child', :'guardian_user');

-- ---------------------------------------------------------------------------
-- Append-only stays append-only, except for the owner's timed purge.
-- ---------------------------------------------------------------------------
select throws_ok($$delete from public.audit_events where action = 'fixture.seed'$$,
  'P0001', 'Append-only relation cannot be updated or deleted',
  'the owner cannot delete an audit row outside a purge');
select set_config('studafy.retention_purge', 'on', true);
select throws_ok($$update public.audit_events set action = 'changed' where action = 'fixture.seed'$$,
  'P0001', 'Append-only relation cannot be updated or deleted',
  'a purge may delete but never change a row');
grant select, delete on public.audit_events to service_role;
set local role service_role;
select throws_ok($$delete from public.audit_events where action = 'fixture.seed'$$,
  'P0001', 'Append-only relation cannot be updated or deleted',
  'no other role can delete one, whatever it sets');
reset role;
select set_config('studafy.retention_purge', '', true);

-- ---------------------------------------------------------------------------
-- Records: security logs 2 years; consent and deletion records the life of
-- the account plus 6 years; billing 6 years after the tax year; legacy AI.
-- ---------------------------------------------------------------------------
insert into public.audit_events (school_id, actor_id, action, entity_type, entity_id, created_at) values
  (:'school_id', :'teacher_user', 'fixture.old', 'school', :'school_id', now() - interval '25 months'),
  (:'school_id', :'teacher_user', 'fixture.recent', 'school', :'school_id', now() - interval '23 months'),
  (null, :'teacher_user', 'account_deletion_requested', 'profile', :'teacher_user', now() - interval '7 years'),
  (null, null, 'account_deletion_requested', 'profile', :'gone_user', now() - interval '7 years 1 day'),
  (null, null, 'account_deleted', 'account_deletion_request', gen_random_uuid(), now() - interval '7 years'),
  (null, null, 'account_deleted', 'account_deletion_request', gen_random_uuid(), now() - interval '5 years');
insert into public.auth_security_events (actor_id, event_type, outcome, reason_code, created_at) values
  (:'teacher_user', 'sign_in_failed', 'denied', 'fixture', now() - interval '25 months'),
  (:'teacher_user', 'token_refreshed', 'allowed', 'fixture', now() - interval '1 month'),
  (:'teacher_user', 'consent_recorded', 'allowed', 'fixture', now() - interval '7 years'),
  (:'gone_user', 'consent_recorded', 'allowed', 'fixture', now() - interval '8 years');
insert into public.membership_events (school_id, membership_id, actor_id, event_type, idempotency_key, created_at)
select school_id, id, user_id, 'granted', 'retention:' || v.k, now() - v.age
from public.memberships, (values ('old', interval '25 months'), ('recent', interval '1 month')) v(k, age)
where school_id = :'school_id' and user_id = :'teacher_user' and role = 'teacher';
insert into public.consent_records (user_id, purpose, policy_version, locale) values
  (:'gone_user', 'terms', 'fixture-1', 'en'),
  (:'teacher_user', 'terms', 'fixture-1', 'en');
insert into public.account_deletion_requests (user_id, requested_at, execute_after, state, completed_at)
values (:'gone_user', now() - interval '7 years 15 days', now() - interval '7 years 1 day', 'completed', now() - interval '7 years');

insert into public.store_transactions (id, platform, environment, transaction_id, original_transaction_id,
  product_id, beneficiary_id, purchaser_id, state, signed_data_hash, purchased_at, effective_until, created_at)
select t.id::uuid, 'app_store', 'synthetic', 'retention-' || t.id, 'retention-' || t.id,
  (select p.id from public.store_products p where p.feature_key = 'student_ai'
     and p.platform = 'app_store' and p.environment = 'synthetic'),
  :'student_user', :'student_user', 'expired', repeat('e', 64), t.bought, t.bought + interval '1 month', t.bought
from (values (:'old_tx', date_trunc('year', now()) - interval '7 years' + interval '2 months'),
             (:'newer_tx', date_trunc('year', now()) - interval '6 years' + interval '2 months')) t(id, bought);
insert into public.entitlements (user_id, feature_key, source, source_transaction_id, status, starts_at, ends_at)
select :'student_user', 'student_ai', 'app_store', st.id, 'expired', st.purchased_at, st.effective_until
from public.store_transactions st where st.id = :'old_tx';
insert into public.store_transaction_history (store_transaction_id, previous_state, new_state, recorded_at)
values (:'old_tx', 'active', 'expired', now() - interval '6 years 9 months');

alter table public.practice_sessions drop constraint ai072_retired;
insert into public.practice_sessions (student_id, classroom_id, topic, kind, item_count, school_id)
values (:'student_id', :'classroom_id', 'Legacy', 'quiz', 3, :'school_id');

select lives_ok($$select private.retention_purge_records(5000)$$, 'the record purge runs');
select is((select array_agg(action order by action) from public.audit_events
    where action like 'fixture.%' or action like 'account_delet%'),
  array['account_deleted', 'account_deletion_requested', 'fixture.recent', 'fixture.seed'],
  'audit: 2-year rows go; deletion records of a live account, and recent ones, stay');
select is((select array_agg(event_type order by event_type) from public.auth_security_events
    where reason_code = 'fixture'),
  array['consent_recorded', 'token_refreshed'],
  'security events: old ones go, a live account''s consent stays');
select is((select array_agg(idempotency_key) from public.membership_events
    where idempotency_key like 'retention:%'),
  array['retention:recent'], 'role changes are kept 2 years');
select is((select array_agg(user_id) from public.consent_records where policy_version = 'fixture-1'),
  array[:'teacher_user'::uuid], 'consent records go 6 years after the account');
select ok(not exists (select 1 from public.account_deletion_requests where user_id = :'gone_user'),
  'so does the record of its deletion');
select is((select array_agg(id) from public.store_transactions where id in (:'old_tx', :'newer_tx')),
  array[:'newer_tx'::uuid], 'billing goes 6 years after the end of its tax year, not before');
select ok(not exists (select 1 from public.entitlements where source_transaction_id = :'old_tx')
  and not exists (select 1 from public.store_transaction_history where store_transaction_id = :'old_tx'),
  'with its entitlement and ledger history');
select is((select count(*)::int from public.practice_sessions), 0, 'the retired AI rows are deleted');

-- ---------------------------------------------------------------------------
-- A closed class: 12 months, unless the school instructed otherwise.
-- ---------------------------------------------------------------------------
insert into public.notebook_entries (school_id, classroom_id, student_id, owner_id, title, body, source)
values (:'school_id', :'classroom_id', :'student_id', :'student_user', 'Cells', 'Mitochondria.', 'typed');
insert into public.assignments (id, school_id, classroom_id, title, due_at, state, created_by, version, published_at)
values (:'work_id', :'school_id', :'classroom_id', 'Worksheet', now() - interval '14 months', 'published',
  :'teacher_user', 1, now() - interval '15 months');
insert into public.submissions (school_id, assignment_id, student_id, submitted_at, status)
values (:'school_id', :'work_id', :'student_id', now() - interval '14 months', 'submitted');
insert into public.submission_attempts (school_id, submission_id, operation_id, answer_text, submitted_at)
select :'school_id', s.id, gen_random_uuid(), 'My answer', now() - interval '14 months'
from public.submissions s where s.assignment_id = :'work_id';
update public.submissions s set current_attempt_id = sa.id
from public.submission_attempts sa where sa.submission_id = s.id and s.assignment_id = :'work_id';
insert into public.grade_result_events (school_id, grade_result_id, actor_id, event_type, next_state, idempotency_key)
select :'school_id', g.id, :'teacher_user', 'published', 'published', 'retention:grade'
from public.grade_results g where g.assessment_id = :'published_assessment_id';
insert into public.attendance_record_revisions (school_id, attendance_record_id, session_id, student_id,
  previous_state, previous_recorded_at, next_state, actor_id, reason, operation_id)
select :'school_id', a.id, a.session_id, a.student_id, 'present', now() - interval '14 months',
  'late', :'teacher_user', 'Bus', gen_random_uuid()
from public.attendance_records a where a.session_id = :'session_id';

-- A hand-in's file, and a lesson from the school's library published to
-- the class for one of its lessons; a quiz marking the work.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name) values
  (:'answer_file', :'school_id', 'legacy', 'files/retention-answer', :'student_user', 10, 'image/png',
    repeat('4', 64), 'clean', now(), :'student_user', 'assignment_submission', 'My answer.png'),
  (:'lesson_file', :'school_id', 'legacy', 'files/retention-lesson', :'teacher_user', 10, 'application/pdf',
    repeat('1', 64), 'clean', now(), :'teacher_user', 'lesson_resource', 'Cells.pdf');
insert into public.file_bindings (school_id, file_object_id, submission_attempt_id)
select :'school_id', :'answer_file', sa.id from public.submission_attempts sa
join public.submissions s on s.id = sa.submission_id where s.assignment_id = :'work_id';
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by, version)
values (:'lesson_id', :'school_id', 'Cells.pdf', 'file', 'published', 1, :'teacher_user', 1);
insert into public.resource_versions (id, school_id, resource_id, version, file_object_id, created_by)
values (:'lesson_v1', :'school_id', :'lesson_id', 1, :'lesson_file', :'teacher_user');
insert into public.file_bindings (school_id, file_object_id, resource_version_id)
values (:'school_id', :'lesson_file', :'lesson_v1');
insert into public.resource_publications (school_id, resource_version_id, classroom_id, lesson_session_id,
  audience, state, published_at, created_by)
values (:'school_id', :'lesson_v1', :'classroom_id', :'session_id', 'both', 'published', now(), :'teacher_user');
update public.assessments set assignment_id = :'work_id' where id = :'draft_assessment_id';

-- Conversations: one inside the class, one between staff, one reported.
insert into public.conversations (id, school_id, subject, created_by, created_at) values
  (:'class_chat', :'school_id', 'Homework', :'teacher_user', now() - interval '14 months'),
  (:'staff_chat', :'school_id', 'Staff', :'teacher_user', now() - interval '14 months'),
  (:'reported_chat', :'school_id', 'Reported', :'teacher_user', now() - interval '14 months');
insert into public.conversation_participants (school_id, conversation_id, user_id) values
  (:'school_id', :'class_chat', :'teacher_user'), (:'school_id', :'class_chat', :'student_user'),
  (:'school_id', :'staff_chat', :'teacher_user'), (:'school_id', :'staff_chat', :'other_teacher'),
  (:'school_id', :'reported_chat', :'teacher_user'), (:'school_id', :'reported_chat', :'other_teacher');
insert into public.messages (school_id, conversation_id, sender_id, client_message_id, body, created_at)
select :'school_id', c, :'teacher_user', gen_random_uuid(), 'Hello', now() - interval '13 months'
from unnest(array[:'class_chat', :'staff_chat', :'reported_chat']::uuid[]) c;
insert into public.reports (school_id, reported_by, kind, conversation_id, details)
values (:'school_id', :'other_teacher', 'conversation', :'reported_chat', 'Fixture report');

update public.classrooms set status = 'archived', archived_at = now() - interval '11 months'
where id = :'classroom_id';
select is(private.retention_purge_classes(5)->>'classes_purged', '0',
  'a class closed 11 months ago keeps its records');
select is((select array_agg(id order by subject) from public.conversations
    where id in (:'class_chat', :'staff_chat', :'reported_chat')),
  array[:'class_chat', :'reported_chat']::uuid[],
  'a conversation its people share no class for goes 12 months after its last message');
select ok(exists (select 1 from public.audit_events where action = 'retention_conversation_purged'
    and entity_id = :'staff_chat'), 'and the purge is audited');

update public.classrooms set archived_at = now() - interval '13 months' where id = :'classroom_id';
insert into private.school_retention_instructions (school_id, academic_retention_months, instruction_reference)
values (:'school_id', null, 'Fixture: keep until we ask');
select is(private.retention_purge_classes(5)->>'classes_purged', '0',
  'a school''s instruction to keep its records holds them');
update private.school_retention_instructions set academic_retention_months = 24 where school_id = :'school_id';
select is(private.retention_purge_classes(5)->>'classes_purged', '0',
  'a longer period the school set holds them for that long');
delete from private.school_retention_instructions where school_id = :'school_id';

select is(private.retention_purge_classes(5), jsonb_build_object(
    'classes_purged', 1, 'classes_kept', 0, 'conversations_purged', 1),
  'with no instruction, a class closed 13 months ago is purged, and its conversation with it');
select ok(not exists (select 1 from public.assignments where classroom_id = :'classroom_id')
  and not exists (select 1 from public.submissions s where s.assignment_id = :'work_id'),
  'its work and hand-ins are gone');
select ok(not exists (select 1 from public.assessments where classroom_id = :'classroom_id')
  and not exists (select 1 from public.grade_results g where g.assessment_id = :'published_assessment_id')
  and not exists (select 1 from public.grade_result_events where idempotency_key = 'retention:grade'),
  'so are its marks and their history');
select ok(not exists (select 1 from public.lesson_sessions where classroom_id = :'classroom_id')
  and not exists (select 1 from public.attendance_records where session_id = :'session_id')
  and not exists (select 1 from public.attendance_record_revisions where session_id = :'session_id'),
  'and its attendance and its history');
select ok(not exists (select 1 from public.enrollments where classroom_id = :'classroom_id'),
  'and its roster');
select ok((select academic_records_purged_at is not null from public.classrooms where id = :'classroom_id'),
  'the class itself stays, marked as purged');
select is((select count(*)::int from public.notebook_entries where classroom_id = :'classroom_id'), 1,
  'the student''s own notebook stays with it');
select ok(exists (select 1 from public.wellbeing_events where classroom_id = :'classroom_id'),
  'safeguarding notes are not academic records and stay with the school');
select ok(not exists (select 1 from public.conversations where id = :'class_chat'),
  'the class conversation goes once nobody shares a class any more');
select ok(exists (select 1 from public.conversations where id = :'reported_chat'),
  'a reported conversation stays for its report');
select ok((select retention_until <= now() from public.file_objects where id = :'answer_file'),
  'the hand-in''s file is now due for the file sweep to delete');
select ok(exists (select 1 from public.resources where id = :'lesson_id')
  and (select retention_until is null from public.file_objects where id = :'lesson_file')
  and not exists (select 1 from public.resource_publications where classroom_id = :'classroom_id'),
  'the lesson and its file stay in the school''s library; only the publication goes');
select ok(exists (select 1 from public.audit_events where action = 'retention_class_purged'
    and entity_id = :'classroom_id'), 'the class purge is audited');
select is(private.retention_purge_classes(5)->>'classes_purged', '0', 'a purged class is not purged again');

-- ---------------------------------------------------------------------------
-- Deleting the last teacher closes the class; consents survive deletion.
-- ---------------------------------------------------------------------------
insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
values (:'second_class', :'school_id', :'term_id', 'Second class', 'G6', 'B', :'leaving_teacher');
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select :'school_id', :'second_class', m.id, m.user_id, 'lead_teacher'
from public.memberships m where m.school_id = :'school_id' and m.user_id = :'leaving_teacher';
insert into public.consent_records (user_id, purpose, policy_version, locale)
values (:'leaving_teacher', 'terms', 'fixture-2', 'en');
insert into public.account_deletion_requests (user_id, requested_at, execute_after)
values (:'leaving_teacher', now() - interval '15 days', now() - interval '1 minute');
select is(private.account_deletion_execute(
    (select id from public.account_deletion_requests where user_id = :'leaving_teacher')),
  'completed', 'the teacher''s account is deleted');
select ok((select archived_at is not null from public.classrooms where id = :'second_class'),
  'the class they were the only teacher of is closed');
select ok(exists (select 1 from public.audit_events where action = 'classroom_archived'
    and entity_id = :'second_class' and after_value->>'cause' = 'last_teacher_deleted'),
  'and the closure says why');
select ok(exists (select 1 from public.consent_records where user_id = :'leaving_teacher'),
  'their consent records are kept');

-- ---------------------------------------------------------------------------
-- Inactive accounts: warned at 23 months, deletion requested at 24.
-- ---------------------------------------------------------------------------
select is(private.retention_inactive_accounts(100)->>'warned', '2',
  'two idle accounts are warned; a managed child goes with its parent instead');
select ok(exists (select 1 from public.notification_outbox o
    where o.recipient_id = :'idle_student' and o.template_key = 'account.inactive_deletion_warning'
      and o.school_id = :'school_id'),
  'the student is warned in the app, in their school');
select is((select notified_school_id from private.inactive_account_warnings where user_id = :'idle_loner'),
  null, 'someone with no school has no in-app channel yet');
select ok(not exists (select 1 from private.inactive_account_warnings where user_id = :'idle_child'),
  'the managed child is not warned');
select is(private.retention_inactive_accounts(100)->>'warned', '0', 'a warning is given once');

update auth.users set last_sign_in_at = now() - interval '24 months 1 day',
  created_at = now() - interval '24 months 1 day'
where id in (:'idle_student', :'idle_loner');
update private.inactive_account_warnings set warned_at = now() - interval '17 days',
  last_active_at = now() - interval '24 months 1 day';
select is(private.retention_inactive_accounts(100)->>'deletion_requested', '1',
  'at 24 months, deletion is requested for the person the warning reached');
select is((select requested_via || ':' || state || ':' || (impact_snapshot->>'cause')
    from public.account_deletion_requests where user_id = :'idle_student'),
  'system:grace_period:inactive_account', 'through the usual deletion workflow, with its grace period');
select ok((select execute_after between now() + interval '13 days' and now() + interval '15 days'
    from public.account_deletion_requests where user_id = :'idle_student'),
  'which deletes the account 14 days later');
select ok(not exists (select 1 from public.account_deletion_requests where user_id = :'idle_loner'),
  'nobody is deleted without a warning that reached them');

insert into auth.sessions (id, user_id, created_at, updated_at, refreshed_at)
values (gen_random_uuid(), :'idle_student', now() - interval '2 months', now(), now()::timestamp);
select is(private.retention_inactive_accounts(100)->>'activity_resumed', '1',
  'using the app again, even on a long-lived session, counts as activity');
select is((select state from public.account_deletion_requests where user_id = :'idle_student'),
  'cancelled', 'and cancels the deletion');
select ok(not exists (select 1 from private.inactive_account_warnings where user_id = :'idle_student'),
  'and clears the warning');

-- ---------------------------------------------------------------------------
-- Helper photos (DL-060): due for deletion 30 days after upload.
-- ---------------------------------------------------------------------------
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name, created_at)
select p.id::uuid, :'school_id', 'legacy', 'files/retention-' || p.id, p.owner::uuid, 10, 'image/jpeg',
  repeat(p.h, 64), 'clean', now(), p.owner::uuid, p.purpose::public.file_purpose, 'Photo.jpg', now() - p.age
from (values
  ('f0000000-0000-4000-8000-0000000000a1', :'student_user', 'assistant_attachment', interval '31 days', '5'),
  ('f0000000-0000-4000-8000-0000000000a2', :'student_user', 'assistant_attachment', interval '29 days', '6'),
  ('f0000000-0000-4000-8000-0000000000a3', :'guardian_user', 'assistant_attachment', interval '31 days', '7'),
  ('f0000000-0000-4000-8000-0000000000a4', :'student_user', 'notebook_photo', interval '31 days', '8')
) p(id, owner, purpose, age, h);
insert into public.legal_holds (school_id, subject_user_id, reason, ticket_ref, granted_by)
values (:'school_id', :'guardian_user', 'Fixture hold for a dispute', 'RET-HOLD-1', :'teacher_user');

select is(private.retention_expire_helper_photos(5000)->>'helper_photos', '1',
  'one helper photo is past its 30 days');
select ok((select retention_until <= now() from public.file_objects
    where id = 'f0000000-0000-4000-8000-0000000000a1'),
  'a helper photo uploaded 31 days ago is now due for the file sweep to delete');
select ok((select bool_and(retention_until is null) from public.file_objects
    where id in ('f0000000-0000-4000-8000-0000000000a2', 'f0000000-0000-4000-8000-0000000000a4')),
  'a newer helper photo, and a notebook photo, are left alone');
select ok((select retention_until is null from public.file_objects
    where id = 'f0000000-0000-4000-8000-0000000000a3'),
  'a person under a legal hold keeps theirs');
select is(private.retention_expire_helper_photos(5000)->>'helper_photos', '0',
  'a photo already due is not counted again');

-- ---------------------------------------------------------------------------
-- Only the worker may run the purges.
-- ---------------------------------------------------------------------------
select ok(has_function_privilege('studafy_worker_runtime', 'private.retention_purge_records(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.retention_purge_classes(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.retention_inactive_accounts(integer)', 'execute')
  and has_function_privilege('studafy_worker_runtime', 'private.retention_expire_helper_photos(integer)', 'execute'),
  'the worker runs the purges');
select ok(not has_function_privilege('studafy_api_runtime', 'private.retention_purge_records(integer)', 'execute')
  and not has_function_privilege('authenticated', 'private.retention_purge_classes(integer)', 'execute')
  and not has_function_privilege('service_role', 'private.retention_inactive_accounts(integer)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.retention_expire_helper_photos(integer)', 'execute')
  and not has_function_privilege('studafy_worker_runtime', 'private.retention_purge_class(uuid)', 'execute'),
  'nobody else does');

select * from finish();
rollback;
