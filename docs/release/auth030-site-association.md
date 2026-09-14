# AUTH-030 claimed-link site association

The OAuth callback should be an owned HTTPS link, not a custom URI scheme. A
custom scheme can be registered by any app on the device; a domain can only be
claimed by whoever controls it. Until the two files below are published, the
custom scheme `io.studafy.app://login-callback` remains the working fallback
and the HTTPS intent filter/entitlement are inert.

Both files are blocked on work outside engineering:

| File | Blocked on |
|---|---|
| `apple-app-site-association` | D1 — Apple Developer organisation account, for the Team ID |
| `assetlinks.json` | D2 — Play App Signing, for the release certificate fingerprint |

Both must be served from the apex of the callback domain (D5).

## Apple

Serve at `https://app.studafy.io/.well-known/apple-app-site-association`, as
`application/json`, with **no** `.json` extension, over HTTPS, with no redirect
and no authentication.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.io.studafy.app",
        "paths": ["/auth/callback", "/auth/callback/*"]
      }
    ]
  }
}
```

Replace `TEAMID` with the Team ID from the Apple Developer account. `appID` is
`<Team ID>.<bundle identifier>`; the bundle identifier is `io.studafy.app`
(ADR-0015, DL-029).

## Android

Serve at `https://app.studafy.io/.well-known/assetlinks.json`, as
`application/json`, over HTTPS, with no redirect.

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "io.studafy.app",
      "sha256_cert_fingerprints": [
        "REPLACE_WITH_PLAY_APP_SIGNING_SHA256"
      ]
    }
  }
]
```

Use the **Play App Signing** certificate fingerprint from the Play Console
(Setup → App integrity → App signing key certificate), not the upload key. Play
re-signs uploads with the app signing key, so verification against the upload
key fingerprint fails on installed builds.

If CI builds are also installed directly for testing, add that debug/upload
fingerprint as a second entry; the array accepts several.

## Verifying after publication

- Android: `adb shell pm verify-app-links --re-verify io.studafy.app`, then
  `adb shell pm get-app-links io.studafy.app` — the domain must report
  `verified`.
- iOS: install a TestFlight build and open
  `https://app.studafy.io/auth/callback?code=test` from Notes or Messages. It
  must open the app rather than Safari. The
  [AASA validator](https://app-site-association.cdn-apple.com/a/v1/app.studafy.io)
  shows what Apple's CDN has cached; propagation is not instant.
- Both: confirm `AuthCallbackGuard` still refuses a lookalike host by running
  `flutter test test/auth030_deep_link_hijack_test.dart`.

Until these checks pass on physical devices, the claimed-link posture is
**unverified** and must not be reported as complete.
