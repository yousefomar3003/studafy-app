-- Access cases the synthetic data lacks, planted before the study_lesson
-- proof (2026-10-17): every condition of can_view_resource_publication as
-- study_lesson asks it, on both sides. Runs inside the differential's
-- transaction and is rolled back with it.
--
-- First the lesson extras of fix 4 (plant-lessons.sql: newer and missing
-- current versions with their own files, one deleted, drafts, deleted
-- lessons, a newer draft publication and an older class-less one). Then,
-- on lessons picked by a different hash (:access_every, default 3; 1 on the
-- pgTAP fixtures):
--   0 the current version's file still being scanned
--   1 the current version's file clean but deleted
--   2 the current version's file clean (shown)
--   3 published to students only
--   4 published to guardians only
--   5 withdrawn, with an older live publication to another class
--   6 a second publication to another class at the same moment (a tie)
--     and a third, newer one to a third class
--   7 a draft publication, and a published one with no class
--   8 the current version's file rejected
--   9 unchanged
-- and on people, spread by hash: inactive, withdrawn, ended and future
-- enrolments; expired and pending guardian links; lapsed and suspended
-- memberships; archived classes; closed terms; suspended profiles; deleted
-- student records; a suspended and a deleted school; parent and guardian
-- memberships for most linked guardians (the seed has none, so without
-- them no guardian could see a lesson), and none for some (half of those
-- with a parent membership in another school instead); a school admin
-- per school who teaches elsewhere, and one who is a parent elsewhere.
\if :{?access_every} \else \set access_every 3 \endif

\ir plant-lessons.sql

create temp table plant_access as
select r.id, r.school_id, r.created_by, r.current_version,
  abs(hashtext(r.id::text || ':access-case')) % 10 as kind
from public.resources r
where abs(hashtext(r.id::text || ':access-pick')) % :access_every = 0;

-- Kinds 0, 1, 2 and 8: a file on the current version, in a scan state.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name, deleted_at)
select gen_random_uuid(), p.school_id, 'legacy', 'files/plant-access/' || p.id, p.created_by,
  100, 'application/pdf', repeat('a', 64),
  (case p.kind when 0 then 'scanning' when 8 then 'rejected' else 'clean' end)::public.file_scan_state,
  case when p.kind in (1, 2) then now() end, p.created_by, 'lesson_resource', 'Access file.pdf',
  case when p.kind = 1 then now() end
from plant_access p where p.kind in (0, 1, 2, 8);
-- Versions are append-only, so the file comes with a new current version,
-- published to the same classes as the version it replaces.
create temp table plant_access_versions as
select p.id, p.school_id, p.created_by, rv.id as old_version, rv.body,
  (select max(x.version) + 1 from public.resource_versions x where x.resource_id = p.id) as version,
  fo.id as file_id
from plant_access p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
join public.file_objects fo on fo.object_key = 'files/plant-access/' || p.id
where p.kind in (0, 1, 2, 8);
insert into public.resource_versions (school_id, resource_id, version, body, file_object_id, created_by)
select v.school_id, v.id, v.version, v.body, v.file_id, v.created_by from plant_access_versions v;
update public.resources r set current_version = v.version
from plant_access_versions v where v.id = r.id;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, withdrawn_at, created_by)
select v.school_id, nv.id, rp.classroom_id, rp.audience, rp.state, rp.published_at, rp.withdrawn_at,
  rp.created_by
from plant_access_versions v
join public.resource_versions nv on nv.resource_id = v.id and nv.version = v.version
join public.resource_publications rp on rp.resource_version_id = v.old_version;

-- Kinds 3 and 4: one audience only.
update public.resource_publications rp
set audience = case p.kind when 3 then 'students' else 'guardians' end::public.meeting_audience
from plant_access p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
where p.kind in (3, 4) and rp.resource_version_id = rv.id;

-- Other classes of the lesson's school, for the extra publications.
create temp table plant_access_classes as
select p.id, p.school_id, p.kind, rv.id as version_id, rp.classroom_id as first_class,
  rp.published_at, others.ids
from plant_access p
join public.resources r on r.id = p.id
join public.resource_versions rv on rv.resource_id = p.id and rv.version = r.current_version
join lateral (
  select x.classroom_id, x.published_at from public.resource_publications x
  where x.resource_version_id = rv.id and x.classroom_id is not null
    and x.state = 'published' and x.withdrawn_at is null
  order by x.created_at desc limit 1) rp on true
cross join lateral (
  select array_agg(c.id order by md5(c.id::text || p.id::text)) as ids
  from public.classrooms c
  where c.school_id = p.school_id and c.id <> rp.classroom_id) others
where p.kind in (5, 6, 7) and cardinality(others.ids) >= 2;

-- Kind 5: withdrawn; an older live publication to another class.
update public.resource_publications rp set withdrawn_at = now()
from plant_access_classes a
where a.kind = 5 and rp.resource_version_id = a.version_id and rp.classroom_id = a.first_class
  and rp.published_at is not null;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by)
select a.school_id, a.version_id, a.ids[1], 'both', 'published', a.published_at - interval '1 day',
  r.created_by
from plant_access_classes a join public.resources r on r.id = a.id where a.kind = 5;

-- Kind 6: another class at the same moment, a third one later.
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by)
select a.school_id, a.version_id, a.ids[n], 'both', 'published',
  a.published_at + case when n = 2 then interval '1 hour' else interval '0' end, r.created_by
from plant_access_classes a join public.resources r on r.id = a.id
cross join generate_series(1, 2) n
where a.kind = 6;

-- Kind 7: the class's publication back to a draft; a published one with no
-- class, which study_lesson never offers.
update public.resource_publications rp set state = 'draft'
from plant_access_classes a
where a.kind = 7 and rp.resource_version_id = a.version_id and rp.classroom_id = a.first_class;
insert into public.resource_publications (school_id, resource_version_id, classroom_id, audience, state,
  published_at, created_by)
select a.school_id, a.version_id, null, 'both', 'published', a.published_at + interval '1 hour',
  r.created_by
from plant_access_classes a join public.resources r on r.id = a.id where a.kind = 7;

-- People. Guardians first get the membership the seed leaves out: parent
-- for most, guardian for some, none for a tenth.
insert into public.memberships (school_id, user_id, role, active)
select distinct gl.school_id, gl.guardian_id,
  case when abs(hashtext(gl.guardian_id::text || ':role')) % 10 < 7 then 'parent'
    else 'guardian' end::public.app_role, true
from public.guardian_links gl
where abs(hashtext(gl.guardian_id::text || ':role')) % 10 <> 9
on conflict do nothing;
-- Half of the guardians left without one hold a parent membership in
-- another school, which must not count for their child's school.
insert into public.memberships (school_id, user_id, role, active)
select distinct on (gl.guardian_id) other.id, gl.guardian_id, 'parent', true
from public.guardian_links gl
cross join lateral (
  select s.id from public.schools s where s.id <> gl.school_id
  order by md5(s.id::text || gl.guardian_id::text) limit 1) other
where abs(hashtext(gl.guardian_id::text || ':role')) % 10 = 9
  and abs(hashtext(gl.guardian_id::text || ':elsewhere')) % 2 = 0
order by gl.guardian_id
on conflict do nothing;
-- A school admin per school who teaches in another school, and one who is
-- a parent in another school (a student account cannot hold another role).
insert into public.memberships (school_id, user_id, role, active)
select s.id, t.user_id, 'school_admin', true
from public.schools s
cross join lateral (
  select m.user_id from public.memberships m
  where m.role = 'teacher' and m.school_id <> s.id
  order by md5(m.user_id::text || s.id::text) limit 1) t
on conflict do nothing;
insert into public.memberships (school_id, user_id, role, active)
select s.id, t.user_id, 'school_admin', true
from public.schools s
cross join lateral (
  select m.user_id from public.memberships m
  where m.role = 'parent' and m.school_id <> s.id
  order by md5(m.user_id::text || s.id::text) limit 1) t
on conflict do nothing;

update public.enrollments set active = false
  where abs(hashtext(classroom_id::text || student_id::text)) % 37 = 0;
update public.enrollments set status = 'withdrawn'
  where abs(hashtext(classroom_id::text || student_id::text)) % 41 = 1;
update public.enrollments set starts_on = current_date - 30, ends_on = current_date - 1
  where abs(hashtext(classroom_id::text || student_id::text)) % 43 = 2;
update public.enrollments set starts_on = current_date + 5
  where abs(hashtext(classroom_id::text || student_id::text)) % 47 = 3 and ends_on is null;
update public.guardian_links
  set verified_at = case when status = 'verified' then now() - interval '30 days' else verified_at end,
      expires_at = now() - interval '1 day'
  where abs(hashtext(id::text)) % 29 = 0 and (verified_at is null or status = 'verified');
update public.guardian_links set expires_at = now() + interval '30 days'
  where abs(hashtext(id::text)) % 29 = 5 and status = 'verified';
update public.guardian_links set status = 'pending'
  where abs(hashtext(id::text)) % 31 = 1;
update public.memberships set valid_from = now() - interval '30 days',
    valid_until = now() - interval '1 day'
  where abs(hashtext(id::text)) % 53 = 0;
update public.memberships set valid_from = now() + interval '1 day'
  where abs(hashtext(id::text)) % 53 = 7 and valid_until is null;
update public.memberships set active = false, status = 'suspended'
  where abs(hashtext(id::text)) % 59 = 1;
update public.classrooms set status = 'archived', archived_at = now()
  where abs(hashtext(id::text)) % 23 = 0;
update public.profiles set status = 'suspended'
  where abs(hashtext(id::text)) % 61 = 0;
update public.profiles set deleted_at = now()
  where abs(hashtext(id::text)) % 61 = 7;
update public.students set deleted_at = now()
  where abs(hashtext(id::text)) % 67 = 0;
update public.terms set status = 'closed'
  where abs(hashtext(id::text)) % 13 = 0;
-- One school suspended and one deleted (on data with several schools).
update public.schools set status = 'suspended'
  where id = (select id from public.schools order by md5(id::text) offset 1 limit 1)
    and (select count(*) from public.schools) > 3;
update public.schools set deleted_at = now()
  where id = (select id from public.schools order by md5(id::text) offset 2 limit 1)
    and (select count(*) from public.schools) > 3;

analyze public.resources, public.resource_versions, public.resource_publications,
  public.file_objects, public.memberships, public.enrollments, public.guardian_links,
  public.students, public.profiles, public.classrooms, public.terms, public.schools;
