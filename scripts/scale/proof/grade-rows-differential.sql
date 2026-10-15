-- The page builder against the single-grade builder (capacity fix 6,
-- 2026-10-16): for every sampled person, every grade of every class they
-- teach, are enrolled in or have a linked child in, in any state, built by
-- api041_grade_json one at a time and by api041_grade_rows a class at a
-- time and one grade at a time, as that person. The lists only show some
-- of these grades; this compares the builders on all of them, including
-- drafts read by someone who is not the class's teacher. In one
-- transaction, rolled back.
--
-- psql -v migration=<file> -v sample=<N> [-v plant=plant-grades.sql]
--   -f grade-rows-differential.sql <db>
-- (omit migration when the database already has it.)
\set ON_ERROR_STOP on
\pset pager off
begin;
set local statement_timeout = 0;
\if :{?migration}
\i :migration
\endif
\if :{?plant}
\i :plant
\endif

create temp table subjects as
select u.id as uid from auth.users u
where (abs(hashtext(u.id::text)) % :sample) = 0;

create temp table pairs as
select distinct s.uid, a.classroom_id
from subjects s
join lateral (
  select cs.classroom_id from public.classroom_staff cs where cs.user_id = s.uid
  union select e.classroom_id from public.enrollments e
    join public.students st on st.id = e.student_id where st.user_id = s.uid
  union select e.classroom_id from public.enrollments e
    join public.guardian_links gl on gl.student_id = e.student_id where gl.guardian_id = s.uid
) rel on true
join public.assessments a on a.classroom_id = rel.classroom_id;

create function pg_temp.check_class(p_uid uuid, p_class uuid)
returns table (grades int, page_differs boolean, single_differences int,
  not_published int, with_content int, not_published_with_content int)
language plpgsql as $$
declare v_ids uuid[]; v_one jsonb; v_page jsonb;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  select array_agg(g.id order by g.id) into v_ids
  from public.grade_results g join public.assessments a on a.id = g.assessment_id
  where a.classroom_id = p_class;
  if v_ids is null then
    grades := 0; page_differs := false; single_differences := 0;
    not_published := 0; with_content := 0; not_published_with_content := 0;
    return next; return;
  end if;
  select jsonb_agg(private.api041_grade_json(x) order by x) into v_one from unnest(v_ids) x;
  v_page := private.api041_grade_rows(v_ids);
  grades := cardinality(v_ids);
  page_differs := v_one is distinct from v_page;
  select count(*) into single_differences from unnest(v_ids) x
  where private.api041_grade_json(x) is distinct from private.api041_grade_rows(array[x])->0;
  -- What the compared grades contained, as this person sees them.
  select count(*) filter (where i->>'state' <> 'published'),
    count(*) filter (where c > 0),
    count(*) filter (where i->>'state' <> 'published' and c > 0)
  into not_published, with_content, not_published_with_content
  from jsonb_array_elements(v_one) i
  cross join lateral (select jsonb_array_length(i->'attachments') + jsonb_array_length(i->'links')
    + jsonb_array_length(i->'sharedAttachments') + jsonb_array_length(i->'sharedLinks') as c) n;
  return next;
end $$;

create temp table results as
select p.uid, p.classroom_id, r.*
from (select distinct uid, classroom_id from pairs) p
cross join lateral pg_temp.check_class(p.uid, p.classroom_id) r;

select count(distinct uid) as people, count(*) as person_classes, sum(grades) as grades_compared,
  count(*) filter (where page_differs) as page_differences,
  sum(single_differences) as single_differences,
  sum(not_published) as not_published, sum(with_content) as with_files_or_links,
  sum(not_published_with_content) as not_published_with_files_or_links
from results;

-- An empty page is null, as jsonb_agg over no rows is; the lists coalesce it.
select private.api041_grade_rows('{}'::uuid[]) is null as empty_page_is_null;

rollback;
