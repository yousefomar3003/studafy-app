# Reviewer access: demo accounts for Google Play and App Review

Written 2026-10-15. Both stores need working demo accounts with full access
before they will review the app:

- **Google Play:** Play Console → *App content* → *App access*.
- **Apple:** App Store Connect → the version page → *App Review Information*.

The app's only sign-in options used to be Google, Microsoft and Apple.
Reviewers cannot use those with an account of ours: Google routinely blocks
demo Google accounts on a new device, and Apple must not need a third-party
sign-in at all. So the app now has a **"Sign in with email"** option on every
sign-in screen, in every build, as a secondary choice below the provider
buttons. It works only for accounts Studafy creates; it has no "create
account" and no "forgot password". (A login only reviewers could find, or a
special reviewer build, is itself grounds for rejection.)

The demo accounts belong to a **separate, fictional school**, so a reviewer
never sees real data. See [Keeping reviewers away from real data](#keeping-reviewers-away-from-real-data).

## The three accounts

| Role | Email | Name in the app | What it shows |
|---|---|---|---|
| Teacher | `teacher@review.studafy.com` | Nadia Haddad | Two classes, lessons, homework with one hand-in, an open online exam, a published grade, announcements, messages. |
| Student | `student@review.studafy.com` | Omar Saleh | Both classes, lessons, homework (one handed in, one due), the online exam to take, a grade of 17/20 with feedback, announcements. |
| Parent | `parent@review.studafy.com` | Huda Saleh | Linked to Omar: his homework, grades and announcements, and Family+ insights about him. |

The school is called **Cedar Grove Review School**. Its classes are *Grade 8
Science* and *Grade 8 Mathematics*. Every person and school in it is
invented.

### Paid plans, without a purchase

A reviewer must reach every paid screen without buying anything, so the
script gives each account its plans for a year (comp grants,
[study-plans.md](../deployment/study-plans.md#testing-a-plan-without-a-purchase)),
with the reason `App store reviewer account`:

| Account | Plans |
|---|---|
| Teacher | Studafy Max |
| Student | Studafy Max |
| Parent | Studafy Max, and Family+ for up to 8 children |

The app shows these as held, with "Given by Studafy, nothing to pay" on the
parent's Family+ and no store subscription to manage or cancel. A re-run adds
nothing while a grant has more than 30 days left, and renews one nearer its
end, so re-run the script before a review that falls within a month of the
year's end.

Grants are written straight to the database (no API writes them), so the
script needs the database owner's connection: `DB_URL` from the local stack,
or `DATABASE_URL` in the env file. To give the parent Family+ by hand
instead, after migration `202610190010_family_plus_grants.sql`:

```sql
insert into private.family_plus_grants (user_id, tier, reason, ends_at)
select p.id, 'family_plus_large', 'App store reviewer account',
  now() + interval '1 year'
from auth.users u join public.profiles p on p.id = u.id
where u.email = 'parent@review.studafy.com';
```

and a Studafy Max for any of the three:

```sql
insert into private.study_plan_grants (user_id, plan, reason, ends_at)
select p.id, 'max', 'App store reviewer account', now() + interval '1 year'
from auth.users u join public.profiles p on p.id = u.id
where u.email in ('teacher@review.studafy.com', 'student@review.studafy.com',
  'parent@review.studafy.com');
```

### Passwords

The passwords are random: four groups of six letters and digits, such as
`Abc2de-Fgh3jk-...`. They are written to the credentials file you name when
you run the script, readable by you only, and never printed. They are not in
this repository.

## What to paste into the store consoles

Take the passwords from the credentials file. Never paste them into an
issue, a chat or this repository.

### Google Play: App content → App access

1. Choose **All or some functionality in my app is restricted**.
2. Add **three** sets of instructions, one per account:

   | Field | Teacher | Student | Parent |
   |---|---|---|---|
   | Name | Teacher demo account | Student demo account | Parent demo account |
   | Username | `teacher@review.studafy.com` | `student@review.studafy.com` | `parent@review.studafy.com` |
   | Password | from the file | from the file | from the file |

3. In **Any other information required to access your app**, use this text
   (the same for all three):

   > Tap "Get started" (or "Skip") on the welcome screens, choose your role
   > (Teacher, Student or Parent) and tap Continue. Tick the box to accept
   > the Terms of Use and Privacy Policy, then tap "Sign in with email" at
   > the bottom of the sign-in screen. Enter the email and password above. These accounts belong to
   > a demo school with invented people and data; no real student's data is
   > shown. The sign-in does not need a verification code. The paid plans
   > (Studafy Max, and Family+ on the parent account) are already active on
   > these accounts, so nothing needs to be bought.

4. Leave *Allow Android to use the credentials you provide for performance
   and app compatibility testing* ticked.

### App Store Connect: App Review Information

1. Tick **Sign-in required**.
2. **User name:** `teacher@review.studafy.com`. **Password:** the teacher's,
   from the file.
3. **Notes:**

   > Tap "Get started" (or "Skip") on the welcome screens, choose a role
   > (Teacher, Student or Parent) and tap Continue. Tick the box to accept
   > the Terms of Use and Privacy Policy, then tap "Sign in with email" at
   > the bottom of the sign-in screen. The account above is the teacher. To review the
   > other roles:
   > Student: student@review.studafy.com / <student password>
   > Parent: parent@review.studafy.com / <parent password>
   > All three belong to a demo school with invented people and data.
   > The paid plans (Studafy Max, and Family+ on the parent account) are
   > already active on these accounts, so nothing needs to be bought.
   > Account deletion is under Account → Delete account. If the sign-in was
   > more than 10 minutes ago, it asks for the account's password again,
   > then schedules deletion with a 14-day grace period.

4. Add contact details as usual. The review notes are visible to Apple only.

## Server settings

### Supabase dashboard (hosted test copy, and production later)

Supabase offers no per-provider "allow sign-ups" switch for email. The only
sign-up switch is global and would also stop every new Google, Microsoft and
Apple account. So the dashboard keeps sign-ups on, and the database refuses
email sign-ups instead (migration `202610150050_reviewer_access.sql`): Supabase
Auth can only create an email account the service role registered minutes
before, and each registration works once. Set:

| Where | Setting | Value | Why |
|---|---|---|---|
| Authentication → Sign In / Providers → *User Signups* | Allow new users to sign up | **On** | Off would also stop new Google, Microsoft and Apple accounts. Email sign-up is refused by the migration instead. |
| same | Confirm email | **On** | Also a backstop for the one domain the migration lets through: managed child accounts at `managed.studafy.invalid`, which no mail can reach. |
| same | Allow anonymous sign-ins | **Off** | As today. |
| Authentication → Sign In / Providers → **Email** | Enable Email provider | **On** | Password sign-in for the reviewer accounts needs it, as do managed child accounts. |
| same | Secure email change | On | As today. |
| Authentication → Attack Protection | Enable CAPTCHA protection | **Off** | The app sends no captcha token with a password sign-in, so on would block the reviewers. The API's own Turnstile check is separate and unaffected. |
| Authentication → Rate Limits | Rate limit for sign-ups and sign-ins | Keep the default (30 requests per 5 minutes per IP) | Applies to password sign-in. The app shows "Too many attempts" when it is hit. |

The local stack's `supabase/config.toml` matches: `[auth] enable_signup` and
`[auth.email] enable_signup` both stay `true` (the second is what switches the
email provider on), and the migration does the refusing. On the local stack,
Supabase Auth applies no IP rate limit (it has no client-IP header), so the
limit can only be seen on the hosted project.

### What the API does with a password session

Nothing different. The token is verified against the same JWKS and resolved
to the same account. Deletion and data export still need a sign-in from the
last 10 minutes (launch plan 2.10). For a password account, the app asks for
the password again and signs in again, where an OAuth account goes through
its provider. A token refresh never counts as a new sign-in. Managed child
accounts are never asked for a password; they have none.

## Running it against the hosted test copy (needs the owner's go-ahead)

Every step here writes to the hosted project. Claude does not run them
without the owner's explicit approval.

1. **Back up:** `gh workflow run backup.yml`, then wait for it to pass.
2. **Apply the migration** the usual way, dry run first:
   `bunx supabase db push --db-url "<test copy DATABASE_URL>" --dry-run`, then
   without `--dry-run`. The script needs `202610150050_reviewer_access.sql`
   and, for the parent's Family+, `202610190010_family_plus_grants.sql`.
   Deploy the API from the same change before that one: an older API refuses
   the new fields it adds to `GET /v1/me/guardian-links`. Check the dashboard
   settings above at the same time.
3. **Ship an app build** with the "Sign in with email" button (this branch).
   The API needs no redeploy: no server code changed.
4. **Provision the school** from the repository root, with the credentials
   file outside the repository:

   ```sh
   bun --no-env-file scripts/provision-reviewer-school.ts --target hosted \
     --credentials-out ~/studafy-reviewer-credentials.json
   ```

   It reads `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and `DATABASE_URL`
   (the database owner, for the plan grants) from `.env.hosted` without
   printing them, and talks to `https://studafy-api-test.fly.dev`
   (override with `--api-url`, or `REVIEWER_API_URL` in the env file). It
   refuses a project whose `ENVIRONMENT` is `production` unless
   `--allow-production` is also given.
5. **Paste** the accounts into both consoles, as above.

The store review of a release build talks to **production**, not the test
copy. Before the first production submission, repeat steps 1, 2 and 4 against
production with its own env file and API URL, adding `--allow-production`.
Use a credentials file of its own.

The script is safe to run again. It adds only what is missing. It puts back
the passwords from the credentials file if anyone changed them.

It refuses to go on when:
- an account at a reviewer address exists that it did not create;
- a reviewer account belongs to any other school, or holds an administrator
  role;
- the target is not this machine and `--target hosted` was not given.

## Rotating the passwords

Rotate after each review cycle that might have exposed them, and at once if
the credentials file or a console screenshot leaks.

```sh
bun --no-env-file scripts/provision-reviewer-school.ts --target hosted \
  --credentials-out ~/studafy-reviewer-credentials.json --rotate
```

This writes three new passwords to the file, sets them, and ends every other
session of the three accounts. Then update **both** consoles at once; a
review that starts with the old password fails.

## Keeping reviewers away from real data

- **A school of their own.** Cedar Grove Review School is a teacher
  workspace the script creates, and its only members are the three accounts.
  The script checks this before and after it works, and stops if any of them
  belongs anywhere else. Every write goes through the real API as one of the
  three accounts, so it can do nothing a teacher, student or parent could
  not.
- **No administrator.** This release has no school administrator, and the
  script never creates one.
- **No email or push to real people.**
  - Supabase Auth sends no confirmation mail for these accounts: they are
    created already confirmed.
  - The app offers no password reset, so no reset mail is sent either.
  - Email notifications are opt-in and off by default.
  - Every notification the demo content causes goes to the three accounts
    alone. Pushes reach only devices signed in to those accounts, which are
    the reviewers' own.
  - The addresses are on `review.studafy.com`, a domain Studafy owns. Point
    its mail (MX or catch-all) at a mailbox the owner reads, so anything sent
    there stays with Studafy. A typo can only reach the owner.
- **Messages and reports stay inside.** Contacts are limited to the school,
  so a reviewer can message only the other demo accounts. A safety report
  made during review reaches Studafy's own moderation queue.
- **If a reviewer deletes an account.** Deletion has a 14-day grace period.
  Cancel it from the account, or let it run and then re-run the script, which
  creates that account again.

## Local runs

On a local stack (this machine only; the script refuses anything else
without `--target hosted`). The stack must be named with `--workdir` (or
`SUPABASE_WORKDIR`); outside CI the script never assumes the default one,
which is the working stack (`--workdir .` names this checkout's own):

```sh
bunx supabase start --workdir <stack dir>
# start the API on this machine, against the same stack, e.g. on :8080
bun --no-env-file scripts/provision-reviewer-school.ts \
  --credentials-out ~/studafy-reviewer-local.json \
  --api-url http://127.0.0.1:8080 --workdir <stack dir>
```

## Tests

- `test/features/session/email_sign_in_test.dart`: the button, the sheet,
  validation and every error, in English and Arabic; the password dialog.
- `test/features/session/password_reauth_test.dart`: the real repository and
  transport. Covers password sign-in errors and re-authentication by
  password before deletion and export.
- `apps/api/test/auth/password-session.integration.test.ts`: real Supabase
  Auth and the real auth routes. Covers sign-up refused, password session
  accepted, fresh sign-in granted, old sign-in and refresh refused, and
  sign-in again granted.
- `supabase/tests/reviewer_access.sql`: the sign-up rule and its grants.
- `scripts/provision-reviewer-school.test.ts`: targets, env parsing (no
  values in errors), passwords, the credentials file, school checks, and the
  plans each account is given.
- `supabase/tests/family_plus_grants.sql`: a Family+ grant gives its seats
  wherever the plan is read, and an ended one gives nothing.
