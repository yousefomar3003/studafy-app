-- Synthetic prior-version fixture loaded after reset through DB-020 only.

insert into auth.users (
  id, email, encrypted_password, aud, role, email_confirmed_at, created_at,
  updated_at, instance_id, confirmation_token, recovery_token, email_change,
  email_change_token_new, email_change_token_current, phone_change_token,
  raw_app_meta_data, raw_user_meta_data
) values
  ('b0210000-0000-4000-8000-000000000001', 'upgrade.teacher@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Upgrade Teacher"}'::jsonb),
  ('b0210000-0000-4000-8000-000000000002', 'upgrade.student@synthetic.studafy.test', 'synthetic-not-a-secret', 'authenticated', 'authenticated', now(), now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '', '{}'::jsonb, '{"full_name":"Upgrade Student"}'::jsonb)
on conflict (id) do nothing;

insert into public.schools (id,name,status) values
  ('b0211000-0000-4000-8000-000000000001','DB-021 Upgrade School','active');
insert into public.memberships (id,school_id,user_id,role,active) values
  ('b0212000-0000-4000-8000-000000000001','b0211000-0000-4000-8000-000000000001','b0210000-0000-4000-8000-000000000001','teacher',true),
  ('b0212000-0000-4000-8000-000000000002','b0211000-0000-4000-8000-000000000001','b0210000-0000-4000-8000-000000000002','student',true);
insert into public.terms (
  id,school_id,name,starts_on,ends_on,active
) values (
  'b0213000-0000-4000-8000-000000000001',
  'b0211000-0000-4000-8000-000000000001',
  'Upgrade Term','2026-09-01','2026-12-31',true
);
insert into public.students (
  id,school_id,user_id,studafy_id,display_name,provisional,created_by
) values (
  'b0214000-0000-4000-8000-000000000001',
  'b0211000-0000-4000-8000-000000000001',
  'b0210000-0000-4000-8000-000000000002',
  'STU-DB021-UPGRADE','Upgrade Student',false,
  'b0210000-0000-4000-8000-000000000001'
);
insert into public.classrooms (
  id,school_id,term_id,name,teacher_id
) values (
  'b0215000-0000-4000-8000-000000000001',
  'b0211000-0000-4000-8000-000000000001',
  'b0213000-0000-4000-8000-000000000001',
  'Upgrade Classroom','b0210000-0000-4000-8000-000000000001'
);
insert into public.classroom_staff (
  school_id,classroom_id,membership_id,user_id,role
) values (
  'b0211000-0000-4000-8000-000000000001',
  'b0215000-0000-4000-8000-000000000001',
  'b0212000-0000-4000-8000-000000000001',
  'b0210000-0000-4000-8000-000000000001','lead_teacher'
);
insert into public.enrollments (classroom_id,student_id,active) values (
  'b0215000-0000-4000-8000-000000000001',
  'b0214000-0000-4000-8000-000000000001',true
);
insert into public.notifications (
  id,school_id,user_id,kind,title,body
) values (
  'b0216000-0000-4000-8000-000000000001',
  'b0211000-0000-4000-8000-000000000001',
  'b0210000-0000-4000-8000-000000000002',
  'upgrade','Upgrade notification','Synthetic'
);
