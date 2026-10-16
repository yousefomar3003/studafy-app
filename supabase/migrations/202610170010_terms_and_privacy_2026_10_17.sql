-- Terms of Use and Privacy Policy, consent version 2026-10-17.
--
-- Privacy policy 1.5 and terms of use 1.3, published by the owner's decision
-- on 2026-10-17 WITHOUT legal review (DL-068); counsel reviews them later
-- (docs/legal/questions-for-counsel-2026-10.md). They make the text match
-- what the app does at launch:
--
--   * the AI study tools are on (DL-062), for students in a class only,
--     after a separate AI consent (a parent's, for a managed child); names
--     Studafy knows are replaced before anything is sent, photos are sent
--     as they are (ADR-0043), helper photos are kept 30 days (DL-060), and
--     the Together AI processing agreement is not yet in place;
--   * Studafy reviews safety reports and may act on them, with a Telegram
--     alert that carries ids only (DL-063, DL-066, PRs #71 and #97);
--   * Studafy creates no meetings; a shared Meet link opens under Google's
--     terms (DL-065);
--   * processors: Cloudflare (R2 backups in the EU, the alert relay,
--     Turnstile, the legal pages), Telegram; GitHub no longer stores
--     backups (PR #69); no outside malware scanner;
--   * the inactive-account warning is always emailed, and the account is
--     kept if it cannot be delivered (PR #73);
--   * the export lists files rather than including them, and what it leaves
--     out (PR #72, DL-060).
--
-- The in-app text no longer says names are never sent to the AI provider,
-- so people must see it again: a new consent version, not a correction.
--
-- Governing documents: docs/legal/privacy-policy.md (1.5) and
-- docs/legal/terms-of-use.md (1.3). content_hash is the SHA-256 of the exact
-- in-app text in that language (policyTermsBody, a blank line,
-- policyPrivacyBody); lib/core/account_lifecycle.dart moves to this version
-- with it. 2026-10-14 stays published, so consent already given still
-- stands, and the app asks for the new version at the next sign-in. The AI
-- notice (ai_features, 2026-10-15) is a separate purpose and is unchanged.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-10-17', 'en',
    'Studafy Terms of Use and Privacy Policy',
    'f849ead87b5be7b204f06e00a04564d5555d3015ae0713c855bc1a706a3d70bc', now(), now()),
  ('terms_and_privacy', '2026-10-17', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    'cdd741910f2ac5656fbb9e2745eaefd2406e4193b6d5e4588ef4098e2e96b978', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
