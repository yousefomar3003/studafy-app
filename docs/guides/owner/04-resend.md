# 04 · Resend (email to users)

Launch plan **C5**. Time: 20 minutes, plus waiting for DNS.

The worker sends short, fixed emails through Resend: notification emails
(only when the person turned email on), subscription notices, and the
warning a month before an inactive account is deleted. The text never
includes message content or amounts
(`packages/infrastructure/src/notifications/channelSenders.ts`,
`apps/worker/src/processors/channelDelivery.ts`).

## Before you start

- Your Resend login. You already have a Resend account: the alert relay
  sends from `alerts@studafy.com` (`ops/alert-relay/wrangler.toml`).
- Your Cloudflare login (the DNS for `studafy.com` is on Cloudflare).
- The private folder `~/studafy-secrets` ([README](README.md)).

## Exact values

| What | Value |
|---|---|
| Sending domain | `studafy.com` |
| Sender (`EMAIL_FROM_ADDRESS`) | `Studafy <no-reply@studafy.com>` |
| API key permission | "Sending access", domain `studafy.com` only |
| API key names | `studafy-worker-test`, later `studafy-worker-production` |

The code sends no "reply-to", so replies to `no-reply@` go nowhere. The
privacy policy and the stores give `hello@studafy.com` for contact.

## Steps

### 1. Check the domain

1. Log in at [resend.com](https://resend.com) → **"Domains"**.
2. If `studafy.com` is there and says **"Verified"**, note its **region**
   and go to step 3.
3. If it is not there, go to step 2.

### 2. Add and verify the domain (only if needed)

1. **"Add domain"** → `studafy.com`.
2. Region: choose **"Ireland (eu-west-1)"**. Our main systems are in the EU.
3. Resend shows DNS records: an **MX** and a **TXT** on `send`, a **TXT**
   on `resend._domainkey`, and an optional **TXT** on `_dmarc`.
4. If Resend offers **"Sign in to Cloudflare"** (automatic setup), use it.
   Otherwise, in Cloudflare → `studafy.com` → **"DNS"** → **"Records"** →
   **"Add record"**, add each record exactly as Resend shows it.
5. Back in Resend, click **"Verify DNS records"**. It can take minutes to a
   few hours. Wait for **"Verified"**.

### 3. Turn off tracking

On the domain page → **"Configuration"** (or "Settings"): turn **off**
"Open tracking" and "Click tracking". Our emails are plain text, and our
users include children.

### 4. Make the worker's API key

1. Resend → **"API Keys"** → **"Create API key"**.
2. Name: `studafy-worker-test`.
3. Permission: **"Sending access"**. Domain: **`studafy.com`**.
4. **"Add"**. The key is shown **once**. Copy it, then:

   ```sh
   pbpaste > ~/studafy-secrets/resend-worker-test.txt
   chmod 600 ~/studafy-secrets/resend-worker-test.txt
   ```

5. Make a separate key, `studafy-worker-production`, when production is
   built (C11). Do not reuse the alert relay's key.

### 5. Data agreement

Resend processes users' email addresses. In Resend's settings or legal
pages, accept their **DPA** (data processing agreement), and keep a copy.
The privacy policy lists Resend (§7.2), and its transfer basis is still a
TODO there (§8).

### 6. Apple's hidden email addresses (later, with guide 07)

People who sign in with Apple can hide their email. Apple then gives an
`@privaterelay.appleid.com` address and drops mail from senders it does not
know. [Guide 07, part E](07-apple.md#part-e-email-to-hide-my-email-users)
registers `no-reply@studafy.com` with Apple.

## Give Claude

> C5 done. Key file `~/studafy-secrets/resend-worker-test.txt`. Sender
> `Studafy <no-reply@studafy.com>`. Domain region: `…`.

## What Claude does

Sets on the worker (after your "go"):

- `RESEND_API_KEY` = the key file's contents;
- `EMAIL_FROM_ADDRESS` = `Studafy <no-reply@studafy.com>`;
- `NOTIFICATION_CHANNELS_ENABLED=true` (also used by push, guide 03).

The worker refuses to start if only one of `RESEND_API_KEY` and
`EMAIL_FROM_ADDRESS` is set (`packages/config/src/index.ts`).

## How Claude checks it

1. The worker's start-up log shows
   `notificationChannels.emailConfigured: true`.
2. Claude turns email on for a test account and sends it a notification.
   Resend → **"Emails"** shows it as "Delivered", and it arrives in your
   inbox (check spam too).
3. **Gap:** `scripts/send-test-notification.ts` tests push only. There is
   no email option yet, so Claude triggers a real notification, or adds an
   `--email` option first.

## Common mistakes

- **Domain not verified.** Resend refuses to send from it.
- **Sender on another domain.** `EMAIL_FROM_ADDRESS` must be on the verified
  domain.
- **A "Full access" key.** Use "Sending access" for one domain. If the key
  leaks, it can then only send.
- **Cloudflare proxy on mail records.** MX and TXT records cannot be
  proxied. If Cloudflare shows an orange cloud on any record you added,
  make it grey ("DNS only").
- **One key for test and production.** Use one key each, so you can revoke
  one without breaking the other.
