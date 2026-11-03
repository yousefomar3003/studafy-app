// The two files that let the app claim https://app.studafy.com/auth/callback
// (AUTH-030, docs/release/auth030-site-association.md): Apple's
// apple-app-site-association (Universal Links) and Android's assetlinks.json
// (App Links). The legal site serves them under /.well-known/ on every host it
// answers, which includes app.studafy.com: the Vercel project studafy-legal
// (`bun run legal:deploy:vercel`), and the Cloudflare copy (wrangler.toml).
//
// Both are real. APPLE_TEAM_ID (DL-079): Studafy Limited's team, which signs
// the iOS app (DEVELOPMENT_TEAM in ios/Runner.xcodeproj). ANDROID_SHA256
// (owner, 2026-11-04): Play Console → Test and release → App integrity →
// App signing key certificate → SHA-256 - the key Google signs the store
// build with, not the upload key. If Play's signing key ever changes, replace
// it, run `bun test ops/legal-site` and `bun run legal:deploy:vercel`.

/** Apple Developer Team ID of Studafy Limited (Membership details). */
export const APPLE_TEAM_ID = "869AV76RU2";

/** Play App Signing certificate SHA-256 of com.studafy.light. */
export const ANDROID_SHA256 =
  "11:36:E6:97:2A:3B:A8:91:A3:8E:71:E6:1D:1C:1D:F0:82:D2:F5:AC:0C:20:E2:70:A4:DF:59:1F:3E:FE:F3:E8";

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
