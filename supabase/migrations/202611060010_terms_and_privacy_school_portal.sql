-- Terms of Use and Privacy Policy, consent version 2026-11-06: the Studafy
-- School Portal (docs/planning/school-portal.md, migration
-- 202611050010_school_portal.sql).
--
-- Terms of use 1.9 and privacy policy 2.1. BRANCH ONLY: this lives on
-- feat/school-admin-web and reaches production only through the portal's
-- release gate (school-portal.md 11.2), after counsel has read the texts
-- (TODO(legal) items at the top of docs/legal/privacy-policy.md and
-- terms-of-use.md). If main publishes a newer consent version first, this
-- one is re-issued after it when the branch is merged.
--
-- What changes for everyone in the app: "there is no school administrator"
-- becomes "none inside the app", and new sections say that a teacher can
-- link with a school, which then reads (never changes) all their classes:
-- students' and linked parents' names and emails, Studafy IDs, lessons,
-- work and answers, every mark including drafts and AI suggestions,
-- attendance and wellbeing notes not restricted to safeguarding; that
-- families are not told one by one; that a school can download class
-- lists, marks, attendance and reports, send announcements to linked
-- classes and make class groups joined with one code; and the duties of a
-- school's administrators. The AI notice (ai_features) does not change.
--
-- The in-app texts changed (policyTermsBody and policyPrivacyBody, EN and
-- AR), so people must see them again: a new version, not a correction.
-- content_hash is the SHA-256 of policyTermsBody, a blank line, and
-- policyPrivacyBody, in that language. lib/core/account_lifecycle.dart
-- moves to this version (test/l10n/policy_consent_version_test.dart checks
-- that they agree). Every earlier version stays published.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-11-06', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '100ce697be3d7ebd6a8d99dc6941157e68ff76e6891c6d04fdcf8a75cfd9e898', now(), now()),
  ('terms_and_privacy', '2026-11-06', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    '4fcd1f03c44008457981998a91ca971041155386dd86cbd607e6af57654cf399', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
