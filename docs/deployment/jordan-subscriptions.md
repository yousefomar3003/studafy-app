# Jordan digital subscription launch

Decision recorded 2026-09-22: the company is registered in Ireland, launch users
are in Jordan, and subscriptions unlock digital app features.

Use Apple In-App Purchase for the App Store build and Google Play Billing for
the Play Store build. Do not add Stripe checkout, card-entry fields, Apple Pay
wallet buttons, Google Pay wallet buttons, or external purchase links for these
digital subscriptions in the Jordan launch. Company registration in Ireland
does not place Jordanian storefront users in an EU/EEA alternative-payment
program. Apply the native-store approach globally for this initial release;
any regional alternative-payment implementation needs its own eligibility review.

Wallet payments are not equivalent to store billing. The native store controls
which funding methods the customer's account can use. Apple currently lists
most debit and credit cards for Jordan's Apple Account payments, not Apple Pay.
Do not promise all cards or wallet buttons will be available.

## Existing implementation and changes

The existing subscription repository uses in_app_purchase and backend receipt
verification; no Stripe checkout exists. The current client adapter and paywall
are for Parent Insights, not a completed student subscription catalogue.

Checkout now requires store availability, product ID, localized recurring price,
currency and a billing period. The paywall also requires HTTPS terms/privacy
URLs before enabling its purchase action, and renders a misconfigured policy
URL as plain text rather than a tappable link. While the catalogue and store
product query are still in flight the paywall says pricing is being checked
instead of declaring subscriptions unavailable. The purchase adapter refuses unknown
subscription terms and unsupported platforms instead of treating every
non-iOS platform as Google Play. Trial wording is conditional on eligibility,
and renewal text no longer invents a monthly period. Restore remains available.

These are payment-flow safeguards, not a guarantee of store approval.

## Still required

- Decide which student features are paid and the monthly/yearly plans.
- Create matching subscriptions/base plans in App Store Connect and Play Console,
  enable the intended storefront availability, and configure store verification
  credentials, notifications and the authoritative backend catalogue.
- Finish Apple developer enrollment and each store's agreements, banking and
  tax setup.
- Publish real privacy/terms pages and supply their HTTPS build defines.
- Exercise purchase, pending/guardian approval, cancellation, restore, renewal,
  refund and revocation using the stores' test environments and the deployed
  backend. Preserve server-side guardian-purchase policy for student accounts.
- Review the remaining app submission requirements; payments are only one part
  of review. No successful real store purchase is claimed by this change.

Sources checked:
- https://developer.apple.com/app-store/review/guidelines/#business
- https://support.google.com/googleplay/android-developer/answer/9858738
- https://support.google.com/googleplay/android-developer/answer/12570971
- https://support.apple.com/en-ca/111741

## Follow-up verification

The Google Play terms resolver now reads the exact selected subscription offer
and its infinite recurring pricing phase; it no longer switches to another
base plan or picks the highest-priced introductory phase. Prepaid plans are
not represented as auto-renewing. StoreKit 2 subscription periods are supported
without treating promotional offers as proof of free-trial eligibility.
StoreKit 1 trial durations include the number of periods. Catalogue caching
retains all returned products and permits retries after transient failures.

Validation: 311 Flutter tests passed, including selected-plan pricing,
introductory-versus-recurring prices, trials, prepaid plans, StoreKit 2 and
incomplete-offer guards. Flutter analysis and Dart feature boundaries passed.
No live purchase, store approval or completed student paywall is claimed.
