-- Terms of Use and Privacy Policy, consent version 2026-09-30.2.
--
-- Two changes people must see before they accept:
--
--   * Family+ is now the parent's own plan - one monthly subscription for up
--     to 4 linked children, or a larger one for up to 8, covering children in
--     the order they were linked - and says what it shows for each child
--     (marks by class, trends, attendance, missing work, missed tests).
--   * A profile photo is kept on the device only and never uploaded.
--
-- Governing documents: docs/legal/privacy-policy.md (1.2) and
-- docs/legal/terms-of-use.md (1.1). content_hash is the SHA-256 of the exact
-- in-app text in that language (policyTermsBody, a blank line,
-- policyPrivacyBody); lib/core/account_lifecycle.dart moves to this version
-- with it. 2026-09-30 stays published, so consent already given still
-- stands, and the app asks for the new version at the next sign-in.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-09-30.2', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '65f10525a93282a93e9fc8381ddd6bf701d6a609bedf93e0df3c2eccc50519b7', now(), now()),
  ('terms_and_privacy', '2026-09-30.2', 'ar',
    'شروط استخدام ستدافاي وسياسة الخصوصية',
    '58407aed64743918a8be092fb53ef316b6636cbefd9ca488955b5912d275c38f', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
