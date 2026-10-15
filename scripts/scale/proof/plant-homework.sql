-- Homework extras the synthetic data lacks, so the fix 3 proof compares
-- every field: closing times, links (one detached, one for results),
-- material files (one deleted, one detached), extensions (one revoked),
-- and homework marked through a published assessment. Runs inside the
-- differential's transaction and is rolled back with it.
update public.assignments set closes_at = due_at + interval '2 days'
  where abs(hashtext(id::text)) % 5 = 0 and due_at is not null;

insert into public.content_links (school_id, title, url, role, position, assignment_id, created_by)
select a.school_id, 'Link ' || n, 'https://example.org/' || a.id || '/' || n,
  case when n = 3 then 'results' else 'material' end, 3 - n, a.id, a.created_by
from public.assignments a cross join generate_series(1, 3) n
where abs(hashtext(a.id::text)) % 7 = 0;
update public.content_links set detached_at = now(), detached_by = created_by
  where role = 'material' and position = 1 and abs(hashtext(id::text)) % 2 = 0;

insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name)
select gen_random_uuid(), a.school_id, 'legacy', 'files/plant/' || a.id || '/' || n, a.created_by,
  10 * n, 'application/pdf', repeat(n::text, 64), 'clean', now(), a.created_by,
  'assignment_material', 'Sheet ' || n || '.pdf'
from public.assignments a cross join generate_series(1, 3) n
where abs(hashtext(a.id::text)) % 11 = 0;
insert into public.file_bindings (school_id, file_object_id, assignment_id, role)
select fo.school_id, fo.id, split_part(fo.object_key, '/', 3)::uuid, 'material'
from public.file_objects fo where fo.object_key like 'files/plant/%';
update public.file_objects set deleted_at = now()
  where object_key like 'files/plant/%/2';
update public.file_bindings b set detached_at = now()
  from public.file_objects fo
  where fo.id = b.file_object_id and fo.object_key like 'files/plant/%/3'
    and abs(hashtext(fo.id::text)) % 2 = 0;

insert into public.assignment_extensions (school_id, assignment_id, student_id, extended_until, reason, granted_by)
select a.school_id, a.id, e.student_id, greatest(coalesce(a.due_at, now()), now()) + interval '3 days', 'Planted', a.created_by
from public.assignments a
join public.enrollments e on e.classroom_id = a.classroom_id
where abs(hashtext(a.id::text || e.student_id::text)) % 9 = 0;
update public.assignment_extensions set revoked_at = now(), revoked_by = granted_by
  where reason = 'Planted' and abs(hashtext(id::text)) % 4 = 0;

-- Homework marked through an assessment, with some marks published.
insert into public.assessments (school_id, classroom_id, title, category, maximum_score, scheduled_at,
  state, delivery, created_by, published_at, assignment_id)
select a.school_id, a.classroom_id, 'Marked ' || a.title, 'homework', 20, coalesce(a.due_at, now()),
  'published', 'paper', a.created_by, now() - interval '1 day', a.id
from public.assignments a
where abs(hashtext(a.id::text)) % 13 = 0 and a.deleted_at is null;
insert into public.grade_results (assessment_id, student_id, score, state, reviewed_by, reviewed_at, published_at)
select s.id, e.student_id, 15, 'published', s.created_by, now() - interval '1 day', now() - interval '1 day'
from public.assessments s
join public.enrollments e on e.classroom_id = s.classroom_id
where s.title like 'Marked %' and abs(hashtext(s.id::text || e.student_id::text)) % 2 = 0;

-- The planner must see the planted rows, or every per-row lookup it plans
-- for an "empty" table turns into a full scan.
analyze public.assignments, public.content_links, public.file_objects, public.file_bindings,
  public.assignment_extensions, public.assessments, public.grade_results;
