-- Terms of Use and Privacy Policy, consent version 2026-10-21.
--
-- Terms of use 1.4 and privacy policy 1.6, published by the owner's decision
-- on 2026-10-20 WITHOUT legal review, like 1.3 / 1.5 (DL-068); counsel
-- reviews them later (docs/legal/questions-for-counsel-2026-10.md, §8).
-- They follow DL-071 (migration 202610210010):
--
--   * a student subscribes to Studafy Plus or Max themselves, in the app,
--     with no approval step in Studafy;
--   * payment is made through Google Play or the App Store with the payment
--     method on that store account; for a child, that account and its
--     payment method should belong to, or be controlled by, a parent or
--     guardian, who is responsible for purchases made with it, and Google
--     Family Link and Apple Ask to Buy let a parent approve purchases;
--   * subscriptions renew until cancelled in the store, refunds follow the
--     store's rules, and Studafy never sees card details;
--   * the app no longer records a parent's approval of a purchase; requests
--     made before are kept as billing records.
--
-- The in-app text changed (policyTermsBody SUBSCRIPTIONS, policyPrivacyBody
-- PAYMENTS), so people must see it again: a new consent version, not a
-- correction.
--
-- Governing documents: docs/legal/terms-of-use.md (1.4) and
-- docs/legal/privacy-policy.md (1.6). content_hash is the SHA-256 of the
-- exact in-app text in that language (policyTermsBody, a blank line,
-- policyPrivacyBody); lib/core/account_lifecycle.dart moves to this version
-- with it (test/l10n/policy_consent_version_test.dart checks the two agree).
-- 2026-10-17 and every earlier version stay published, so consent already
-- given still stands, and the app asks for the new version at the next
-- sign-in. The AI notice (ai_features, 2026-10-15) is a separate purpose and
-- is unchanged.

insert into public.consent_policies (
  purpose, policy_version, locale, title, content_hash,
  published_at, effective_at
)
values
  ('terms_and_privacy', '2026-10-21', 'en',
    'Studafy Terms of Use and Privacy Policy',
    '8f239477c90bd2c39dcdcb6135c640c730b8796be27951fdbf6cd7553516d1d9', now(), now()),
  ('terms_and_privacy', '2026-10-21', 'ar',
    'شروط استخدام ستودافاي وسياسة الخصوصية',
    '076b9239d6ea6cdbac09ed1aec6a491841494c81234355ef92b8997eca79d025', now(), now())
on conflict (purpose, policy_version, locale) do nothing;
