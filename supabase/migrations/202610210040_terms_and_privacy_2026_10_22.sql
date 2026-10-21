-- Terms of Use and Privacy Policy, consent version 2026-10-22, and the AI
-- notice, version 2026-10-22.
--
-- Terms of use 1.5 and privacy policy 1.7, published by the owner's decision
-- on 2026-10-21 WITHOUT legal review, like 1.3 to 1.6 (DL-068); counsel
-- reviews them later (docs/legal/questions-for-counsel-2026-10.md). They
-- follow DL-072 (migration 202610210030, ADR-0045):
--
--   * joining a class is optional: a student can study on their own and
--     join a class later;
--   * the AI study tools are for every student account, in a class or not
--     (privacy policy 1.6 and ADR-0043 said students in a class only); the
--     separate AI consent, a parent's for a managed child, and replacing
--     names before anything is sent are unchanged;
--   * a student has a personal notebook that belongs to no class and that
--     only they can see;
--   * a photo or screenshot from a student who is in no class is read once
--     and not kept; photos sent from a class are kept 30 days, as before;
--   * the study helper is called the AI Tutor.
--
-- The in-app texts changed (policyTermsBody STUDENTS and AI STUDY TOOLS;
-- policyPrivacyBody WHAT WE COLLECT, AI STUDY TOOLS and ON YOUR DEVICE;
-- aiConsentNoticeBody), so people must see them again: new versions, not
-- corrections. The version label is the day the owner publishes them;
-- 2026-10-21 was already taken by DL-071's text.
--
-- Governing documents: docs/legal/terms-of-use.md (1.5) and
-- docs/legal/privacy-policy.md (1.7). content_hash is the SHA-256 of the
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
  ('terms_and_privacy', '2026-10-22', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '86a25d6382375a13749b42abcd7fd827654431823bf9341224d697f972175058', now(), now()),
  ('terms_and_privacy', '2026-10-22', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    'e02e8e60ee6469a1259b3dbf6dfe73ff95d2ada24f3364e66dcf733fe830c8a9', now(), now()),
  ('ai_features', '2026-10-22', 'en', 'Studafy AI study tools',
    '9e7b58315ec70484541bb143f3e7a4eab178322719cc3fb01ed9c53af2f3ff7d', now(), now()),
  ('ai_features', '2026-10-22', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    'bfa31c313720ceffc6a9fcf7cdcf2574d12d0619eede9277f0b3462bb1ca5c1f', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
