# Studafy API hostname

Public API origin: https://api.studafy.com
Native Turnstile page: https://api.studafy.com/auth/bot-check
Backend Turnstile expected hostname: api.studafy.com

## Where studafy.com's DNS lives (2026-11-03, DL-079)

studafy.com's nameservers are Vercel's (`ns1.vercel-dns.com`,
`ns2.vercel-dns.com`). Records are managed in Vercel → **Domains** →
`studafy.com` → **DNS records**. The hosts on it:

| Host | Served by |
| --- | --- |
| `studafy.com`, `www.studafy.com` | The website, Vercel project `waitlist-app` |
| `legal.studafy.com`, `app.studafy.com` | The legal site and the app-link files, Vercel project `studafy-legal` (`docs/deployment/legal-site.md`) |
| `api.studafy.com` | The production API on Fly (`studafy-api`), from launch-day cutover step 10 |

Cloudflare no longer holds the zone. It is still used for Turnstile (the
real widget's Hostname management lists `studafy.com`, which covers
`api.studafy.com`), the alert relay Worker, the backups in R2 and the
legal site's fallback copy on `studafy-legal.studafy.workers.dev`.

## Pointing api.studafy.com at Fly

Done on launch day, after the production API answers on
`https://studafy-api.fly.dev/readyz`
(`docs/deployment/production-cutover.md`, step 10):

1. `fly certs add api.studafy.com --app studafy-api`. It prints the records
   Fly needs.
2. In Vercel → Domains → `studafy.com` → DNS records, add them: either `A`
   and `AAAA` records for `api` to the addresses Fly printed, or a `CNAME`
   `api` → `studafy-api.fly.dev`; plus the `_acme-challenge.api` CNAME that
   lets Fly issue the certificate. If an older `api` record exists (the
   Cloudflare Tunnel below), remove it first. Do not touch the website's,
   `legal`'s, `app`'s or the email records.
3. `fly certs check api.studafy.com --app studafy-api` until the certificate
   is issued.
4. `https://api.studafy.com/readyz` returns 200.

The record is plain DNS: nothing proxies the API. So there is no SSL/TLS
mode, WAF or origin lock to set. `fly.api.toml` keeps
`ORIGIN_REQUIRE_CLOUDFLARE = "false"` (on, it would refuse every request)
and reads client addresses from Fly's `Fly-Client-IP`
(`CLIENT_IP_SOURCE = "fly"`); `scripts/fly-config.test.ts` pins both.

## History: the Cloudflare Tunnel to the Mac (2026-09-22, retired)

Before the Fly test copy, the plan was to publish the Mac-hosted API through
the Cloudflare Tunnel `a6098e5e-c7d5-4a94-b1af-09e5c019871e` as a proxied
`CNAME api → a6098e5e-c7d5-4a94-b1af-09e5c019871e.cfargotunnel.com`, while
studafy.com used Cloudflare's nameservers. That route is not used: testing
moved to Fly on 2026-10-03, and the zone moved to Vercel on 2026-11-03. If
the tunnel still exists in the Cloudflare dashboard (Networking → Tunnels),
it can be deleted; no record in Vercel's DNS points at it.

The Supabase OAuth provider callback and the native app's redirect
(`io.studafy.app://login-callback`, and the claimed link
`https://app.studafy.com/auth/callback`) do not depend on the API hostname.

After the cutover:

- https://api.studafy.com/healthz reports status ok.
- https://api.studafy.com/readyz passes its dependency checks.
- The app's student-ID lookup completes one real Turnstile challenge.
- Replaying the consumed token is rejected.

References:

- https://fly.io/docs/networking/custom-domain/
- https://vercel.com/docs/domains/managing-dns-records
- https://developers.cloudflare.com/turnstile/additional-configuration/hostname-management/
