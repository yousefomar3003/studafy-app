-- Terms of Use and Privacy Policy, consent version 2026-11-03, and the AI
-- notice, version 2026-11-03 (owner, 2026-11-03; DL-081).
--
-- Terms of use 1.8 and privacy policy 2.0, published by the owner's decision
-- WITHOUT legal review, like 1.3 to 1.9 (DL-068); counsel reviews them later
-- (docs/legal/questions-for-counsel-2026-10.md). The policy is brought back
-- in line with the product:
--
--   * a parent creating a child account chooses the AI study tools with a
--     separate, unticked box that names Together AI (PR #151); left
--     unticked, they are off for the child. This replaces "on from the
--     start" (DL-074) in the in-app terms, privacy summary and AI notice;
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
--
-- A new child account still gets the parent's agreement to the current AI
-- notice from the trigger dl074_managed_child_ai_on (202611020030), now to
-- this version; the app withdraws it at once when the parent leaves the AI
-- box unticked. TODO(legal): DL-081 (questions-for-counsel 11.1).

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-11-03', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '21d3e8e15a5d80bc04d306ee7986d0644e37fb5a5d1cc6bee227668198f83e46', now(), now()),
  ('terms_and_privacy', '2026-11-03', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    '20288024e4baec8da76afdf388e0ba263fac03977fdfe3fa64e8e28b20e6115e', now(), now()),
  ('ai_features', '2026-11-03', 'en', 'Studafy AI study tools',
    '2f35e0bdba79e52f6bb300a9a056fee2ec9532cc5f827466d60fbdddce7ccb93', now(), now()),
  ('ai_features', '2026-11-03', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    '807335814bd33b8c8a93cc9fa38ca52a8f34f4509e4f1adfc4963f0ef93d70b7', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
