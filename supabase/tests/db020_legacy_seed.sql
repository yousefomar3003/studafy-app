-- Legacy-shaped fixture loaded after reset --version 202609090004 and before
-- applying DB-020. Contains synthetic values only and intentionally omits all
-- columns introduced by the DB-020 migrations.

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  ('71000000-0000-4000-8000-000000000001', 'db020.teacher.a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"DB020 Teacher A"}'::jsonb),
  ('71000000-0000-4000-8000-000000000002', 'db020.student.a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"DB020 Student A"}'::jsonb),
  ('71000000-0000-4000-8000-000000000003', 'db020.guardian.a@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"DB020 Guardian A"}'::jsonb),
  ('72000000-0000-4000-8000-000000000001', 'db020.teacher.b@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"DB020 Teacher B"}'::jsonb);

insert into public.schools (id, name) values
  ('71111111-1111-4111-8111-111111111111', 'DB020 School A'),
  ('72222222-2222-4222-8222-222222222222', 'DB020 School B');

insert into public.memberships (id, school_id, user_id, role, active) values
  ('71000000-0000-4000-8000-000000000011', '71111111-1111-4111-8111-111111111111', '71000000-0000-4000-8000-000000000001', 'teacher', true),
  ('71000000-0000-4000-8000-000000000012', '71111111-1111-4111-8111-111111111111', '71000000-0000-4000-8000-000000000002', 'student', true),
  ('71000000-0000-4000-8000-000000000013', '71111111-1111-4111-8111-111111111111', '71000000-0000-4000-8000-000000000003', 'parent', false),
  ('72000000-0000-4000-8000-000000000011', '72222222-2222-4222-8222-222222222222', '72000000-0000-4000-8000-000000000001', 'teacher', true);

insert into public.terms (id, school_id, name, starts_on, ends_on, active) values
  ('71000000-0000-4000-8000-000000000021', '71111111-1111-4111-8111-111111111111', 'Active Term', '2026-09-01', '2026-12-31', true),
  ('72000000-0000-4000-8000-000000000021', '72222222-2222-4222-8222-222222222222', 'Other Term', '2026-09-01', '2026-12-31', true);

insert into public.students (
  id, school_id, user_id, studafy_id, display_name, provisional, created_by
) values
  ('71000000-0000-4000-8000-000000000031', '71111111-1111-4111-8111-111111111111', '71000000-0000-4000-8000-000000000002', 'DB020-A-1', 'DB020 Student A', false, '71000000-0000-4000-8000-000000000001');

insert into public.guardian_links (
  id, student_id, guardian_id, status, relationship, verified_by, verified_at
) values (
  '71000000-0000-4000-8000-000000000041',
  '71000000-0000-4000-8000-000000000031',
  '71000000-0000-4000-8000-000000000003', 'verified', 'parent',
  '71000000-0000-4000-8000-000000000001', now()
);

insert into public.classrooms (
  id, school_id, term_id, name, grade, section, teacher_id
) values
  ('71000000-0000-4000-8000-000000000051', '71111111-1111-4111-8111-111111111111', '71000000-0000-4000-8000-000000000021', 'DB020 Class A', 'G6', 'A', '71000000-0000-4000-8000-000000000001'),
  ('72000000-0000-4000-8000-000000000051', '72222222-2222-4222-8222-222222222222', '72000000-0000-4000-8000-000000000021', 'DB020 Class B', 'G6', 'B', '72000000-0000-4000-8000-000000000001');

insert into public.enrollments (classroom_id, student_id, active) values
  ('71000000-0000-4000-8000-000000000051', '71000000-0000-4000-8000-000000000031', false);

insert into public.lesson_sessions (
  id, classroom_id, starts_at, ends_at, title, filed_at
) values (
  '71000000-0000-4000-8000-000000000061',
  '71000000-0000-4000-8000-000000000051',
  '2026-09-11 08:00+00', '2026-09-11 09:00+00', 'DB020 Session', now()
);

insert into public.lesson_materials (
  id, session_id, title, body, created_by
) values (
  '71000000-0000-4000-8000-000000000071',
  '71000000-0000-4000-8000-000000000061',
  'DB020 Material', 'Synthetic text',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.assignments (
  id, classroom_id, title, due_at, state, created_by, published_at
) values (
  '71000000-0000-4000-8000-000000000081',
  '71000000-0000-4000-8000-000000000051',
  'DB020 Assignment', '2026-09-20 12:00+00', 'published',
  '71000000-0000-4000-8000-000000000001', now()
);

insert into public.submissions (
  id, assignment_id, student_id, submitted_at, excused
) values (
  '71000000-0000-4000-8000-000000000091',
  '71000000-0000-4000-8000-000000000081',
  '71000000-0000-4000-8000-000000000031', null, true
);

insert into public.assessments (
  id, classroom_id, title, category, maximum_score, state, delivery,
  created_by, published_at
) values (
  '71000000-0000-4000-8000-0000000000a1',
  '71000000-0000-4000-8000-000000000051',
  'DB020 Assessment', 'quiz', 20, 'published', 'paper',
  '71000000-0000-4000-8000-000000000001', now()
);

insert into public.assessment_questions (
  id, assessment_id, position, prompt, maximum_score
) values (
  '71000000-0000-4000-8000-0000000000b1',
  '71000000-0000-4000-8000-0000000000a1', 1, 'Synthetic question', 20
);

insert into public.grade_results (
  id, assessment_id, student_id, score, state, reviewed_by, reviewed_at,
  published_at
) values (
  '71000000-0000-4000-8000-0000000000c1',
  '71000000-0000-4000-8000-0000000000a1',
  '71000000-0000-4000-8000-000000000031', 17, 'published',
  '71000000-0000-4000-8000-000000000001', now(), now()
);

insert into public.attendance_records (
  id, session_id, student_id, state, recorded_by
) values (
  '71000000-0000-4000-8000-0000000000d1',
  '71000000-0000-4000-8000-000000000061',
  '71000000-0000-4000-8000-000000000031', 'excused',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.wellbeing_events (
  id, student_id, classroom_id, kind, title, context, created_by
) values (
  '71000000-0000-4000-8000-0000000000e1',
  '71000000-0000-4000-8000-000000000031',
  '71000000-0000-4000-8000-000000000051',
  'note', 'DB020 wellbeing', 'Synthetic note',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.announcements (
  id, school_id, classroom_id, title, body, created_by
) values (
  '71000000-0000-4000-8000-0000000000f1',
  '71111111-1111-4111-8111-111111111111',
  '71000000-0000-4000-8000-000000000051',
  'DB020 announcement', 'Synthetic',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.meetings (
  id, classroom_id, title, starts_at, ends_at, audience, state, created_by
) values (
  '71000000-0000-4000-8000-000000000101',
  '71000000-0000-4000-8000-000000000051', 'DB020 meeting',
  '2026-09-12 08:00+00', '2026-09-12 09:00+00', 'students', 'scheduled',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.meeting_deliveries (
  meeting_id, recipient_id, state, delivered_at
) values (
  '71000000-0000-4000-8000-000000000101',
  '71000000-0000-4000-8000-000000000002', 'sent', now()
);

insert into public.notifications (
  id, user_id, kind, title, body
) values (
  '71000000-0000-4000-8000-000000000111',
  '71000000-0000-4000-8000-000000000002',
  'grade', 'DB020 notification', 'Synthetic'
);

insert into public.ai_grading_drafts (
  id, grade_result_id, private_scan_path, strictness, model_version,
  status, created_by
) values (
  '71000000-0000-4000-8000-000000000121',
  '71000000-0000-4000-8000-0000000000c1',
  'disabled/synthetic-only', 'balanced', 'disabled', 'ready',
  '71000000-0000-4000-8000-000000000001'
);

insert into public.question_suggestions (
  id, draft_id, question_id, proposed_score, confidence, rationale
) values (
  '71000000-0000-4000-8000-000000000131',
  '71000000-0000-4000-8000-000000000121',
  '71000000-0000-4000-8000-0000000000b1', 17, 0.8,
  'Synthetic rationale'
);

insert into public.subscription_entitlements (
  user_id, product_id, source, active
) values (
  '71000000-0000-4000-8000-000000000003',
  'synthetic.parent.monthly', 'app_store', true
);

insert into public.audit_events (
  school_id, actor_id, action, entity_type, entity_id
) values (
  '71111111-1111-4111-8111-111111111111',
  '71000000-0000-4000-8000-000000000001',
  'db020.legacy.seed', 'school',
  '71111111-1111-4111-8111-111111111111'
);

insert into public.practice_sessions (
  id, student_id, classroom_id, topic, kind, item_count, correct_count,
  completed_at
) values (
  '71000000-0000-4000-8000-000000000141',
  '71000000-0000-4000-8000-000000000031',
  '71000000-0000-4000-8000-000000000051',
  'Synthetic topic', 'quiz', 10, 8, now()
);

insert into public.consent_records (
  user_id, purpose, policy_version, locale
) values (
  '71000000-0000-4000-8000-000000000003',
  'terms_and_privacy', 'legacy-test', 'en'
);

insert into public.account_deletion_requests (
  id, user_id, state, execute_after
) values (
  '71000000-0000-4000-8000-000000000151',
  '71000000-0000-4000-8000-000000000003',
  'grace_period', now() + interval '14 days'
);
