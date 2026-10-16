# Inactive-account warnings that could not be emailed

Privacy policy §10 says accounts are deleted after 2 years without a
sign-in, and that we warn the account holder 30 days before. People with a
school are warned in the app and by email. People with **no school** can only
be warned by email (migration `202610150091`).

If that email fails for good, the warning never reaches the person. That
happens when there is no address, the address is refused or hard-bounces, or
eight tries fail. The account is then **kept, not deleted**: the deletion
step needs a warning that reached the person. We don't delete anyone without
a warning, so these accounts need an operator.

## How you hear about it

- Each hourly retention pass logs `retention_purged` with
  `step: "inactive_accounts"` and `inactive_warnings_undeliverable: <n>`
  (`private.inactive_warning_email_undeliverable`, migration `202610160030`).
- When queue alerts are on (`QUEUE_ALERTS_ENABLED`,
  `docs/deployment/queue-alerts.md`), the same Telegram chat gets **one alert
  a day** while the count is above zero:
  `ALERT Studafy production: 2 inactive-account warnings could not be emailed
  to people with no school...`, then `STILL HAPPENING` once a day, then
  `RESOLVED` when the count is back to zero.

The log and the alert carry the count only. They never include an address or
an account id.

## What to do

1. **List the rows.** Use an operator session on the database, never the
   worker role:
   ```sql
   select user_id, warned_at, email_attempts, email_error_code
   from private.inactive_account_warnings
   where notified_school_id is null and emailed_at is null
     and email_attempts >= 8 and deletion_request_id is null;
   ```
   `email_error_code` says why it stopped (`NO_ADDRESS`, a provider refusal,
   or the last error after eight tries).
2. **Check the address.** Look up the account's address in Auth, and the send
   in the Resend dashboard (bounce or complaint). If the cause was ours (a
   sender misconfiguration, or an outage the retries didn't outlast), fix it
   and let the worker send the warning again:
   ```sql
   update private.inactive_account_warnings
     set email_attempts = 0, email_claimed_at = null, email_error_code = null
   where user_id = '<user id>';
   ```
   Deletion is counted from when the email is accepted, so the person still
   gets the full 30 days.
3. **Otherwise, try another way.** If you have another way to reach the
   person, use it. If they sign in, the warning is dropped automatically.
4. **If nobody can be reached, decide with counsel.** See
   `docs/legal/questions-for-counsel-2026-10.md`, item 3.3. Record the
   decision in the decision log. Never set `emailed_at` by hand to make the
   deletion run: that would record a warning that was never delivered.

The alert resolves on its own once no rows are left: the person signed in,
the email went out, or the account was deleted through the normal deletion
path.
