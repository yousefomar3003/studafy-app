# School operations frontend — 21 September 2026

Implemented 17 existing API operations behind typed mobile repositories:

- Terms: list and create.
- Roster: list, create student, enrol, withdraw, transfer.
- Staff: list, assign, remove.
- Guardian links: verify and revoke.
- Meetings: request, fetch status, cancel with the returned version.
- Notification preferences: read and update.

The server's `school_admin` membership now maps to a dedicated administrator
shell. Selecting that role on the welcome screen does not grant membership.
Teacher class workspaces expose the management screen; student creation is
shown only to school administrators. Server authorization remains authoritative
for every mutation, including lead-teacher restrictions on staffing.

Writes use authenticated transport and idempotency keys. Retries retain the
same key until success. Notification on/off/on actions get different keys so
an old successful response cannot suppress a later change. A created student
is retained on screen when enrolment fails, allowing enrolment to be retried
without creating the student again. Withdrawal, transfer, staff removal and
guardian changes require explicit confirmation. Meeting cancellation uses the
server version. Screens show safe failure messages rather than raw exceptions.

Both native application identifiers are now `com.studafy.light`; release
containment and signing requirements are still in force. This identity change
is not an OAuth redirect fix: the registered login callback remains
`io.studafy.app://login-callback`.

## Verification

- Flutter static analysis and architecture boundary checks.
- Full Flutter regression suite, including notification replay tests and
  school scoping, transfer payload, term retries, and invalid meeting times.
- Xcode simulator development build and launch on iPhone 17 Pro / iOS 26.5.
- Native synthetic integration smoke: administrator, teacher, student and
  parent; all five tabs in English and Arabic. Passed in 66 seconds.

The simulator smoke proves startup and navigation, not live server mutation
success. It used synthetic fixtures and did not authenticate a real Google or
Microsoft account. The local API answered an unauthenticated probe with 401;
that is not proof of database readiness or successful authenticated requests.

## Remaining limitations

- No school-wide student directory, eligible-teacher picker, pending guardian
  request list, or meeting-list endpoint was added. Existing-record enrolment,
  staff assignment, guardian verification and meeting lookup require record IDs.
- Firebase/APNs configuration and native device-token registration are still
  absent. Preferences can be stored, but push delivery is not activated.
- Existing store billing and guardian purchase approvals were preserved. No
  Stripe checkout, new student self-purchase screen, or school billing-policy
  screen was added in this change; those remain outside the implemented 17.
- Real-account OAuth and authenticated backend mutations remain to be exercised
  with appropriate test memberships. Apple account approval/signing remains
  external to this change.
- Turnstile and tunnel hostname configuration remain unresolved. No supplied
  secret was embedded in Dart, native resources, or committed configuration.

This is substantial frontend coverage, not completion of every operation in
groups 2–4 or evidence that the app is ready for production release.
