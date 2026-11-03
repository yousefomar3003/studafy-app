# AUTH-030 claimed-link site association

The OAuth callback should be an owned HTTPS link, not a custom URI scheme. A
custom scheme can be registered by any app on the device; a domain can only be
claimed by whoever controls it. Until the two files below carry real values,
the custom scheme `io.studafy.app://login-callback` remains the working
fallback and the HTTPS intent filter/entitlement are inert.

The callback domain is `app.studafy.com` (DL-067). Both files are live
there, served by the legal site (`docs/deployment/legal-site.md`; the
Vercel project `studafy-legal` since 2026-11-03) and generated from
`ops/legal-site/src/app-links.ts`. Since DL-079 the Apple file names the
real team, `869AV76RU2` (Studafy Limited), with `com.studafy.light`. Since
2026-11-04 the Android file names the Play App Signing certificate
(`11:36:E6:…:F3:E8`), so Android verifies the domain. If Play's signing key
ever changes: set it in `app-links.ts`, run `bun test ops/legal-site`, then
`bun run legal:deploy:vercel`.

| File | State |
|---|---|
| `apple-app-site-association` | Real Team ID `869AV76RU2` (DL-079); live after the next `legal:deploy:vercel` |
| `assetlinks.json` | Blocked on D2 — Play App Signing, for the release certificate fingerprint (Play Console → Setup → App integrity → App signing key certificate → SHA-256) |

Both must be served from the root of the callback host, `app.studafy.com`.

## Apple

Serve at `https://app.studafy.com/.well-known/apple-app-site-association`, as
`application/json`, with **no** `.json` extension, over HTTPS, with no redirect
and no authentication.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.studafy.light"],
        "components": [
          { "/": "/auth/callback" },
          { "/": "/auth/callback/*" }
        ]
      }
    ]
  }
}
```

(`appIDs` and `components` are the current format, iOS 13 and later; the app
targets iOS 15.) Replace `TEAMID` (`APPLE_TEAM_ID` in `app-links.ts`) with
the Team ID from the Apple Developer account. Each entry of `appIDs` is
`<Team ID>.<bundle identifier>`; the bundle identifier is `com.studafy.light`
(ADR-0015, DL-058).

## Android

Serve at `https://app.studafy.com/.well-known/assetlinks.json`, as
`application/json`, over HTTPS, with no redirect.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.studafy.light",
      "sha256_cert_fingerprints": [
        "PLAY_APP_SIGNING_SHA256"
      ]
    }
  }
]
```

Replace `PLAY_APP_SIGNING_SHA256` (`ANDROID_SHA256` in `app-links.ts`, as
colon-separated upper-case hex) with the **Play App Signing** certificate
fingerprint from the Play Console (Setup → App integrity → App signing key
certificate), not the upload key. Play
re-signs uploads with the app signing key, so verification against the upload
key fingerprint fails on installed builds.

If CI builds are also installed directly for testing, add that debug/upload
fingerprint as a second entry; the array accepts several (the test in
`ops/legal-site/test/site.test.ts` then needs the second entry too).

## Verifying after publication

- Android: `adb shell pm verify-app-links --re-verify com.studafy.light`, then
  `adb shell pm get-app-links com.studafy.light` — the domain must report
  `verified`.
- iOS: install a TestFlight build and open
  `https://app.studafy.com/auth/callback?code=test` from Notes or Messages. It
  must open the app rather than Safari. The
  [AASA validator](https://app-site-association.cdn-apple.com/a/v1/app.studafy.com)
  shows what Apple's CDN has cached; propagation is not instant.
- Both: confirm `AuthCallbackGuard` still refuses a lookalike host by running
  `flutter test test/features/session/deep_link_hijack_test.dart`.

Until these checks pass on physical devices, the claimed-link posture is
**unverified** and must not be reported as complete.
