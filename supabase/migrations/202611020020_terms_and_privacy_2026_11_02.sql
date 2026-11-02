-- Terms of Use and Privacy Policy, consent version 2026-11-02, and the AI
-- notice, version 2026-11-02 (owner, 2026-11-02; DL-074).
--
-- Terms of use 1.7 and privacy policy 1.9, published by the owner's decision
-- WITHOUT legal review, like 1.3 to 1.8 (DL-068); counsel reviews them later
-- (docs/legal/questions-for-counsel-2026-10.md). Two changes:
--
--   * the AI study tools are on from the start for a child account a parent
--     creates, and the parent can turn them off (they were off until the
--     parent agreed) - 202611020030;
--   * AI-suggested marks (DL-073) no longer have a student opt-out: the
--     teacher may ask for them for any written work, and still decides
--     every mark.
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
  ('terms_and_privacy', '2026-11-02', 'en',
    'Studafy Terms of Use and Privacy Policy',
    'fda85733f0def04d43a0365f3d7c51534e018706a245381cd6d9c1642079ff53', now(), now()),
  ('terms_and_privacy', '2026-11-02', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    '9c4cb958280587f149e26464ec7a490f4095c64378d4bf20fea573e55c63b1f0', now(), now()),
  ('ai_features', '2026-11-02', 'en', 'Studafy AI study tools',
    '6733e5f55295f5ecb112fdf277d431e3ddf79a689840552d9890aea1bb16da13', now(), now()),
  ('ai_features', '2026-11-02', 'ar', 'أدوات الدراسة بالذكاء الاصطناعي في ستودافاي',
    'a7e0314d99cd72242dd756fcad53fabb4addc36dd6b4db327ddc70d3f7d06737', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
