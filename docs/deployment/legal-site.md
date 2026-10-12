# Legal site (privacy policy, terms, account deletion)

Launch plan 4.3. A temporary public home for the documents in `docs/legal`,
because Google Play needs a privacy policy link and an account deletion link
(`docs/store/google-play-data-safety.md`).

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
  and `_redirects`. wrangler runs the build before every deploy.
- **Hosting:** a Cloudflare Worker with static assets only (no script), on
  the account's `studafy.workers.dev` subdomain: `ops/legal-site/wrangler.toml`.
- **Tests:** `bun test ops/legal-site` (CI runs `bun test ... ops`).

## Deploy (owner approves)

```sh
npx wrangler deploy --config ops/legal-site/wrangler.toml
```

It needs a Cloudflare login (`npx wrangler login`) on the account that owns
`studafy.workers.dev`. The pages are then at
`https://studafy-legal.studafy.workers.dev/privacy` and so on.

Before deploying, check that the deletion behaviour the pages describe is
live: they describe the executor after launch plan 3.6b
(`202610110004_account_deletion_gaps.sql`).

To check locally: `cd ops/legal-site && npx wrangler dev`, then open
`http://localhost:8787/privacy`.

## Moving to our own domain

Every link in the pages is path-absolute or relative, so nothing in the
pages changes:

1. Uncomment the `routes` line in `ops/legal-site/wrangler.toml` with the
   chosen host (the zone must be on the same Cloudflare account) and deploy.
2. Point `STUDAFY_PRIVACY_URL` and `STUDAFY_TERMS_URL` (app build, see
   `subscriptions.md`), the Play Console and App Store Connect at the new
   address.
3. Keep `workers_dev = true` for a while so old links keep working.
