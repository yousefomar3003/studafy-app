-- Terms of Use and Privacy Policy, consent version 2026-11-03, and the AI
-- notice, version 2026-11-03 (owner, 2026-11-03; DL-081).
--
-- Terms of use 1.8 and privacy policy 2.0, published by the owner's decision
-- WITHOUT legal review, like 1.3 to 1.9 (DL-068); counsel reviews them later
-- (docs/legal/questions-for-counsel-2026-10.md). The policy is brought back
-- in line with the product:
--
--   * for a child account a parent creates, the AI study tools are off
--     unless the parent turns them on: a separate, unticked box that names
--     Together AI (PR #151), or later on the child's card. Creating the
--     account no longer records an AI consent (202611040030). This replaces
--     "on from the start" (DL-074) in the in-app terms, privacy summary and
--     AI notice;
--   * reporting an AI answer (DL-076, 202611030040): what is kept, for how
--     long, and what the alert carries;
--   * Excel, CSV and Word/Excel/PowerPoint 97-2003 files, with PDF previews
--     and newer-format copies made by our own converter (DL-077, DL-078);
--     photos turned into a JPEG on the phone;
--   * hosting: Vercel serves the website and the legal pages, Cloudflare is
--     no longer in front of the API (DL-079), and Redis is Upstash in
--     Frankfurt.
--
-- The in-app texts changed (policyTermsBody, policyPrivacyBody and
-- aiConsentNoticeBody, EN and AR), so people must see them again: new
-- versions, not corrections. content_hash is the SHA-256 of the exact in-app
-- text in that language: for terms_and_privacy, policyTermsBody, a blank
-- line, policyPrivacyBody; for ai_features, aiConsentNoticeBody.
-- lib/core/account_lifecycle.dart and lib/core/ai_consent.dart move to these
-- versions (test/l10n/policy_consent_version_test.dart and
-- ai_consent_version_test.dart check that they agree). Every earlier version
-- stays published.


insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-11-03', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '386f424e7c4bf7dcf914a0fcfb87ad05c699817d12ab946963af0b36b79fe066', now(), now()),
  ('terms_and_privacy', '2026-11-03', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    '743ee34cc2a7bbaf3830b54b7a3da36b0cf4aeba25bc2aacb036a6fd3a7d883e', now(), now()),
  ('ai_features', '2026-11-03', 'en', 'Studafy AI study tools',
    '37f54c8de3e929e2ef15eb44d55fe60a370a85c7c0b491133a3bffed0cf9b4f2', now(), now()),
  ('ai_features', '2026-11-03', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    '9c574e03bb9877172f2118bdeec46f5dd4f019c2d8bed262fa37588991d23787', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
