-- A managed child's AI study tools need the parent's affirmative consent
-- again (owner, 2026-11-03; DL-081). Replaces DL-074 (1).
--
-- 202611020030 made creating a managed child record the parent's agreement
-- to the current AI notice (trigger dl074_managed_child_ai_on), so the tools
-- were on unless the parent turned them off. That is not the clear
-- affirmative act GDPR Art. 4(11)/7 and the Planet49 ruling expect. The
-- create-child screen now has its own unticked box naming Together AI
-- (PR #151); when the parent ticks it, the app gives the consent for the
-- child through the existing guardian path (child_give, given_as
-- 'guardian'), and when the box is left unticked nothing is recorded and the
-- tools stay off. The parent can turn them on or off later on the child's
-- card, as before (ADR-0043).
--
-- So the trigger and its function go. Existing consent records are left as
-- they are: nobody's choice is changed here. The AI notice is version
-- 2026-11-03 (202611040020), so every child, like everyone, needs a new
-- agreement to it anyway, which now only the parent can give.

drop trigger if exists dl074_managed_child_ai_on on private.managed_accounts;
drop function if exists private.managed_child_ai_on();
