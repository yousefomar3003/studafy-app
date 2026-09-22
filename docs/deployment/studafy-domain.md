# Studafy API hostname

Public API origin: https://api.studafy.com
Native Turnstile page: https://api.studafy.com/auth/bot-check
Backend Turnstile expected hostname: api.studafy.com
Existing tunnel: a6098e5e-c7d5-4a94-b1af-09e5c019871e

The ignored mobile development configuration and server .env.hosted now use
this hostname with Turnstile enabled. This prepares the deployment; it does
not create Cloudflare DNS records or change the existing widget's allowlist.

## Publish the existing tunnel

In Cloudflare Dashboard, open Networking > Tunnels, select the tunnel above,
then Routes > Add route > Published application. Some dashboard versions
call this Published application routes.

| Field | Value |
| --- | --- |
| Subdomain | api |
| Domain | studafy.com |
| Path | Leave empty |
| Service type | HTTP |
| Service URL | localhost:8080 |

Saving a published application route normally creates its proxied DNS record.
If a DNS record must be added separately, the intended record is:

| Field | Value |
| --- | --- |
| Type | CNAME |
| Name | api |
| Target | a6098e5e-c7d5-4a94-b1af-09e5c019871e.cfargotunnel.com |
| Proxy status | Proxied |

A DNS record alone does not configure tunnel ingress; both must point to this
application. Do not replace the root studafy.com website records.

## Existing Turnstile widget

Open Turnstile, select the existing widget and add api.studafy.com under
Hostname management. Preserve its existing mode and clearance setting.
There is no need to create another widget or change the supplied keys.

## Backend prerequisites

The tunnel reaches the API on this Mac, so the Mac, tunnel connector and API
must be running. Complete the hosted project's DATABASE_URL in .env.hosted,
upgrade its schema, and start the matching backend using bun run dev:hosted.
Do not expose the older local-database API as the hosted account backend.

The Supabase OAuth provider callback stays:
https://eamewgaptdfqzpmayavx.supabase.co/auth/v1/callback

The native app redirect remains io.studafy.app://login-callback.
The API subdomain does not replace either OAuth callback.

## Verification boundary

On 2026-09-22, studafy.com used Cloudflare nameservers and an authoritative
lookup of api.studafy.com returned NXDOMAIN. No Cloudflare management API
credential was available in this session. DNS, tunnel ingress, and the widget
allowlist were therefore not changed remotely. Local configuration validation
passed with Turnstile enabled and the exact hostname api.studafy.com.

After publishing the route and starting the correct API:
- https://api.studafy.com/healthz should report status ok.
- https://api.studafy.com/readyz should pass its configured dependency checks.
- The app's student-ID lookup must complete one real Turnstile challenge.
- Replaying the consumed token must be rejected.

References:
- https://developers.cloudflare.com/tunnel/get-started/
- https://developers.cloudflare.com/turnstile/additional-configuration/hostname-management/
