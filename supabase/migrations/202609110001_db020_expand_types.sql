-- DB-020 expand step: additive lifecycle types only. Existing enum values are
-- retained so previously deployed clients remain compatible.
alter type public.app_role add value if not exists 'school_admin' before 'teacher';
alter type public.app_role add value if not exists 'guardian' after 'parent';

create type public.school_status as enum (
  'provisioning', 'active', 'suspended', 'closed'
);
create type public.profile_status as enum (
  'active', 'suspended', 'deletion_pending', 'deleted'
);
create type public.membership_status as enum (
  'invited', 'active', 'suspended', 'revoked', 'expired'
);
create type public.term_status as enum (
  'planned', 'active', 'closed', 'cancelled'
);
create type public.classroom_status as enum (
  'draft', 'active', 'archived'
);
create type public.enrollment_status as enum (
  'invited', 'active', 'withdrawn', 'completed'
);
create type public.classroom_staff_role as enum (
  'lead_teacher', 'co_teacher', 'assistant'
);
create type public.staff_assignment_status as enum ('active', 'ended');
create type public.lesson_session_status as enum (
  'scheduled', 'completed', 'cancelled'
);
create type public.resource_state as enum (
  'draft', 'published', 'withdrawn', 'archived'
);
create type public.submission_status as enum (
  'open', 'submitted', 'excused', 'withdrawn'
);
create type public.wellbeing_visibility as enum (
  'class_staff',
  'guardian_shared',
  'student_guardian_shared',
  'safeguarding_restricted'
);
create type public.conversation_state as enum ('active', 'archived', 'closed');
create type public.file_scan_state as enum (
  'quarantined', 'scanning', 'clean', 'rejected', 'error', 'deleted'
);
create type public.upload_session_state as enum (
  'initiated', 'uploaded', 'completed', 'expired', 'cancelled'
);
create type public.outbox_state as enum (
  'pending', 'processing', 'retry', 'completed', 'dead_letter', 'cancelled'
);
create type public.delivery_state as enum (
  'pending', 'sent', 'retry', 'failed', 'cancelled'
);
create type public.store_platform as enum ('app_store', 'play_store', 'school');
create type public.store_transaction_state as enum (
  'pending',
  'active',
  'grace_period',
  'on_hold',
  'refunded',
  'revoked',
  'expired'
);
create type public.entitlement_status as enum (
  'pending', 'active', 'grace_period', 'on_hold', 'revoked', 'expired'
);
