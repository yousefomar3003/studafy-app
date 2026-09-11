# ADR-0015: Application identity and store accounts

- Status: Accepted — identity decided; signing and privacy manifests remain open
- Date: 2026-09-11
- Decision log: DL-029 (resolves the identity portion of DL-015)

## Context

Both platforms still carry the generated placeholder identity
`com.example.studafy`. ADR-0003 committed Studafy to iOS and Android but
explicitly deferred final application identity, signing, and privacy manifests
to REL-002 under DL-015, which has been open since 2026-09-10.

That deferral now blocks the first launch task. Neither store console can be
configured without a final identifier: Apple requires a registered App ID before
Sign in with Apple credentials or an App Store Connect record can exist, and
Google Play refuses `com.example.*` uploads outright. The identifier is also
irreversible — after the first publish to either store it cannot be changed
without abandoning the listing, its reviews, and its installed base.

A separate constraint shapes the choice. `io.studafy.app` is already the OAuth
redirect scheme in five functional locations: `ios/Runner/Info.plist:20`,
`android/app/src/main/AndroidManifest.xml:31`, `supabase/config.toml:11`,
`lib/features/session/data/supabase_session_repository.dart:30`, and
`README.md:96`. Any other identifier forces all five to change or accepts a
permanent scheme/identifier mismatch across the auth path.

The registered legal entity exists, so organisation accounts are available on
both stores. Organisation accounts are required in substance rather than
preference: an education product sold to schools cannot credibly publish under
an individual's personal name, and school procurement expects the vendor of
record to be the entity.

## Decision

**`io.studafy.app` is the permanent bundle identifier, Android application ID,
and Android namespace on both platforms.** The user-visible display name is
`Studafy`.

Store accounts are registered as **Organization** accounts under the registered
legal entity on both Apple Developer Program and Google Play Console, with a
named Account Holder and a named backup administrator.

The identifier is **decided now and applied at the REL-002 cutover**, not
immediately. The SEC-001 release guards in `android/app/build.gradle.kts` and
`ios/Runner.xcodeproj/project.pbxproj` remain in force. Those guards are
currently the only control preventing a store upload of an application whose
core screens still read and write local SQLite, and they are removed only after
the Phase 10 gate, through a reviewed forward change.

Registration procedure, the cutover edit list, and credential custody are
recorded in `docs/release/rel-002-store-accounts.md`.

## Consequences

- The identifier cannot be revisited after first publish. This ADR is the
  binding record; superseding it after release is not practically possible.
- Adopting the existing redirect scheme costs zero churn in the auth path. No
  OAuth redirect, deep link, or Supabase callback changes.
- DL-015 is **not** closed. Signing material, privacy manifests, and store
  account completion remain open under it.
- Organisation enrolment introduces a D-U-N-S dependency with a multi-week lead
  time. Starting it now removes that wait from the critical path rather than
  shortening the engineering work.
- Apple guideline 4.8 obliges Sign in with Apple because the app offers Google
  and Microsoft sign-in. The Apple account must therefore produce Sign in with
  Apple credentials before Phase 3 authentication work can be completed against
  a real provider.
- Account renewal becomes an operational obligation: the Apple membership is
  annual, and a lapse removes the app from sale.
- No behaviour, build, or containment control changes as a result of this ADR.
