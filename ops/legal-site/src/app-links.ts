// The two files that let the app claim https://app.studafy.com/auth/callback
// (AUTH-030, docs/release/auth030-site-association.md): Apple's
// apple-app-site-association (Universal Links) and Android's assetlinks.json
// (App Links). The legal site serves them under /.well-known/ on every host it
// answers, which includes app.studafy.com: the Vercel project studafy-legal
// (`bun run legal:deploy:vercel`), and the Cloudflare copy (wrangler.toml).
//
// APPLE_TEAM_ID is real (DL-079): Studafy Limited's team, which signs the iOS
// app (DEVELOPMENT_TEAM in ios/Runner.xcodeproj). ANDROID_SHA256 is still a
// PLACEHOLDER: while it is, assetlinks.json is well-formed but names no real
// certificate, so Android does not verify the domain and sign-in there keeps
// the custom-scheme fallback (io.studafy.app://login-callback). Replace it,
// run `bun test ops/legal-site` and `bun run legal:deploy:vercel`:
//   - ANDROID_SHA256: Play Console → Setup → App integrity → App signing key
//     certificate → SHA-256 (the Play App Signing key, not the upload key).

/** Apple Developer Team ID of Studafy Limited (Membership details). */
export const APPLE_TEAM_ID = "869AV76RU2";

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
