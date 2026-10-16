# AUTH-030 claimed-link site association

The OAuth callback should be an owned HTTPS link, not a custom URI scheme. A
custom scheme can be registered by any app on the device; a domain can only be
claimed by whoever controls it. Until the two files below carry real values,
the custom scheme `io.studafy.app://login-callback` remains the working
fallback and the HTTPS intent filter/entitlement are inert.

The callback domain is `app.studafy.com` (DL-067). Since 2026-10-16 both files
are live there, served by the legal-site Worker
(`docs/deployment/legal-site.md`) and generated from
`ops/legal-site/src/app-links.ts`, with **placeholders** for the two values
below (`PENDING_APPLE_TEAM_ID`, `PENDING_PLAY_APP_SIGNING_SHA256`). A
placeholder names no real app, so neither platform verifies the domain yet.
When a value is known: set it in `app-links.ts`, run
`bun test ops/legal-site`, then `bun run legal:deploy`.

Both files are blocked on work outside engineering:

| File | Blocked on |
|---|---|
| `apple-app-site-association` | D1 — Apple Developer organisation account, for the Team ID |
| `assetlinks.json` | D2 — Play App Signing, for the release certificate fingerprint |

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
