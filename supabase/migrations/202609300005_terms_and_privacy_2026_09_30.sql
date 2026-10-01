-- Terms of Use and Privacy Policy, consent version 2026-09-30.
--
-- The policy people accept before signing in now describes everything the
-- app does: paper marks kept private until published, corrections that keep
-- the mark they replaced, the attendance lock rule and its history,
-- deadlines and extensions, replaced files kept for the school, child
-- accounts a parent manages, Family+, voice notes, meeting links, encrypted
-- backups, what the AI study tools send and to whom, and that this version
-- of the app has no school administrator. The governing documents are
-- docs/legal/privacy-policy.md (1.1) and docs/legal/terms-of-use.md (1.0).
--
-- content_hash is the SHA-256 of the exact in-app text a person accepts in
-- that language (policyTermsBody, a blank line, policyPrivacyBody), so a
-- consent record points at the words that were shown. The client version in
-- lib/core/account_lifecycle.dart moves to this version with it; the earlier
-- version stays published, so consent already given still stands.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-09-30', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '38d86bc6f64ac5f383535cdf1eb88884fd66bc160433966b747854c0482c4cd6', now(), now()),
  ('terms_and_privacy', '2026-09-30', 'ar',
    'شروط استخدام ستدافاي وسياسة الخصوصية',
    '70394c17c03cff48b37a6b458cd5bcfa99ee975de273a3a3a7108bd1abfaa445', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
