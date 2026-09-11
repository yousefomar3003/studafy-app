-- DB-021 policy/feed indexes. These fill gaps found while explaining the RLS
-- predicates against the deterministic multi-school fixture. Existing DB-020
-- indexes are reused wherever their leading columns match the policy path.

create index db021_lesson_materials_session_visible
on public.lesson_materials (session_id, created_at, id)
where deleted_at is null;

create index db021_assessments_class_published
on public.assessments (classroom_id, scheduled_at, id)
where state = 'published' and deleted_at is null;

create index db021_wellbeing_student_timeline
on public.wellbeing_events (student_id, created_at desc, id desc);

create index db021_announcements_school_feed
on public.announcements (school_id, published_at desc, id desc)
where state = 'published' and deleted_at is null;

create index db021_meetings_class_time
on public.meetings (classroom_id, starts_at desc, id desc)
where state = 'scheduled';

create index db021_resource_publications_version_state
on public.resource_publications (resource_version_id, state, id)
where withdrawn_at is null;
