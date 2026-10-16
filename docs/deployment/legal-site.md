# Legal site (privacy policy, terms, account deletion)

Launch plan 4.3. The public home for the documents in `docs/legal`, because
Google Play needs a privacy policy link and an account deletion link
(`docs/store/google-play-data-safety.md`). Since 2026-10-16 (DL-067) it is at
**`https://legal.studafy.com`**; the first address,
`https://studafy-legal.studafy.workers.dev`, still answers with the same pages.
The same Worker also serves the app-link association files on
**`app.studafy.com`** (below).

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
  `ops/legal-site/public` (gitignored), with `_headers` (security headers)
  and `_redirects`. `bun run legal:deploy` builds, then deploys.
- **Hosting:** a Cloudflare Worker with static assets only (no script):
  `ops/legal-site/wrangler.toml`. It answers on two Workers custom domains,
  `legal.studafy.com` and `app.studafy.com`, and on the account's
  `studafy.workers.dev` subdomain. The `studafy.com` zone is on the same
  Cloudflare account; a custom domain makes Cloudflare create that one
  host's DNS record and certificate, nothing else. The root `studafy.com`
  and `www.studafy.com` (the marketing site on Vercel) are not touched.
- **Association files:** `ops/legal-site/src/app-links.ts` builds
  `/.well-known/apple-app-site-association` (served as `application/json`
  through `_headers`) and `/.well-known/assetlinks.json`
  (`docs/release/auth030-site-association.md`).
- **Tests:** `bun test ops/legal-site` (CI runs `bun test ... ops`).

## Deploy (owner approves)

```sh
bun run legal:deploy    # builds docs/legal into ops/legal-site/public, then wrangler deploy
```

It needs a Cloudflare login (`npx wrangler login`) on the account that owns
`studafy.workers.dev` and the `studafy.com` zone. The pages are then at
`https://legal.studafy.com/privacy` and so on.

Before deploying, check that the deletion behaviour the pages describe is
live: they describe the executor after launch plan 3.6b
(`202610110004_account_deletion_gaps.sql`).

To check locally: `bun run legal:build && cd ops/legal-site && npx wrangler dev`,
then open `http://localhost:8787/privacy`.

## Addresses the app and the stores use

| Where | Value |
|---|---|
| `STUDAFY_PRIVACY_URL` (app build, `subscriptions.md`) | `https://legal.studafy.com/privacy` |
| `STUDAFY_TERMS_URL` | `https://legal.studafy.com/terms` |
| Play Console privacy policy, App Store Connect privacy policy URL | `https://legal.studafy.com/privacy` |
| Play Console delete account URL | `https://legal.studafy.com/delete-account` |

Every link in the pages is path-absolute or relative, so a host is only a
`routes` entry in `wrangler.toml`. Static assets cannot tell hosts apart:
the legal pages also answer on `app.studafy.com` and the association files
on `legal.studafy.com`. That is harmless; the app claims only
`app.studafy.com`. Keep `workers_dev = true` so links already handed out
keep working.
