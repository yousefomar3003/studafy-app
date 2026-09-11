-- DB-020 validate step. Validated CHECK constraints let PostgreSQL make the
-- following SET NOT NULL operations without re-discovering invalid rows.

do $db020$
declare
  item record;
begin
  for item in
    select n.nspname as schema_name, c.relname as table_name, con.conname
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and con.conname like 'db020_%'
      and not con.convalidated
    order by c.relname, con.conname
  loop
    execute format(
      'alter table %I.%I validate constraint %I',
      item.schema_name,
      item.table_name,
      item.conname
    );
  end loop;
end
$db020$;

alter table public.schools
  alter column status set default 'provisioning',
  alter column status set not null,
  alter column locale set default 'en',
  alter column locale set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.profiles
  alter column status set default 'active',
  alter column status set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.memberships
  alter column status drop default,
  alter column status set not null,
  alter column valid_from set default now(),
  alter column valid_from set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.terms
  alter column status drop default,
  alter column status set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.students
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.guardian_links
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.classrooms
  alter column status drop default,
  alter column status set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.enrollments
  alter column school_id set not null,
  alter column status drop default,
  alter column status set not null,
  alter column starts_on set default current_date,
  alter column starts_on set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.lesson_sessions
  alter column school_id set not null,
  alter column status set default 'scheduled',
  alter column status set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.lesson_materials
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.assignments
  alter column school_id set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.submissions
  alter column school_id set not null,
  alter column status drop default,
  alter column status set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.assessments
  alter column school_id set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.assessment_questions
  alter column school_id set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.grade_results
  alter column school_id set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.attendance_records
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.wellbeing_events
  alter column school_id set not null,
  alter column visibility set default 'class_staff',
  alter column visibility set not null,
  alter column severity set default 'low',
  alter column severity set not null,
  alter column status set default 'open',
  alter column status set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.announcements
  alter column state set default 'published',
  alter column state set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.meetings
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.meeting_deliveries
  alter column school_id set not null,
  alter column attempt_count set default 0,
  alter column attempt_count set not null,
  alter column created_at set default now(),
  alter column created_at set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.notifications
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.ai_grading_drafts
  alter column school_id set not null,
  alter column version set default 1,
  alter column version set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.question_suggestions
  alter column school_id set not null,
  alter column created_at set default now(),
  alter column created_at set not null;

alter table public.subscription_entitlements
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.practice_sessions
  alter column school_id set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.consent_records
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.account_deletion_requests
  alter column version set default 1,
  alter column version set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

-- The product decision is exactly one current term for each school. Planned,
-- closed, and cancelled terms remain unrestricted.
create unique index db020_terms_one_active_per_school
on public.terms (school_id)
where status = 'active';
