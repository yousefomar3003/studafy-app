# ADR-0031: Managed child accounts and switching accounts on one device

- Status: Accepted; deployed to the Fly test copy, not yet to production
  (status reviewed 2026-10-12, launch plan 7.2). Originally accepted for
  local/disposable use
- Date: 2026-09-28
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Relates to: guardian child mode (`202609250003_guardian_child_mode.sql`),
  ADR-0015 (application identity), ADR-0016 (AUTH-030 session lifecycle)

## Context

Young children have no email or phone, so they cannot sign in with Google,
Microsoft or Apple, which are the only ways into Studafy. Guardian child
mode (2026-09-25) let a parent act *for* such a child, with the child
existing only as a school's student record and the parent remaining the
actor. It deliberately did not give the child an account: "nothing
impersonates the child", and the parent could do only an allowlist of
things for them.

The owner has now asked for more:

1. A parent creates a **real student account** for their child from their
   own account.
2. The parent **switches into it** the way Instagram switches accounts, sees
   exactly what a student sees, and the app **shows that it is a
   sub-account**.
3. Anyone can keep **several accounts on one device** and switch between
   them ("add account").

Asked directly, the owner chose a real child account over extending child
mode. That reverses "nothing impersonates the child" for managed accounts
only. Child mode still exists for children who have no account at all.

## Decision

### The child's identity

The API creates the account through Supabase Auth's admin API
(`SupabaseManagedAccountIssuer`). Three properties make it reachable only
through the parent:

- **Its address is `child-<uuid>@managed.studafy.invalid`.** `.invalid` is
  reserved (RFC 2606) and never resolves, so no confirmation, magic link or
  reset can be delivered. The child has no way to sign in on their own.
- **The guardian's id is in `app_metadata`**, which only the service role
  can write. The database checks it before recording the account as
  managed, so the register step cannot be used to claim anyone else's
  account, and a client cannot forge it.
- **Sign-ins are issued to the parent alone**, as one-time magic-link token
  hashes (`POST /v1/me/managed-children/{childId}/session`). The app
  exchanges the hash with Supabase Auth for a session. A hash works once.
  The route has idempotency `forbidden`, like `verifyReauth`, so the token is
  never stored for replay, and it is sent with `cache-control: no-store`.
  The issuer also refuses any account whose address is not under the
  managed domain, whatever the database says.

The service role is built once, in `composition/platform.ts`, like the
storage client. The FILE-050 boundary check keeps it there.

### The database (`202609280004_managed_child_accounts.sql`)

- `private.managed_accounts(child_id, guardian_id)`: at most six children
  for each parent.
- `private.api048_managed_accounts` has four operations (`list`,
  `can_create`, `register`, `authorize_session`). Each one re-derives the
  caller from `auth.uid()`, and each refuses a managed account outright, so
  a child can neither create accounts nor issue sign-ins.
- `register` accepts only an account created in the last 15 minutes, with
  the caller as its guardian in app metadata. It records the parent's
  acceptance of the terms on the child, against a *published* policy only,
  the same rule `record_policy_consent` applies. The parent ticks a box that
  says they are accepting for the child. The whole step is audited
  (`managed_account_created`).
- Every sign-in as a child is audited (`managed_account_session_issued`).
- When the child joins a class, a trigger makes the managing parent a
  **verified guardian** at that school. The parent's own view of the child
  (grades, attendance, messages to the teacher) then works as it does for
  any linked child. An existing link, including a revoked one, is left
  untouched.

### Switching accounts on the device

Only one Supabase session is current at a time. `DeviceAccountSwitcher`
(`lib/app/account`) keeps the other accounts in the platform keystore
(`SecureAccountVault`), each with its latest refresh token:

- **Tokens rotate.** Presenting a rotated-out refresh token ends that
  session, so the vault follows every token the session layer issues
  (`SessionRepository.sessionTokens`). It never holds a stale one.
- **A switch is verified, not assumed.** Supabase keeps the *current*
  session when handed a token that was already used, so after every resume
  the switcher checks who is actually signed in.
- **A child account is entered through its parent.** If the parent is not
  current, the parent's session is resumed first, then a sign-in is issued.
  A child whose parent is not on the device cannot be opened.
- **Failure restores** the account that was current, where it still can be.
- **Signing out** removes only that account from the device, with any child
  accounts it manages, then opens another account kept there. A child
  account goes back to its parent.
- **Adding an account** leaves the current session untouched: signing out
  would revoke the token being kept. The login screen ignores the
  still-current session and completes only when a *different* user signs
  in.

While a parent is in a child's account, a banner above every screen says
"Sub-account · managed by <parent>", with one tap back.

## Consequences

- Teachers see a managed child's work under the child's own name. There is
  no "handed in by a parent" label for managed accounts, because the child
  is the actor. Only the audit log shows that a parent was signed in.
- A managed child has the full student surface, including the study helper.
  The AI gate (ADR-0029, `AI_LESSON_TOOLS_ENABLED`) still applies.
- A signed-out child session is abandoned, not revoked, when the parent
  switches away. Nobody holds its token.
- Not built yet:
  - **Graduating a child.** Giving the child their own login later, and
    removing it from `managed_accounts`.
  - **Parent-initiated deletion** of a child account.
  - **A managed flag in `/v1/me`.** The device knows an account is managed
    because it was reached through the parent.
