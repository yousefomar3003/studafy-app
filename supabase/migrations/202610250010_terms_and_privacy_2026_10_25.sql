-- Terms of Use and Privacy Policy, consent version 2026-10-25, and the AI
-- notice, version 2026-10-25.
--
-- Terms of use 1.6 and privacy policy 1.8, published by the owner's decision
-- on 2026-10-25 WITHOUT legal review, like 1.3 to 1.7 (DL-068); counsel
-- reviews them later (docs/legal/questions-for-counsel-2026-10.md). They
-- follow Studafy AI Marking (DL-073, ADR-0046, migration 202610210060):
--
--   * a teacher with Studafy AI Marking, a paid plan for teachers, can ask
--     AI (Together AI) for a suggested mark on written work - written
--     answers in an online assessment, and hand-ins of graded assignments
--     with their files - compared with the teacher's own reference answers;
--   * names Studafy knows are replaced before anything is sent; files are
--     read for the suggestion and not kept by the AI step;
--   * a suggestion is a draft only the class's teachers see: the teacher
--     decides every mark and AI never marks on its own (the privacy policy
--     and the AI notice said "AI never marks your work");
--   * suggestions are kept for the teacher for up to 180 days;
--   * a student can turn suggested marks off in Account; their work is then
--     never sent and is marked by hand.
--
-- The in-app texts changed (policyTermsBody TEACHERS, STUDENTS, AI STUDY
-- TOOLS and SUBSCRIPTIONS; policyPrivacyBody WHAT WE COLLECT, AI STUDY
-- TOOLS, the new AI-SUGGESTED MARKS, WHO ELSE PROCESSES DATA and PAYMENTS;
-- aiConsentNoticeBody, a new MARKS section), so people must see them again:
-- new versions, not corrections.
--
-- Governing documents: docs/legal/terms-of-use.md (1.6) and
-- docs/legal/privacy-policy.md (1.8). content_hash is the SHA-256 of the
-- exact in-app text in that language: for terms_and_privacy,
-- policyTermsBody, a blank line, policyPrivacyBody; for ai_features,
-- aiConsentNoticeBody. lib/core/account_lifecycle.dart and
-- lib/core/ai_consent.dart move to these versions with them
-- (test/l10n/policy_consent_version_test.dart and
-- ai_consent_version_test.dart check that they agree). Every earlier version
-- stays published, so consent already given still stands for what it
-- covered, and the app asks for the new versions at the next sign-in and
-- the next use of an AI tool.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-10-25', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '81916a95995c90de0a1a19d74617a9d614d748bf9e3b0d4f88e5c6f173ab7c92', now(), now()),
  ('terms_and_privacy', '2026-10-25', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    'c3b73b63a20b8e5b51d3fcb2b160fb27a7b3a2047e1757139277f030884d1e29', now(), now()),
  ('ai_features', '2026-10-25', 'en', 'Studafy AI study tools',
    'b66294e3a35729ccfced5e93bebc967fbc4265ef4550f7970a02bef801ff22c9', now(), now()),
  ('ai_features', '2026-10-25', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    'c0aec4d6537d86b80784ee89853cc2109108e60413fb55f884e9a4e7b643eab0', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
