# Legal site (privacy policy, terms, account deletion)

Launch plan 4.3. The public home for the documents in `docs/legal`, because
Google Play needs a privacy policy link and an account deletion link
(`docs/store/google-play-data-safety.md`). It is at
**`https://legal.studafy.com`** (DL-067), served since 2026-11-03 by the
Vercel project **`studafy-legal`** (DL-079), which also serves the app-link
association files on **`app.studafy.com`** (below). The first address,
`https://studafy-legal.studafy.workers.dev` (Cloudflare), stays as a
fallback copy with the same pages.

| Page | English | Arabic |
|---|---|---|
| Privacy Policy | `/privacy` | `/ar/privacy` |
| Terms of Use | `/terms` | `/ar/terms` |
| Delete your account | `/delete-account` | `/ar/delete-account` |

`/` redirects to `/privacy` and `/ar` to `/ar/privacy`.

## How it works

- **Source:** `docs/legal/*.md` (English) and `docs/legal/ar/*.md` (Arabic).
  Legal-review notes are HTML comments in those files. The build removes
  every comment, so they never reach a page; a test checks this.
- **Build:** `ops/legal-site/build.ts` renders them into
  `ops/legal-site/public` (gitignored) as `.html` pages, with `vercel.json`
  (security headers, clean URLs, the two redirects, and the
  `application/json` type of the Apple association file) for Vercel, and
  `_headers` and `_redirects` for the Cloudflare copy. A rebuild keeps
  `public/.vercel`, Vercel's link to the project.
- **Hosting:** the Vercel project `studafy-legal`, a static deployment of
  `ops/legal-site/public`, with the domains `legal.studafy.com` and
  `app.studafy.com`. studafy.com's DNS is on Vercel (nameservers
  `ns1/ns2.vercel-dns.com`, `docs/deployment/studafy-domain.md`), so adding
  a domain to the project is all a host needs. The website
  (`studafy.com`, `www.studafy.com`, project `waitlist-app`) is a separate
  project and is not touched.
- **Fallback:** the Cloudflare Worker with static assets only
  (`ops/legal-site/wrangler.toml`) still answers on
  `studafy-legal.studafy.workers.dev`, so links already handed out keep
  working. Its `legal.studafy.com` and `app.studafy.com` custom domains no
  longer receive traffic: those names resolve through Vercel's DNS.
- **Association files:** `ops/legal-site/src/app-links.ts` builds
  `/.well-known/apple-app-site-association` (served as `application/json`)
  and `/.well-known/assetlinks.json`
  (`docs/release/auth030-site-association.md`). The Apple file names Studafy
  Limited's team `869AV76RU2` and `com.studafy.light` (DL-079); the Android
  file still carries the placeholder `PENDING_PLAY_APP_SIGNING_SHA256` until
  the Play App Signing certificate's SHA-256 is copied from Play Console.
- **Tests:** `bun test ops/legal-site` (CI runs `bun test ... ops`).

## Deploy (owner approves)

```sh
bun run legal:deploy:vercel   # builds docs/legal into ops/legal-site/public, then vercel deploy --prod
```

It needs a Vercel login (`npx vercel login`) on the team that owns
`studafy-legal`. The first time, `vercel` asks which project the folder is:
choose the existing `studafy-legal`; the link is kept in
`ops/legal-site/public/.vercel` (gitignored). The pages are then at
`https://legal.studafy.com/privacy` and so on.

The Cloudflare fallback is deployed separately, with a Cloudflare login
(`npx wrangler login`) on the account that owns `studafy.workers.dev`:

```sh
bun run legal:deploy          # the same build, then wrangler deploy
```

Deploy both when the pages change, so the fallback never shows an older
policy.

Before deploying, check that the deletion behaviour the pages describe is
live: they describe the executor after launch plan 3.6b
(`202610110004_account_deletion_gaps.sql`).

To check locally: `bun run legal:build && cd ops/legal-site && npx wrangler dev`,
then open `http://localhost:8787/privacy`.

After a deploy, check:

- `https://legal.studafy.com/privacy` and `/ar/privacy` load;
- `https://app.studafy.com/.well-known/apple-app-site-association` answers
  `200` with `Content-Type: application/json`, no redirect, and names
  `869AV76RU2.com.studafy.light`;
- `https://app.studafy.com/.well-known/assetlinks.json` answers `200`.

## Addresses the app and the stores use

| Where | Value |
|---|---|
| `STUDAFY_PRIVACY_URL` (app build, `config/dart-defines.production.example.json`) | `https://legal.studafy.com/privacy` |
| `STUDAFY_TERMS_URL` | `https://legal.studafy.com/terms` |
| Play Console privacy policy, App Store Connect privacy policy URL | `https://legal.studafy.com/privacy` |
| Play Console delete account URL | `https://legal.studafy.com/delete-account` |

Every link in the pages is path-absolute or relative, so a host is only a
domain on the Vercel project. Static files cannot tell hosts apart: the
legal pages also answer on `app.studafy.com` and the association files on
`legal.studafy.com`. That is harmless; the app claims only
`app.studafy.com`.
