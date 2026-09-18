-- AI-072 (ADR-0026, DL-047): retire the AI surface.
--
-- No signed DPA and no DPIA covering AI processing of minors' data exist, so
-- the removal path is the only lawful outcome. Both AI Edge Functions, every
-- AI screen and the Study Coach slice are deleted in the same change; this
-- migration retires what they left in the database.
--
-- Forward-only and non-destructive: no table, column or enum value is
-- dropped, and legacy rows stay under the retention schedule. What changes is
-- that nothing can read or write them any more. Re-enabling any part of this
-- is a new reviewed migration plus a new ADR - there is deliberately no flag.

-- 1. Retired relations: the grading-draft pair written only by the removed
--    propose-paper-grade path, and practice_sessions, written only by the
--    removed study-coach function and read by nothing in the app.
revoke all on table
  public.ai_grading_drafts,
  public.question_suggestions,
  public.practice_sessions
from anon, authenticated, service_role;

do $$
declare
  retired record;
begin
  for retired in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('ai_grading_drafts', 'question_suggestions', 'practice_sessions')
  loop
    execute format('drop policy %I on public.%I', retired.policyname, retired.tablename);
  end loop;
end
$$;

-- `check (false) not valid` leaves legacy rows untouched but refuses every
-- new insert and every update, including from SECURITY DEFINER functions.
-- That makes the API-041 draft-approval branch of private.api041_command
-- permanently unreachable: no draft can become `ready`, and no suggestion
-- can be updated. Deletes (retention, tenant cascade) remain possible.
alter table public.ai_grading_drafts
  add constraint ai072_retired check (false) not valid;
alter table public.question_suggestions
  add constraint ai072_retired check (false) not valid;
alter table public.practice_sessions
  add constraint ai072_retired check (false) not valid;

comment on table public.ai_grading_drafts is
  'Retired by AI-072 (ADR-0026). Legacy rows only; no role may read or write.';
comment on table public.question_suggestions is
  'Retired by AI-072 (ADR-0026). Legacy rows only; no role may read or write.';
comment on table public.practice_sessions is
  'Retired by AI-072 (ADR-0026). Legacy rows only; no role may read or write.';

-- 2. The Study Coach upload purpose. Disabling the policy row makes
--    private.api050_prepare_intent answer `invalid`; the upload_sessions
--    constraint is the backstop for private.api050_issue_intent, which does
--    not itself refuse a missing policy row.
update public.file_purpose_policies
set enabled = false, updated_at = now()
where purpose = 'coach_attachment';

alter table public.file_purpose_policies
  add constraint ai072_coach_attachment_retired
  check (purpose <> 'coach_attachment' or not enabled);

alter table public.upload_sessions
  add constraint ai072_coach_attachment_retired
  check (purpose::text <> 'coach_attachment') not valid;

-- 3. The two AI store products. Only `synthetic` ever had rows; they are
--    unlisted and deactivated, and no environment may re-activate them. The
--    feature keys stay as retired ledger vocabulary (ADR-0009, ADR-0026).
update public.store_products
set active = false, storefront_listed = false, updated_at = now()
where feature_key in ('student_ai', 'teacher_ai_grading');

alter table public.store_products
  add constraint ai072_ai_products_retired
  check (
    feature_key not in ('student_ai', 'teacher_ai_grading')
    or (not active and not storefront_listed)
  );
