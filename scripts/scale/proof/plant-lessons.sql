-- Lesson extras the synthetic data lacks, so the fix 4 proof compares
-- every field of a lesson: a newer current version with its own file, a
-- version that is not current, files bound as material (one deleted, one
-- detached, one bound for results, the version's own file bound again),
-- links (one detached, one for results, two at the same position), a newer
-- and an older publication, drafts, deleted lessons, a lesson whose current
-- version is missing, and a teacher's unpublished lesson. Runs inside the
-- differential's transaction and is rolled back with it.
--
-- :lesson_every picks how many lessons get an extra (1 = every lesson, for
-- the pgTAP fixtures; the scale data uses 5). Each picked lesson gets the
-- case its id hashes to, so every case is planted on any sizeable sample.
\if :{?lesson_every} \else \set lesson_every 5 \endif

-- The pgTAP fixtures hold only a couple of lessons; -v seed_lessons=1 first
-- copies each one twelve times (its title, version and latest publication),
-- so every case below is planted on them.
\if :{?seed_lessons}
create temp table seed_copies as
select r.id as source, ('0000' || substr(md5(r.id::text || ':copy:' || k), 5))::uuid as id,
  r.school_id, r.title, r.resource_type, r.state, r.created_by, rv.body, k
from public.resources r
join public.resource_versions rv on rv.resource_id = r.id and rv.version = r.current_version
cross join generate_series(1, 12) k
where r.deleted_at is null;
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
select c.id, c.school_id, c.title || ' ' || c.k, c.resource_type, c.state, 1, c.created_by
from seed_copies c;
insert into public.resource_versions (school_id, resource_id, version, body, created_by)
select c.school_id, c.id, 1, c.body, c.created_by from seed_copies c;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by)
select c.school_id, rv.id, x.classroom_id, x.audience, x.state, x.published_at, c.created_by
from seed_copies c
join public.resource_versions rv on rv.resource_id = c.id
join public.resources r on r.id = c.source
join public.resource_versions orv on orv.resource_id = r.id and orv.version = r.current_version
cross join lateral (
  select p.classroom_id, p.audience, p.state, p.published_at from public.resource_publications p
  where p.resource_version_id = orv.id order by p.created_at desc limit 1) x;
\endif

create temp table plant_lessons as
select r.id, r.school_id, r.created_by, r.current_version,
  abs(hashtext(r.id::text || ':case')) % 10 as kind
from public.resources r
where abs(hashtext(r.id::text || ':pick')) % :lesson_every = 0;

-- Files to hang on versions: three per picked lesson, created a second
-- apart so their order is by creation, then id.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name, created_at)
select gen_random_uuid(), p.school_id, 'legacy', 'files/plant-lesson/' || p.id || '/' || n, p.created_by,
  100 * n, 'application/pdf', repeat(n::text, 64), 'clean', now(), p.created_by,
  'lesson_resource', 'Lesson file ' || n || '.pdf', now() - (n || ' seconds')::interval
from plant_lessons p cross join generate_series(1, 3) n
where p.kind in (0, 1, 2, 3, 9);

-- Kinds 0, 1, 2 and 9: a version 2 whose own file is the lesson's file 1.
insert into public.resource_versions (school_id, resource_id, version, body, file_object_id, created_by)
select p.school_id, p.id, p.current_version + 1, 'Revised: ' || p.kind,
  (select fo.id from public.file_objects fo where fo.object_key = 'files/plant-lesson/' || p.id || '/1'),
  p.created_by
from plant_lessons p where p.kind in (0, 1, 2, 9);
-- Kind 2 keeps its old version current, so the new one must not show.
update public.resources r set current_version = r.current_version + 1
from plant_lessons p where p.id = r.id and p.kind in (0, 1, 9);
-- Kind 1: the version's own file is deleted.
update public.file_objects fo set deleted_at = now()
from plant_lessons p
where p.kind = 1 and fo.object_key = 'files/plant-lesson/' || p.id || '/1';

-- Kinds 0, 2, 3 and 9: every file bound to the current version (and, for
-- kind 2, the version that is not current) as material; file 3 is detached
-- for kind 3, file 2 deleted for kind 9, and file 1 bound for results too.
insert into public.file_bindings (school_id, file_object_id, resource_version_id, role)
select p.school_id, fo.id, rv.id, 'material'
from plant_lessons p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id
  and (rv.version = r.current_version or p.kind = 2)
join public.file_objects fo on fo.object_key like 'files/plant-lesson/' || p.id || '/%'
where p.kind in (0, 2, 3, 9);
insert into public.file_bindings (school_id, file_object_id, resource_version_id, role)
select p.school_id, fo.id, rv.id, 'results'
from plant_lessons p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
join public.file_objects fo on fo.object_key = 'files/plant-lesson/' || p.id || '/1'
where p.kind in (3, 9);
update public.file_bindings b set detached_at = now()
from plant_lessons p, public.file_objects fo
where p.kind = 3 and fo.object_key = 'files/plant-lesson/' || p.id || '/3' and b.file_object_id = fo.id;
update public.file_objects fo set deleted_at = now()
from plant_lessons p
where p.kind = 9 and fo.object_key = 'files/plant-lesson/' || p.id || '/2';

-- Kinds 4 and 9: links on the current version, two at the same position,
-- one detached, one for results.
insert into public.content_links (school_id, title, url, role, position, resource_version_id, created_by,
  created_at)
select p.school_id, 'Lesson link ' || n, 'https://example.org/lesson/' || p.id || '/' || n,
  case when n = 4 then 'results' else 'material' end, case when n <= 2 then 0 else n end,
  rv.id, p.created_by, now() - (n || ' seconds')::interval
from plant_lessons p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
cross join generate_series(1, 4) n
where p.kind in (4, 9);
update public.content_links l set detached_at = now(), detached_by = l.created_by
from plant_lessons p
where p.kind = 4 and l.url = 'https://example.org/lesson/' || p.id || '/3';

-- Kind 5: a newer publication of the current version to another class (a
-- draft), and an older one; the newest is the one a lesson reports.
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by, created_at)
select p.school_id, rv.id, other.id, 'students', 'draft', null, p.created_by, now() + interval '1 minute'
from plant_lessons p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
cross join lateral (
  select c.id from public.classrooms c where c.school_id = p.school_id
  order by c.id limit 1) other
where p.kind = 5;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by, created_at)
select p.school_id, rv.id, null, 'both', 'published', now() - interval '400 days', p.created_by,
  now() - interval '400 days'
from plant_lessons p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
where p.kind = 5;

-- Kind 6: the current version is missing, so the lesson's row is null.
update public.resources r set current_version = 99
from plant_lessons p where p.id = r.id and p.kind = 6;
-- Kind 7: back to a draft, and a new unpublished lesson by the same teacher.
update public.resources r set state = 'draft'
from plant_lessons p where p.id = r.id and p.kind = 7;
insert into public.resources (id, school_id, title, resource_type, state, current_version, created_by)
select ('0000' || substr(md5(p.id::text || ':new'), 5))::uuid, p.school_id, 'Unpublished', 'lesson',
  'draft', 1, p.created_by
from plant_lessons p where p.kind = 7;
insert into public.resource_versions (school_id, resource_id, version, body, created_by)
select p.school_id, ('0000' || substr(md5(p.id::text || ':new'), 5))::uuid, 1, 'Not yet published',
  p.created_by
from plant_lessons p where p.kind = 7;
-- Kind 8: deleted.
update public.resources r set deleted_at = now()
from plant_lessons p where p.id = r.id and p.kind = 8;

analyze public.resources, public.resource_versions, public.resource_publications,
  public.file_objects, public.file_bindings, public.content_links;
