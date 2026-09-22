-- A grade says which piece of work it is for (GRADE-056).
--
-- api041_grade_json returned only ids and a score, so every row on a
-- student's grades screen read "Grade". A student with four exams could not
-- tell which was which, which defeats the point of releasing marks to them.
--
-- The assessment's title and kind travel with the grade. Both are the
-- teacher's own words about work the student sat, so neither discloses
-- anything the student should not see.

create or replace function private.api041_grade_json(p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $function$
  select jsonb_build_object('id',g.id,'assessmentId',g.assessment_id,'studentId',g.student_id,
    'assessmentTitle',a.title,'category',a.category,
    'score',g.score,'maximumScore',a.maximum_score,'feedback',g.feedback,'state',g.state,
    'version',g.version,'reviewedAt',g.reviewed_at,'publishedAt',g.published_at)
  from public.grade_results g join public.assessments a on a.id=g.assessment_id where g.id=p_id;
$function$;
