-- Grade extras the synthetic data lacks, so the fix 6 proof compares every
-- field of a grade: its own files (one deleted, one detached, one bound for
-- results, one bound twice, two bound at the same moment) and links (two at
-- the same position and moment, one detached, one for results); its
-- assessment's shared results files and links (with material ones that
-- must not show, a deleted file, a detached binding and link); grades in
-- every state, so the files are hidden from everyone but the class's
-- teacher until published; marks (absent, not graded, scored 0, none);
-- feedback; a category weight; a teacher whose membership is not a
-- teacher's (coursework_staff says no although the list shows the class's
-- drafts). Runs inside the differential's transaction and is rolled back
-- with it.
--
-- :grade_every picks how many grades get an extra and :assessment_every how
-- many assessments (1 = every one, for the pgTAP fixtures; the scale data
-- uses 5 and 3). Each picked row gets the case its id hashes to.
\if :{?grade_every} \else \set grade_every 5 \endif
\if :{?assessment_every} \else \set assessment_every 3 \endif

-- The pgTAP fixtures hold only a few grades; -v seed_grades=1 first adds
-- ten published assessments to every class with staff and active enrolments, each
-- with a published grade for every enrolled student, so every case below
-- is planted on them.
\if :{?seed_grades}
insert into public.assessments (id, school_id, classroom_id, title, category, maximum_score, state,
  published_at, created_by)
select ('0000' || substr(md5(c.id::text || ':grades:' || k), 5))::uuid, c.school_id, c.id,
  'Planted quiz ' || k, 'quiz', 20, 'published', now() - interval '2 days',
  (select cs.user_id from public.classroom_staff cs where cs.classroom_id = c.id
    order by cs.user_id limit 1)
from public.classrooms c
cross join generate_series(1, 10) k
where exists (select 1 from public.enrollments e where e.classroom_id = c.id and e.active)
  and exists (select 1 from public.classroom_staff cs where cs.classroom_id = c.id);
insert into public.grade_results (id, assessment_id, student_id, score, state, reviewed_by, reviewed_at,
  published_at, published_by)
select ('0000' || substr(md5(a.id::text || ':' || e.student_id::text), 5))::uuid, a.id, e.student_id, 10 + (abs(hashtext(e.student_id::text || a.id::text)) % 10), 'published',
  a.created_by, now() - interval '1 day', now() - interval '1 day', a.created_by
from public.assessments a
join public.enrollments e on e.classroom_id = a.classroom_id and e.active
where a.title like 'Planted quiz %'
on conflict do nothing;
\endif

create temp table plant_grades as
select g.id, g.school_id, a.created_by, a.id as assessment_id,
  abs(hashtext(g.id::text || ':case')) % 10 as kind
from public.grade_results g
join public.assessments a on a.id = g.assessment_id
where abs(hashtext(g.id::text || ':pick')) % :grade_every = 0;

create temp table plant_assessments as
select a.id, a.school_id, a.created_by, abs(hashtext(a.id::text || ':case')) % 5 as kind
from public.assessments a
where abs(hashtext(a.id::text || ':pick')) % :assessment_every = 0;

-- Grade kinds 0, 2, 3, 4 and 9: three material files. File 1 is bound
-- twice and for results too; file 2 is deleted; file 3's binding is
-- detached (kind 0 only). Files 1 and 2 are bound at the same moment, so
-- their order is by id.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name)
select gen_random_uuid(), p.school_id, 'legacy', 'files/plant-grade/' || p.id || '/' || n, p.created_by,
  100 * n, 'application/pdf', repeat(n::text, 64), 'clean', now(), p.created_by,
  'assignment_material', 'Marked paper ' || n || '.pdf'
from plant_grades p cross join generate_series(1, 3) n
where p.kind in (0, 2, 3, 4, 9);
insert into public.file_bindings (school_id, file_object_id, grade_result_id, role, created_at)
select p.school_id, fo.id, p.id, 'material',
  now() - case when fo.object_key like '%/3' then interval '5 seconds' else interval '1 minute' end
from plant_grades p
join public.file_objects fo on fo.object_key like 'files/plant-grade/' || p.id || '/%'
where p.kind in (0, 2, 3, 4, 9);
insert into public.file_bindings (school_id, file_object_id, grade_result_id, role, created_at)
select p.school_id, fo.id, p.id, r, now()
from plant_grades p
join public.file_objects fo on fo.object_key = 'files/plant-grade/' || p.id || '/1'
cross join unnest(array['material', 'results']) r
where p.kind in (0, 9);
update public.file_objects fo set deleted_at = now()
from plant_grades p
where p.kind in (0, 9) and fo.object_key = 'files/plant-grade/' || p.id || '/2';
update public.file_bindings b set detached_at = now()
from plant_grades p, public.file_objects fo
where p.kind = 0 and fo.object_key = 'files/plant-grade/' || p.id || '/3' and b.file_object_id = fo.id;

-- Grade kinds 1, 2, 3, 4 and 9: four links. Links 1 and 2 share a position
-- and a moment, so their order is by id; link 3 is detached (kind 1 only);
-- link 4 is for results.
insert into public.content_links (school_id, title, url, role, position, grade_result_id, created_by,
  created_at)
select p.school_id, 'Feedback link ' || n, 'https://example.org/grade/' || p.id || '/' || n,
  case when n = 4 then 'results' else 'material' end, case when n <= 2 then 0 else n end,
  p.id, p.created_by, now() - case when n <= 2 then interval '1 minute' else (n || ' seconds')::interval end
from plant_grades p cross join generate_series(1, 4) n
where p.kind in (1, 2, 3, 4, 9);
update public.content_links l set detached_at = now(), detached_by = l.created_by
from plant_grades p
where p.kind = 1 and l.url = 'https://example.org/grade/' || p.id || '/3';

-- Grade states and marks.
update public.grade_results g set state = 'draft', published_at = null, published_by = null
from plant_grades p where p.id = g.id and p.kind = 2;
update public.grade_results g set state = 'reviewed', published_at = null, published_by = null,
  feedback = 'Reviewed, not yet published'
from plant_grades p where p.id = g.id and p.kind = 3;
update public.grade_results g set state = 'withdrawn'
from plant_grades p where p.id = g.id and p.kind = 4;
update public.grade_results g set mark = 'absent', score = null
from plant_grades p where p.id = g.id and p.kind = 5;
update public.grade_results g set mark = 'not_graded', score = null, feedback = 'Excused'
from plant_grades p where p.id = g.id and p.kind = 6;
update public.grade_results g set mark = 'scored', score = 0, feedback = 'Try again',
  reviewed_at = now() - interval '3 days'
from plant_grades p where p.id = g.id and p.kind = 7;
update public.grade_results g set state = 'draft', score = null, mark = null, published_at = null,
  published_by = null, reviewed_by = null, reviewed_at = null
from plant_grades p where p.id = g.id and p.kind = 8;
update public.grade_results g set feedback = 'Well done', version = g.version + 1
from plant_grades p where p.id = g.id and p.kind = 9;

-- Assessment kinds 0, 1 and 2: shared results. Kind 0: three results files
-- (file 2 deleted, file 3's binding detached) and a material file that
-- must not show; three results links (two at the same position, one
-- detached) and a material link that must not show. Kind 1: links only.
-- Kind 2: files only. Kind 3: a category weight. Kind 4: nothing.
insert into public.file_objects (id, school_id, bucket, object_key, uploader_id, size_bytes,
  declared_media_type, sha256, scan_state, scanned_at, owner_id, purpose, display_name)
select gen_random_uuid(), p.school_id, 'legacy', 'files/plant-results/' || p.id || '/' || n, p.created_by,
  10 * n, 'application/pdf', repeat(n::text, 64), 'clean', now(), p.created_by,
  'assignment_material', 'Mark scheme ' || n || '.pdf'
from plant_assessments p cross join generate_series(1, 4) n
where p.kind in (0, 2);
insert into public.file_bindings (school_id, file_object_id, assessment_id, role, created_at)
select p.school_id, fo.id, p.id, case when fo.object_key like '%/4' then 'material' else 'results' end,
  now() - interval '1 minute'
from plant_assessments p
join public.file_objects fo on fo.object_key like 'files/plant-results/' || p.id || '/%'
where p.kind in (0, 2);
update public.file_objects fo set deleted_at = now()
from plant_assessments p
where p.kind = 0 and fo.object_key = 'files/plant-results/' || p.id || '/2';
update public.file_bindings b set detached_at = now()
from plant_assessments p, public.file_objects fo
where p.kind = 0 and fo.object_key = 'files/plant-results/' || p.id || '/3' and b.file_object_id = fo.id;
insert into public.content_links (school_id, title, url, role, position, assessment_id, created_by,
  created_at)
select p.school_id, 'Answers ' || n, 'https://example.org/results/' || p.id || '/' || n,
  case when n = 4 then 'material' else 'results' end, case when n <= 2 then 1 else 0 end,
  p.id, p.created_by, now() - (n || ' seconds')::interval
from plant_assessments p cross join generate_series(1, 4) n
where p.kind in (0, 1);
update public.content_links l set detached_at = now(), detached_by = l.created_by
from plant_assessments p
where p.kind = 0 and l.url = 'https://example.org/results/' || p.id || '/2';
update public.assessments a set category_weight = 25.5
from plant_assessments p where p.id = a.id and p.kind = 3;

-- A class's staff whose membership is not a teacher's: one teacher per
-- school also gets a school_admin membership and, through it, a class
-- assistant's place in a class they do not teach. The list shows them that
-- class's drafts (is_class_staff), but coursework_staff says no, so those
-- drafts carry no files. Teachers in the 1-in-1,000 sample go first.
create temp table plant_admins as
select distinct on (m.school_id) m.school_id, m.user_id
from public.memberships m
where m.role = 'teacher' and m.active and m.status = 'active'
  and exists (select 1 from public.classroom_staff cs where cs.membership_id = m.id)
order by m.school_id, (abs(hashtext(m.user_id::text)) % 1000 = 0) desc, m.user_id;
insert into public.memberships (school_id, user_id, role, active)
select p.school_id, p.user_id, 'school_admin', true from plant_admins p
on conflict do nothing;
insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
select p.school_id, c.id, m.id, p.user_id, 'assistant'
from plant_admins p
join public.memberships m on m.school_id = p.school_id and m.user_id = p.user_id
  and m.role = 'school_admin'
cross join lateral (
  select c.id from public.classrooms c
  where c.school_id = p.school_id
    and not exists (select 1 from public.classroom_staff cs
      where cs.classroom_id = c.id and cs.user_id = p.user_id)
  order by c.id limit 1) c
on conflict do nothing;
-- And a teacher whose place in a class has not started yet (one in seven):
-- coursework_staff, but not yet is_class_staff.
update public.classroom_staff cs set starts_at = now() + interval '1 day'
where cs.status = 'active' and abs(hashtext(cs.id::text || ':later')) % 7 = 0;

analyze public.grade_results, public.assessments, public.file_objects, public.file_bindings,
  public.content_links, public.memberships;
