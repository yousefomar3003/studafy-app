


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."app_role" AS ENUM (
    'teacher',
    'parent',
    'student'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."attendance_state" AS ENUM (
    'present',
    'absent',
    'late',
    'excused'
);


ALTER TYPE "public"."attendance_state" OWNER TO "postgres";


CREATE TYPE "public"."link_status" AS ENUM (
    'pending',
    'verified',
    'declined',
    'revoked'
);


ALTER TYPE "public"."link_status" OWNER TO "postgres";


CREATE TYPE "public"."meeting_audience" AS ENUM (
    'students',
    'guardians',
    'both'
);


ALTER TYPE "public"."meeting_audience" OWNER TO "postgres";


CREATE TYPE "public"."publication_state" AS ENUM (
    'draft',
    'reviewed',
    'published'
);


ALTER TYPE "public"."publication_state" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.classrooms c
    where c.id = target_classroom
      and (
        c.teacher_id = auth.uid()
        or exists (
          select 1
          from public.enrollments e
          join public.students s on s.id = e.student_id
          where e.classroom_id = c.id
            and e.active
            and s.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.enrollments e
          join public.guardian_links g on g.student_id = e.student_id
          where e.classroom_id = c.id
            and e.active
            and g.guardian_id = auth.uid()
            and g.status = 'verified'
        )
      )
  );
$$;


ALTER FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_access_student"("target_student" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.students s
    where s.id = target_student
      and (
        s.user_id = auth.uid()
        or exists (
          select 1 from public.guardian_links g
          where g.student_id = s.id
            and g.guardian_id = auth.uid()
            and g.status = 'verified'
        )
        or exists (
          select 1
          from public.enrollments e
          join public.classrooms c on c.id = e.classroom_id
          where e.student_id = s.id
            and e.active
            and c.teacher_id = auth.uid()
        )
      )
  );
$$;


ALTER FUNCTION "public"."can_access_student"("target_student" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  requested_locale text;
begin
  requested_locale := coalesce(new.raw_user_meta_data ->> 'locale', 'en');
  if requested_locale not in ('en', 'ar') then
    requested_locale := 'en';
  end if;

  insert into public.profiles (id, display_name, locale)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(new.email, 'Studafy user'), '@', 1)
    ),
    requested_locale
  )
  on conflict (id) do nothing;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_class_teacher"("target_classroom" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.classrooms c
    where c.id=target_classroom and c.teacher_id=auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_class_teacher"("target_classroom" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_school_member"("target_school" "uuid", "allowed_roles" "public"."app_role"[] DEFAULT NULL::"public"."app_role"[]) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.memberships m
    where m.school_id = target_school and m.user_id = auth.uid() and m.active
      and (allowed_roles is null or m.role = any(allowed_roles))
  );
$$;


ALTER FUNCTION "public"."is_school_member"("target_school" "uuid", "allowed_roles" "public"."app_role"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_policy_consent"("requested_purpose" "text", "requested_version" "text", "requested_locale" "text" DEFAULT 'en'::"text") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if requested_purpose not in ('terms_and_privacy', 'ai_features') then
    raise exception 'Unsupported consent purpose';
  end if;
  if requested_locale not in ('en', 'ar') then
    raise exception 'Unsupported locale';
  end if;

  insert into public.consent_records (
    user_id, purpose, policy_version, locale, accepted_at, withdrawn_at
  ) values (
    auth.uid(), requested_purpose, requested_version, requested_locale, now(), null
  )
  on conflict (user_id, purpose, policy_version)
  do update set accepted_at = excluded.accepted_at, withdrawn_at = null;
end;
$$;


ALTER FUNCTION "public"."record_policy_consent"("requested_purpose" "text", "requested_version" "text", "requested_locale" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."account_deletion_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "state" "text" DEFAULT 'grace_period'::"text" NOT NULL,
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "execute_after" timestamp with time zone DEFAULT ("now"() + '14 days'::interval) NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "account_deletion_requests_state_check" CHECK (("state" = ANY (ARRAY['grace_period'::"text", 'cancelled'::"text", 'executing'::"text", 'completed'::"text"])))
);


ALTER TABLE "public"."account_deletion_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ai_grading_drafts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "grade_result_id" "uuid" NOT NULL,
    "private_scan_path" "text" NOT NULL,
    "strictness" "text" NOT NULL,
    "model_version" "text" NOT NULL,
    "status" "text" DEFAULT 'processing'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "ai_grading_drafts_status_check" CHECK (("status" = ANY (ARRAY['processing'::"text", 'ready'::"text", 'failed'::"text", 'approved'::"text"]))),
    CONSTRAINT "ai_grading_drafts_strictness_check" CHECK (("strictness" = ANY (ARRAY['strict'::"text", 'balanced'::"text", 'lenient'::"text"])))
);


ALTER TABLE "public"."ai_grading_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "school_id" "uuid" NOT NULL,
    "classroom_id" "uuid",
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "audience" "public"."meeting_audience" DEFAULT 'both'::"public"."meeting_audience" NOT NULL,
    "important" boolean DEFAULT false NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" NOT NULL
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."assessment_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assessment_id" "uuid" NOT NULL,
    "position" integer NOT NULL,
    "prompt" "text" NOT NULL,
    "preferred_answer" "text",
    "maximum_score" numeric(8,2) NOT NULL,
    CONSTRAINT "assessment_questions_maximum_score_check" CHECK (("maximum_score" > (0)::numeric))
);


ALTER TABLE "public"."assessment_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."assessments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "classroom_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "category" "text" NOT NULL,
    "maximum_score" numeric(8,2) NOT NULL,
    "category_weight" numeric(5,2),
    "scheduled_at" timestamp with time zone,
    "state" "public"."publication_state" DEFAULT 'draft'::"public"."publication_state" NOT NULL,
    "delivery" "text" DEFAULT 'paper'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "published_at" timestamp with time zone,
    CONSTRAINT "assessments_delivery_check" CHECK (("delivery" = ANY (ARRAY['paper'::"text", 'practice'::"text"]))),
    CONSTRAINT "assessments_maximum_score_check" CHECK (("maximum_score" > (0)::numeric))
);


ALTER TABLE "public"."assessments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."assignments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "classroom_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "instructions" "text",
    "due_at" timestamp with time zone NOT NULL,
    "state" "public"."publication_state" DEFAULT 'draft'::"public"."publication_state" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "published_at" timestamp with time zone
);


ALTER TABLE "public"."assignments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attendance_records" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "state" "public"."attendance_state" NOT NULL,
    "reason" "text",
    "recorded_by" "uuid" NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."attendance_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."audit_events" (
    "id" bigint NOT NULL,
    "school_id" "uuid",
    "actor_id" "uuid",
    "action" "text" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "uuid",
    "before_value" "jsonb",
    "after_value" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."audit_events" OWNER TO "postgres";


ALTER TABLE "public"."audit_events" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."audit_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."classrooms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "school_id" "uuid" NOT NULL,
    "term_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "grade" "text",
    "section" "text",
    "teacher_id" "uuid" NOT NULL,
    "archived_at" timestamp with time zone
);


ALTER TABLE "public"."classrooms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."consent_records" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "purpose" "text" NOT NULL,
    "policy_version" "text" NOT NULL,
    "locale" "text" NOT NULL,
    "accepted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "withdrawn_at" timestamp with time zone,
    CONSTRAINT "consent_records_locale_check" CHECK (("locale" = ANY (ARRAY['en'::"text", 'ar'::"text"])))
);


ALTER TABLE "public"."consent_records" OWNER TO "postgres";


ALTER TABLE "public"."consent_records" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."consent_records_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."enrollments" (
    "classroom_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."enrollments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."grade_results" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assessment_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "score" numeric(8,2) NOT NULL,
    "state" "public"."publication_state" DEFAULT 'draft'::"public"."publication_state" NOT NULL,
    "feedback" "text",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "published_at" timestamp with time zone
);


ALTER TABLE "public"."grade_results" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."guardian_links" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "guardian_id" "uuid" NOT NULL,
    "status" "public"."link_status" DEFAULT 'pending'::"public"."link_status" NOT NULL,
    "relationship" "text",
    "verified_by" "uuid",
    "verified_at" timestamp with time zone
);


ALTER TABLE "public"."guardian_links" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lesson_materials" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text",
    "storage_path" "text",
    "media_type" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."lesson_materials" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."lesson_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "classroom_id" "uuid" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "title" "text",
    "filed_at" timestamp with time zone
);


ALTER TABLE "public"."lesson_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meeting_deliveries" (
    "meeting_id" "uuid" NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "state" "text" NOT NULL,
    "delivered_at" timestamp with time zone,
    "error" "text",
    CONSTRAINT "meeting_deliveries_state_check" CHECK (("state" = ANY (ARRAY['queued'::"text", 'sent'::"text", 'failed'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."meeting_deliveries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meetings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "classroom_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone NOT NULL,
    "audience" "public"."meeting_audience" NOT NULL,
    "calendar_event_id" "text",
    "meet_url" "text",
    "state" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "meetings_state_check" CHECK (("state" = ANY (ARRAY['pending'::"text", 'scheduled'::"text", 'cancelled'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."meetings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."memberships" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "school_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."app_role" NOT NULL,
    "active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."memberships" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "route" "text",
    "entity_id" "uuid",
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."practice_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "classroom_id" "uuid" NOT NULL,
    "topic" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "item_count" integer NOT NULL,
    "correct_count" integer,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "practice_sessions_item_count_check" CHECK (("item_count" > 0)),
    CONSTRAINT "practice_sessions_kind_check" CHECK (("kind" = ANY (ARRAY['quiz'::"text", 'flashcards'::"text"])))
);


ALTER TABLE "public"."practice_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "display_name" "text" NOT NULL,
    "locale" "text" DEFAULT 'en'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "profiles_locale_check" CHECK (("locale" = ANY (ARRAY['en'::"text", 'ar'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."question_suggestions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "draft_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "proposed_score" numeric(8,2) NOT NULL,
    "confidence" numeric(5,4) NOT NULL,
    "rationale" "text" NOT NULL,
    "teacher_score" numeric(8,2),
    "override_reason" "text",
    CONSTRAINT "question_suggestions_confidence_check" CHECK ((("confidence" >= (0)::numeric) AND ("confidence" <= (1)::numeric)))
);


ALTER TABLE "public"."question_suggestions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."schools" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "timezone" "text" DEFAULT 'Asia/Riyadh'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."schools" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."students" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "school_id" "uuid",
    "user_id" "uuid",
    "studafy_id" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "provisional" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."students" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."submissions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "assignment_id" "uuid" NOT NULL,
    "student_id" "uuid" NOT NULL,
    "submitted_at" timestamp with time zone,
    "excused" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."subscription_entitlements" (
    "user_id" "uuid" NOT NULL,
    "product_id" "text" NOT NULL,
    "source" "text" NOT NULL,
    "active" boolean DEFAULT false NOT NULL,
    "expires_at" timestamp with time zone,
    "verified_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "subscription_entitlements_source_check" CHECK (("source" = ANY (ARRAY['app_store'::"text", 'play_store'::"text", 'school'::"text"])))
);


ALTER TABLE "public"."subscription_entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."terms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "school_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "starts_on" "date" NOT NULL,
    "ends_on" "date" NOT NULL,
    "active" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."terms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wellbeing_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "student_id" "uuid" NOT NULL,
    "classroom_id" "uuid",
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "context" "text",
    "follow_up" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "wellbeing_events_kind_check" CHECK (("kind" = ANY (ARRAY['strength'::"text", 'concern'::"text", 'note'::"text"])))
);


ALTER TABLE "public"."wellbeing_events" OWNER TO "postgres";


ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_user_id_state_key" UNIQUE ("user_id", "state");



ALTER TABLE ONLY "public"."ai_grading_drafts"
    ADD CONSTRAINT "ai_grading_drafts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."assessment_questions"
    ADD CONSTRAINT "assessment_questions_assessment_id_position_key" UNIQUE ("assessment_id", "position");



ALTER TABLE ONLY "public"."assessment_questions"
    ADD CONSTRAINT "assessment_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."assignments"
    ADD CONSTRAINT "assignments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_session_id_student_id_key" UNIQUE ("session_id", "student_id");



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."classrooms"
    ADD CONSTRAINT "classrooms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."consent_records"
    ADD CONSTRAINT "consent_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."consent_records"
    ADD CONSTRAINT "consent_records_user_id_purpose_policy_version_key" UNIQUE ("user_id", "purpose", "policy_version");



ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_pkey" PRIMARY KEY ("classroom_id", "student_id");



ALTER TABLE ONLY "public"."grade_results"
    ADD CONSTRAINT "grade_results_assessment_id_student_id_key" UNIQUE ("assessment_id", "student_id");



ALTER TABLE ONLY "public"."grade_results"
    ADD CONSTRAINT "grade_results_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guardian_links"
    ADD CONSTRAINT "guardian_links_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."guardian_links"
    ADD CONSTRAINT "guardian_links_student_id_guardian_id_key" UNIQUE ("student_id", "guardian_id");



ALTER TABLE ONLY "public"."lesson_materials"
    ADD CONSTRAINT "lesson_materials_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."lesson_sessions"
    ADD CONSTRAINT "lesson_sessions_classroom_id_starts_at_key" UNIQUE ("classroom_id", "starts_at");



ALTER TABLE ONLY "public"."lesson_sessions"
    ADD CONSTRAINT "lesson_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meeting_deliveries"
    ADD CONSTRAINT "meeting_deliveries_pkey" PRIMARY KEY ("meeting_id", "recipient_id");



ALTER TABLE ONLY "public"."meetings"
    ADD CONSTRAINT "meetings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_school_id_user_id_role_key" UNIQUE ("school_id", "user_id", "role");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."practice_sessions"
    ADD CONSTRAINT "practice_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."question_suggestions"
    ADD CONSTRAINT "question_suggestions_draft_id_question_id_key" UNIQUE ("draft_id", "question_id");



ALTER TABLE ONLY "public"."question_suggestions"
    ADD CONSTRAINT "question_suggestions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."schools"
    ADD CONSTRAINT "schools_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_studafy_id_key" UNIQUE ("studafy_id");



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_assignment_id_student_id_key" UNIQUE ("assignment_id", "student_id");



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."subscription_entitlements"
    ADD CONSTRAINT "subscription_entitlements_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."terms"
    ADD CONSTRAINT "terms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."terms"
    ADD CONSTRAINT "terms_school_id_name_key" UNIQUE ("school_id", "name");



ALTER TABLE ONLY "public"."wellbeing_events"
    ADD CONSTRAINT "wellbeing_events_pkey" PRIMARY KEY ("id");



CREATE INDEX "account_deletion_due_idx" ON "public"."account_deletion_requests" USING "btree" ("execute_after") WHERE ("state" = 'grace_period'::"text");



CREATE INDEX "meeting_deliveries_recipient_idx" ON "public"."meeting_deliveries" USING "btree" ("recipient_id", "state");



ALTER TABLE ONLY "public"."account_deletion_requests"
    ADD CONSTRAINT "account_deletion_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ai_grading_drafts"
    ADD CONSTRAINT "ai_grading_drafts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."ai_grading_drafts"
    ADD CONSTRAINT "ai_grading_drafts_grade_result_id_fkey" FOREIGN KEY ("grade_result_id") REFERENCES "public"."grade_results"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assessment_questions"
    ADD CONSTRAINT "assessment_questions_assessment_id_fkey" FOREIGN KEY ("assessment_id") REFERENCES "public"."assessments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assessments"
    ADD CONSTRAINT "assessments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."assignments"
    ADD CONSTRAINT "assignments_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."assignments"
    ADD CONSTRAINT "assignments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_recorded_by_fkey" FOREIGN KEY ("recorded_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."lesson_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance_records"
    ADD CONSTRAINT "attendance_records_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."audit_events"
    ADD CONSTRAINT "audit_events_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."classrooms"
    ADD CONSTRAINT "classrooms_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."classrooms"
    ADD CONSTRAINT "classrooms_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."classrooms"
    ADD CONSTRAINT "classrooms_term_id_fkey" FOREIGN KEY ("term_id") REFERENCES "public"."terms"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."consent_records"
    ADD CONSTRAINT "consent_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."enrollments"
    ADD CONSTRAINT "enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."grade_results"
    ADD CONSTRAINT "grade_results_assessment_id_fkey" FOREIGN KEY ("assessment_id") REFERENCES "public"."assessments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."grade_results"
    ADD CONSTRAINT "grade_results_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."grade_results"
    ADD CONSTRAINT "grade_results_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guardian_links"
    ADD CONSTRAINT "guardian_links_guardian_id_fkey" FOREIGN KEY ("guardian_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guardian_links"
    ADD CONSTRAINT "guardian_links_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."guardian_links"
    ADD CONSTRAINT "guardian_links_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."lesson_materials"
    ADD CONSTRAINT "lesson_materials_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."lesson_materials"
    ADD CONSTRAINT "lesson_materials_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."lesson_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."lesson_sessions"
    ADD CONSTRAINT "lesson_sessions_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meeting_deliveries"
    ADD CONSTRAINT "meeting_deliveries_meeting_id_fkey" FOREIGN KEY ("meeting_id") REFERENCES "public"."meetings"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meeting_deliveries"
    ADD CONSTRAINT "meeting_deliveries_recipient_id_fkey" FOREIGN KEY ("recipient_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meetings"
    ADD CONSTRAINT "meetings_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."meetings"
    ADD CONSTRAINT "meetings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."memberships"
    ADD CONSTRAINT "memberships_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_sessions"
    ADD CONSTRAINT "practice_sessions_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."practice_sessions"
    ADD CONSTRAINT "practice_sessions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."question_suggestions"
    ADD CONSTRAINT "question_suggestions_draft_id_fkey" FOREIGN KEY ("draft_id") REFERENCES "public"."ai_grading_drafts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."question_suggestions"
    ADD CONSTRAINT "question_suggestions_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."assessment_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."students"
    ADD CONSTRAINT "students_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_assignment_id_fkey" FOREIGN KEY ("assignment_id") REFERENCES "public"."assignments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."submissions"
    ADD CONSTRAINT "submissions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."subscription_entitlements"
    ADD CONSTRAINT "subscription_entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."terms"
    ADD CONSTRAINT "terms_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wellbeing_events"
    ADD CONSTRAINT "wellbeing_events_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "public"."classrooms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."wellbeing_events"
    ADD CONSTRAINT "wellbeing_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."wellbeing_events"
    ADD CONSTRAINT "wellbeing_events_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE CASCADE;



ALTER TABLE "public"."account_deletion_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."ai_grading_drafts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcements read audience" ON "public"."announcements" FOR SELECT USING (("public"."is_school_member"("school_id") AND (("classroom_id" IS NULL) OR "public"."can_access_classroom"("classroom_id")) AND (("created_by" = "auth"."uid"()) OR (("audience" = ANY (ARRAY['students'::"public"."meeting_audience", 'both'::"public"."meeting_audience"])) AND (EXISTS ( SELECT 1
   FROM "public"."students" "s"
  WHERE (("s"."school_id" = "announcements"."school_id") AND ("s"."user_id" = "auth"."uid"()))))) OR (("audience" = ANY (ARRAY['guardians'::"public"."meeting_audience", 'both'::"public"."meeting_audience"])) AND (EXISTS ( SELECT 1
   FROM ("public"."guardian_links" "g"
     JOIN "public"."students" "s" ON (("s"."id" = "g"."student_id")))
  WHERE (("s"."school_id" = "announcements"."school_id") AND ("g"."guardian_id" = "auth"."uid"()) AND ("g"."status" = 'verified'::"public"."link_status"))))))));



CREATE POLICY "assessment questions teacher or practice" ON "public"."assessment_questions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."assessments" "a"
  WHERE (("a"."id" = "assessment_questions"."assessment_id") AND "public"."can_access_classroom"("a"."classroom_id") AND ("public"."is_class_teacher"("a"."classroom_id") OR (("a"."delivery" = 'practice'::"text") AND ("a"."state" = 'published'::"public"."publication_state")))))));



ALTER TABLE "public"."assessment_questions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."assessments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "assessments read authorized" ON "public"."assessments" FOR SELECT USING (("public"."can_access_classroom"("classroom_id") AND (("state" = 'published'::"public"."publication_state") OR "public"."is_class_teacher"("classroom_id"))));



ALTER TABLE "public"."assignments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "assignments read authorized" ON "public"."assignments" FOR SELECT USING (("public"."can_access_classroom"("classroom_id") AND (("state" = 'published'::"public"."publication_state") OR "public"."is_class_teacher"("classroom_id"))));



CREATE POLICY "attendance read authorized" ON "public"."attendance_records" FOR SELECT USING ("public"."can_access_student"("student_id"));



ALTER TABLE "public"."attendance_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "audit actors read own" ON "public"."audit_events" FOR SELECT USING (("actor_id" = "auth"."uid"()));



ALTER TABLE "public"."audit_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."classrooms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "classrooms read authorized" ON "public"."classrooms" FOR SELECT USING ("public"."can_access_classroom"("id"));



CREATE POLICY "consent insert own" ON "public"."consent_records" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "consent read own" ON "public"."consent_records" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "consent update own" ON "public"."consent_records" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."consent_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "deletion requests own" ON "public"."account_deletion_requests" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."enrollments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "enrollments read authorized" ON "public"."enrollments" FOR SELECT USING ("public"."can_access_classroom"("classroom_id"));



CREATE POLICY "entitlements read own" ON "public"."subscription_entitlements" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."grade_results" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "grades read published authorized" ON "public"."grade_results" FOR SELECT USING ((("state" = 'published'::"public"."publication_state") AND "public"."can_access_student"("student_id")));



CREATE POLICY "grading drafts teacher only" ON "public"."ai_grading_drafts" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."grade_results" "g"
     JOIN "public"."assessments" "a" ON (("a"."id" = "g"."assessment_id")))
  WHERE (("g"."id" = "ai_grading_drafts"."grade_result_id") AND "public"."is_class_teacher"("a"."classroom_id")))));



ALTER TABLE "public"."guardian_links" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "guardians read own links" ON "public"."guardian_links" FOR SELECT USING ((("guardian_id" = "auth"."uid"()) OR "public"."can_access_student"("student_id")));



CREATE POLICY "guardians request link" ON "public"."guardian_links" FOR INSERT WITH CHECK ((("guardian_id" = "auth"."uid"()) AND ("status" = 'pending'::"public"."link_status")));



ALTER TABLE "public"."lesson_materials" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."lesson_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "materials read authorized" ON "public"."lesson_materials" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."lesson_sessions" "s"
  WHERE (("s"."id" = "lesson_materials"."session_id") AND "public"."can_access_classroom"("s"."classroom_id") AND (("s"."filed_at" IS NOT NULL) OR "public"."is_class_teacher"("s"."classroom_id"))))));



CREATE POLICY "meeting deliveries own or teacher" ON "public"."meeting_deliveries" FOR SELECT USING ((("recipient_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."meetings" "m"
  WHERE (("m"."id" = "meeting_deliveries"."meeting_id") AND "public"."is_class_teacher"("m"."classroom_id"))))));



ALTER TABLE "public"."meeting_deliveries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meetings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "meetings read authorized" ON "public"."meetings" FOR SELECT USING (("public"."can_access_classroom"("classroom_id") AND (("created_by" = "auth"."uid"()) OR (("audience" = ANY (ARRAY['students'::"public"."meeting_audience", 'both'::"public"."meeting_audience"])) AND (EXISTS ( SELECT 1
   FROM ("public"."enrollments" "e"
     JOIN "public"."students" "s" ON (("s"."id" = "e"."student_id")))
  WHERE (("e"."classroom_id" = "meetings"."classroom_id") AND "e"."active" AND ("s"."user_id" = "auth"."uid"()))))) OR (("audience" = ANY (ARRAY['guardians'::"public"."meeting_audience", 'both'::"public"."meeting_audience"])) AND (EXISTS ( SELECT 1
   FROM ("public"."enrollments" "e"
     JOIN "public"."guardian_links" "g" ON (("g"."student_id" = "e"."student_id")))
  WHERE (("e"."classroom_id" = "meetings"."classroom_id") AND "e"."active" AND ("g"."guardian_id" = "auth"."uid"()) AND ("g"."status" = 'verified'::"public"."link_status"))))))));



ALTER TABLE "public"."memberships" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "memberships read self" ON "public"."memberships" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications read own" ON "public"."notifications" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications update own" ON "public"."notifications" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "practice own" ON "public"."practice_sessions" FOR SELECT USING ("public"."can_access_student"("student_id"));



ALTER TABLE "public"."practice_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles read self" ON "public"."profiles" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "profiles update self" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"())) WITH CHECK (("id" = "auth"."uid"()));



ALTER TABLE "public"."question_suggestions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."schools" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "schools read memberships" ON "public"."schools" FOR SELECT USING ("public"."is_school_member"("id"));



CREATE POLICY "sessions read authorized" ON "public"."lesson_sessions" FOR SELECT USING ("public"."can_access_classroom"("classroom_id"));



ALTER TABLE "public"."students" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "students read authorized" ON "public"."students" FOR SELECT USING ("public"."can_access_student"("id"));



CREATE POLICY "students submit own work" ON "public"."submissions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM (("public"."students" "s"
     JOIN "public"."assignments" "a" ON (("a"."id" = "submissions"."assignment_id")))
     JOIN "public"."enrollments" "e" ON ((("e"."classroom_id" = "a"."classroom_id") AND ("e"."student_id" = "s"."id"))))
  WHERE (("s"."id" = "e"."student_id") AND ("s"."user_id" = "auth"."uid"()) AND "e"."active" AND ("a"."state" = 'published'::"public"."publication_state")))));



CREATE POLICY "students update own work" ON "public"."submissions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."students" "s"
  WHERE (("s"."id" = "submissions"."student_id") AND ("s"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."students" "s"
  WHERE (("s"."id" = "submissions"."student_id") AND ("s"."user_id" = "auth"."uid"())))));



ALTER TABLE "public"."submissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "submissions read authorized" ON "public"."submissions" FOR SELECT USING ("public"."can_access_student"("student_id"));



ALTER TABLE "public"."subscription_entitlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "suggestions teacher only" ON "public"."question_suggestions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM (("public"."ai_grading_drafts" "d"
     JOIN "public"."grade_results" "g" ON (("g"."id" = "d"."grade_result_id")))
     JOIN "public"."assessments" "a" ON (("a"."id" = "g"."assessment_id")))
  WHERE (("d"."id" = "question_suggestions"."draft_id") AND "public"."is_class_teacher"("a"."classroom_id")))));



CREATE POLICY "teachers create assignment drafts" ON "public"."assignments" FOR INSERT WITH CHECK ((("created_by" = "auth"."uid"()) AND ("state" = 'draft'::"public"."publication_state") AND "public"."is_class_teacher"("classroom_id")));



CREATE POLICY "teachers create own class sessions" ON "public"."lesson_sessions" FOR INSERT WITH CHECK ("public"."is_class_teacher"("classroom_id"));



CREATE POLICY "teachers create own materials" ON "public"."lesson_materials" FOR INSERT WITH CHECK ((("created_by" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."lesson_sessions" "s"
  WHERE (("s"."id" = "lesson_materials"."session_id") AND "public"."is_class_teacher"("s"."classroom_id"))))));



CREATE POLICY "teachers edit assignment drafts" ON "public"."assignments" FOR UPDATE USING ((("created_by" = "auth"."uid"()) AND ("state" = 'draft'::"public"."publication_state") AND "public"."is_class_teacher"("classroom_id"))) WITH CHECK ((("created_by" = "auth"."uid"()) AND ("state" = 'draft'::"public"."publication_state") AND "public"."is_class_teacher"("classroom_id")));



CREATE POLICY "teachers update own class sessions" ON "public"."lesson_sessions" FOR UPDATE USING ("public"."is_class_teacher"("classroom_id")) WITH CHECK ("public"."is_class_teacher"("classroom_id"));



ALTER TABLE "public"."terms" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "terms read memberships" ON "public"."terms" FOR SELECT USING ("public"."is_school_member"("school_id"));



CREATE POLICY "wellbeing read authorized" ON "public"."wellbeing_events" FOR SELECT USING ("public"."can_access_student"("student_id"));



ALTER TABLE "public"."wellbeing_events" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































REVOKE ALL ON FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_access_classroom"("target_classroom" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_access_student"("target_student" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_access_student"("target_student" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."can_access_student"("target_student" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_access_student"("target_student" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_class_teacher"("target_classroom" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_class_teacher"("target_classroom" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_class_teacher"("target_classroom" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_school_member"("target_school" "uuid", "allowed_roles" "public"."app_role"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."is_school_member"("target_school" "uuid", "allowed_roles" "public"."app_role"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_school_member"("target_school" "uuid", "allowed_roles" "public"."app_role"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."record_policy_consent"("requested_purpose" "text", "requested_version" "text", "requested_locale" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."record_policy_consent"("requested_purpose" "text", "requested_version" "text", "requested_locale" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_policy_consent"("requested_purpose" "text", "requested_version" "text", "requested_locale" "text") TO "service_role";


















GRANT ALL ON TABLE "public"."account_deletion_requests" TO "anon";
GRANT ALL ON TABLE "public"."account_deletion_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."account_deletion_requests" TO "service_role";



GRANT ALL ON TABLE "public"."ai_grading_drafts" TO "service_role";
GRANT SELECT ON TABLE "public"."ai_grading_drafts" TO "authenticated";



GRANT ALL ON TABLE "public"."announcements" TO "anon";
GRANT ALL ON TABLE "public"."announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."announcements" TO "service_role";



GRANT ALL ON TABLE "public"."assessment_questions" TO "anon";
GRANT ALL ON TABLE "public"."assessment_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."assessment_questions" TO "service_role";



GRANT ALL ON TABLE "public"."assessments" TO "anon";
GRANT ALL ON TABLE "public"."assessments" TO "authenticated";
GRANT ALL ON TABLE "public"."assessments" TO "service_role";



GRANT ALL ON TABLE "public"."assignments" TO "anon";
GRANT ALL ON TABLE "public"."assignments" TO "authenticated";
GRANT ALL ON TABLE "public"."assignments" TO "service_role";



GRANT ALL ON TABLE "public"."attendance_records" TO "anon";
GRANT ALL ON TABLE "public"."attendance_records" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance_records" TO "service_role";



GRANT ALL ON TABLE "public"."audit_events" TO "anon";
GRANT ALL ON TABLE "public"."audit_events" TO "authenticated";
GRANT ALL ON TABLE "public"."audit_events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."audit_events_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."classrooms" TO "anon";
GRANT ALL ON TABLE "public"."classrooms" TO "authenticated";
GRANT ALL ON TABLE "public"."classrooms" TO "service_role";



GRANT ALL ON TABLE "public"."consent_records" TO "anon";
GRANT ALL ON TABLE "public"."consent_records" TO "authenticated";
GRANT ALL ON TABLE "public"."consent_records" TO "service_role";



GRANT ALL ON SEQUENCE "public"."consent_records_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."consent_records_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."consent_records_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."enrollments" TO "anon";
GRANT ALL ON TABLE "public"."enrollments" TO "authenticated";
GRANT ALL ON TABLE "public"."enrollments" TO "service_role";



GRANT ALL ON TABLE "public"."grade_results" TO "anon";
GRANT ALL ON TABLE "public"."grade_results" TO "authenticated";
GRANT ALL ON TABLE "public"."grade_results" TO "service_role";



GRANT ALL ON TABLE "public"."guardian_links" TO "anon";
GRANT ALL ON TABLE "public"."guardian_links" TO "authenticated";
GRANT ALL ON TABLE "public"."guardian_links" TO "service_role";



GRANT ALL ON TABLE "public"."lesson_materials" TO "anon";
GRANT ALL ON TABLE "public"."lesson_materials" TO "authenticated";
GRANT ALL ON TABLE "public"."lesson_materials" TO "service_role";



GRANT ALL ON TABLE "public"."lesson_sessions" TO "anon";
GRANT ALL ON TABLE "public"."lesson_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."lesson_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."meeting_deliveries" TO "anon";
GRANT ALL ON TABLE "public"."meeting_deliveries" TO "authenticated";
GRANT ALL ON TABLE "public"."meeting_deliveries" TO "service_role";



GRANT ALL ON TABLE "public"."meetings" TO "anon";
GRANT ALL ON TABLE "public"."meetings" TO "authenticated";
GRANT ALL ON TABLE "public"."meetings" TO "service_role";



GRANT ALL ON TABLE "public"."memberships" TO "anon";
GRANT ALL ON TABLE "public"."memberships" TO "authenticated";
GRANT ALL ON TABLE "public"."memberships" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."practice_sessions" TO "anon";
GRANT ALL ON TABLE "public"."practice_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."practice_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."question_suggestions" TO "service_role";
GRANT SELECT ON TABLE "public"."question_suggestions" TO "authenticated";



GRANT ALL ON TABLE "public"."schools" TO "anon";
GRANT ALL ON TABLE "public"."schools" TO "authenticated";
GRANT ALL ON TABLE "public"."schools" TO "service_role";



GRANT ALL ON TABLE "public"."students" TO "anon";
GRANT ALL ON TABLE "public"."students" TO "authenticated";
GRANT ALL ON TABLE "public"."students" TO "service_role";



GRANT ALL ON TABLE "public"."submissions" TO "anon";
GRANT ALL ON TABLE "public"."submissions" TO "authenticated";
GRANT ALL ON TABLE "public"."submissions" TO "service_role";



GRANT ALL ON TABLE "public"."subscription_entitlements" TO "anon";
GRANT ALL ON TABLE "public"."subscription_entitlements" TO "authenticated";
GRANT ALL ON TABLE "public"."subscription_entitlements" TO "service_role";



GRANT ALL ON TABLE "public"."terms" TO "anon";
GRANT ALL ON TABLE "public"."terms" TO "authenticated";
GRANT ALL ON TABLE "public"."terms" TO "service_role";



GRANT ALL ON TABLE "public"."wellbeing_events" TO "anon";
GRANT ALL ON TABLE "public"."wellbeing_events" TO "authenticated";
GRANT ALL ON TABLE "public"."wellbeing_events" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































