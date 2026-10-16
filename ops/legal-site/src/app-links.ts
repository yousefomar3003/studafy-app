// The two files that let the app claim https://app.studafy.com/auth/callback
// (AUTH-030, docs/release/auth030-site-association.md): Apple's
// apple-app-site-association (Universal Links) and Android's assetlinks.json
// (App Links). The legal-site Worker serves them under /.well-known/ on every
// host it answers, which includes app.studafy.com (wrangler.toml).
//
// Both identifiers below are PLACEHOLDERS until the accounts exist. While they
// are, the files are well-formed but name no real app, so neither platform
// verifies the domain and sign-in keeps using the custom-scheme fallback
// (io.studafy.app://login-callback). Replace them, run `bun test ops/legal-site`
// and `bun run legal:deploy`:
//   - APPLE_TEAM_ID: Apple Developer → Membership details → Team ID
//     (10 characters, e.g. A1B2C3D4E5), once Apple approves the organisation.
//   - ANDROID_SHA256: Play Console → Setup → App integrity → App signing key
//     certificate → SHA-256 (the Play App Signing key, not the upload key).

/** Placeholder: replace with the Apple Developer Team ID. */
export const APPLE_TEAM_ID = "PENDING_APPLE_TEAM_ID";

/** Placeholder: replace with the Play App Signing certificate SHA-256. */
export const ANDROID_SHA256 = "PENDING_PLAY_APP_SIGNING_SHA256";

/** iOS bundle identifier and Android package name (ADR-0015, DL-058). */
export const APP_ID = "com.studafy.light";

/** The claimed path: AuthCallbackGuard.defaultTargets in the app. */
export const CALLBACK_PATH = "/auth/callback";

/** True while either identifier is still a placeholder. */
export function appLinksPending(): boolean {
  return APPLE_TEAM_ID.startsWith("PENDING") ||
    ANDROID_SHA256.startsWith("PENDING");
}

/** /.well-known/apple-app-site-association (no extension, JSON). */
export function appleAppSiteAssociation(): string {
  const appID = `${APPLE_TEAM_ID}.${APP_ID}`;
  return `${
    JSON.stringify(
      {
        applinks: {
          details: [
            {
              appIDs: [appID],
              components: [
                { "/": CALLBACK_PATH },
                { "/": `${CALLBACK_PATH}/*` },
              ],
            },
          ],
        },
      },
      null,
      2,
    )
  }\n`;
}

/** /.well-known/assetlinks.json */
export function assetLinks(): string {
  return `${
    JSON.stringify(
      [
        {
          relation: ["delegate_permission/common.handle_all_urls"],
          target: {
            namespace: "android_app",
            package_name: APP_ID,
            sha256_cert_fingerprints: [ANDROID_SHA256],
          },
        },
      ],
      null,
      2,
    )
  }\n`;
}
