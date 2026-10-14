-- Terms of Use and Privacy Policy, consent version 2026-10-14.
--
-- Privacy policy 1.4 (approved by counsel for publication on 2026-10-14)
-- sets fixed retention periods (DL-057, migration 202610140001). The in-app
-- summary no longer says records of significant actions can never be
-- removed: nobody can edit them, and they are deleted when their retention
-- period ends. It also names the current hosts (Fly.io, Axiom, Sentry; no
-- longer Amazon Web Services) and says Supabase keeps sign-in IP addresses
-- for up to 7 days. People must see this before the purges run, so this is
-- a new consent version, not a correction.
--
-- Governing documents: docs/legal/privacy-policy.md (1.4) and
-- docs/legal/terms-of-use.md (1.1). content_hash is the SHA-256 of the exact
-- in-app text in that language (policyTermsBody, a blank line,
-- policyPrivacyBody); lib/core/account_lifecycle.dart moves to this version
-- with it. 2026-09-30.2 stays published, so consent already given still
-- stands, and the app asks for the new version at the next sign-in.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-10-14', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '3c92a507fa9c74e4b82a543ea9462db927c265713cf622397d53c87fe1594084', now(), now()),
  ('terms_and_privacy', '2026-10-14', 'ar',
    'شروط استخدام ستدافاي وسياسة الخصوصية',
    '40f66a724df2d2dc8c018ecc86d01fef41c77d295e01cf2c1bdec61af870c1cc', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
