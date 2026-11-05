# Public website (studafy.com)

The public pages in `apps/school-web/`: home, features, about and contact,
in English (`/`) and Arabic (`/ar/...`). The School Portal page
(`/schools`) and every sign-in button are built only when
`VITE_PORTAL_PUBLIC=true`. Plan: `docs/planning/school-portal.md`
(sections 4, 4.9 and 11.1).

**Lives on the branch `feat/school-admin-web` only.** The public pages are
deployed from that branch (plan 11.1); nothing is merged into `main`.

## Build and check

```bash
bun install                       # at the repo root
cd apps/school-web
bun run dev                       # http://localhost:5173 (no prerender)
bun run build                     # vite build, then prerender to dist/
bun test apps/school-web          # from the repo root
bunx tsc --noEmit -p .            # in apps/school-web
```

`bun run build` writes static files only: `dist/index.html`,
`dist/features/index.html`, `dist/ar/...`, `404.html`, `ar/404.html`,
`sitemap.xml` and `robots.txt`. There is no server code.

## Settings

All optional; read at build time (Vite and the prerender script read the
same names).

| Variable | Default | What it does |
| --- | --- | --- |
| `VITE_SITE_URL` | `https://studafy.com` | Canonical, language and share links |
| `VITE_APP_STORE_URL` | none | The App Store page. Until both store URLs are set, the site shows "Coming soon to the App Store and Google Play" instead of badges |
| `VITE_PLAY_STORE_URL` | none | The Google Play page, `https://play.google.com/store/apps/details?id=com.studafy.light` once the app is live |
| `VITE_PORTAL_PUBLIC` | off | `true` builds `/schools` and the portal links. Leave off until the portal's gate (plan 11.2) |
| `VITE_PORTAL_URL` | `https://school.studafy.com` | Where "Open the School Portal" goes |

Only `https://` values are accepted; anything else is ignored.

## Vercel project

A **new** project, `studafy-web`, in the same Vercel account as
`waitlist-app` and `studafy-legal`. **Never** run `vercel link` from this
folder to either of those projects.

| Setting | Value |
| --- | --- |
| Git repository | `studafy-app`, production branch **`feat/school-admin-web`** |
| Root directory | `apps/school-web`, with "Include files outside the root directory" on (the Bun workspace lock is at the repo root) |
| Framework preset | Other |
| Install command | `cd ../.. && bun install --frozen-lockfile` |
| Build and output | From `apps/school-web/vercel.json` (`bun run build`, `dist`) |
| Environment variables | The table above, for Production; Preview can leave the store URLs empty |

`vercel.json` sets the security headers on every response:
Content-Security-Policy (only this site's own files; no inline scripts or
styles), HSTS for one year, `nosniff`, a strict referrer policy and a
permissions policy. It also caches `/assets/*` (file names carry a hash)
for a year. After the first deploy, check the preview address with a
header scanner (for example securityheaders.com) before moving the domain.

## Moving studafy.com (plan 4.9)

Only when every item in plan 11.1 is true, and the owner says go.

1. Export the waitlist sign-ups from the old site.
2. `studafy-web` → Settings → Domains → add `studafy.com`, then
   `www.studafy.com` set to **redirect** to `studafy.com`. Vercel offers to
   move both from `waitlist-app`; confirm.
3. Check `https://studafy.com`, `/ar`, `/features`, a missing page (404),
   and `https://legal.studafy.com/privacy` (must still be the legal site).
4. **Rollback:** add the domains back to `waitlist-app`. Keep that project,
   with no domain, for a few weeks.

**Never touch:** `legal.studafy.com` and `app.studafy.com` (project
`studafy-legal`; the app's links and sign-in return use `app.studafy.com`),
`api.studafy.com` (Fly), or the email records for `hello@studafy.com`.

## Pictures and badges

- `public/screens/<lang>/*.webp`: the store screenshots
  (`docs/store/screenshots/ios/<lang>/`), 600 px wide, made with
  `cwebp -q 82 -resize 600 0`. Retake them when the store screenshots
  change (they still show the Announcements tab, not Messages).
- `public/badges/`: Apple's and Google's official badges, unchanged, as
  their rules ask. Apple's Arabic badge is not in the repo yet, so Arabic
  pages show the English App Store badge. To add it, download the Arabic
  "Download on the App Store" badge from Apple's marketing tools, save it
  as `public/badges/app-store-ar.svg`, and use it in `StoreBadges`
  (`src/components/Parts.tsx`).
- `public/brand/share.jpg`: the 1200×630 picture shown when a link is
  shared.

## Writing the pages

- Words live in `src/i18n/en.ts` and `src/i18n/ar.ts`; the type in
  `src/i18n/types.ts` and `test/copy.test.ts` keep the two languages in
  step.
- Claims follow the store listing's rules (`docs/store/listing-copy.md`):
  only what the app does, no "best" or "#1", no prices, no competitor
  names. Re-read the listing before each release of the site.
- Arabic follows `docs/l10n/arabic-glossary.md` (صف for a class,
  ستودافاي in running text, plan names in Latin letters). Put a space
  between و and a Latin name (`App Store و Google Play`), or the line
  reads out of order.
- No company name, number or address anywhere; the footer says "© Studafy".
