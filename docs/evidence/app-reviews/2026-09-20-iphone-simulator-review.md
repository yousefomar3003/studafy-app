# iPhone simulator and login review — 2026-09-20

The development app builds and runs on iPhone 17 / iOS 26.5 using Xcode 27.
The hosted Supabase project has Google and Azure (Microsoft) enabled. Both
authorization endpoints return redirects to their providers, and Google
account verification was observed in the running simulator. A completed
provider callback and authorized school session have **not** been verified.

## Real-login blocker

The ignored mobile development config points to hosted Supabase project
`eamewgaptdfqzpmayavx` and API `http://127.0.0.1:8080`. The API's root `.env`
points to local Supabase `http://127.0.0.1:54321` and local PostgreSQL on port
54322. The API was initially offline; after starting it, `/readyz` returned
`{"ready":true,"reasons":[]}`. This verifies the **local** dependencies only.

The API must use the hosted project's issuer/JWKS and its corresponding
application database before it can authorize the hosted accounts. Alternatively,
point the mobile build at an already deployed API configured for that project.
No hosted database connection for the running API or deployed API URL was
established in this review. The later read-only CLI inspection below uses the
existing Supabase management login, not an application database credential.
The selected teacher/parent/student role also requires an active server-side
school membership; merely choosing a role does not grant it.

Supabase must allow `io.studafy.app://login-callback`. The iOS scheme and client
callback match, but the hosted redirect allowlist and the complete return from
provider verification were not independently verified. Users complete account
credentials and MFA in the provider UI, not in the development session.

### Follow-up after the supplied Supabase settings

The supplied project URL and publishable key exactly match the ignored mobile
configuration. The supplied `/rest/v1/` endpoint is Supabase's PostgREST API,
not the custom Studafy API implemented in `apps/api`; it cannot replace
`STUDAFY_API_URL`. The supplied direct connection still has a password
placeholder, and no actual hosted database password was available in the
API environment. The supplied server secret was not put into the app or
configuration; rotation was advised because it was shared in chat.

Read-only queries through `supabase db query --linked` established:

- Hosted migration history contains 8 migrations, ending `202609090004`.
- The repository contains 64 migrations, with 56 later than the hosted version.
- Hosted `public.profiles`, `public.memberships`, and the consent RPC exist.
- Hosted `public.auth_devices` and `private.auth_context()` do not exist. The
  current API calls the latter when resolving an authenticated account.

Therefore correcting the runtime connection alone is insufficient: the hosted
schema needs a reviewed upgrade before the current API can complete login.
No hosted migrations, school memberships, or user records were changed.

### Hosted OAuth redirect correction

After the user reported Safari opening `localhost`, `supabase config diff`
confirmed hosted `auth.site_url = http://localhost:3000` and an empty
`auth.additional_redirect_urls`. The app's requested native callback was thus
not allowed. A minimal temporary config was reviewed and pushed with exactly
one declared change: allow `io.studafy.app://login-callback`.

Readback confirmed no remaining difference for that setting; Google and Azure
remained enabled. Fresh Google and Azure authorization flows followed by
simulated provider cancellation both returned HTTP 302 to the native callback,
not localhost. These probes verify redirect routing without signing in a user.
The user must start a new sign-in attempt; existing provider flows may retain
the former redirect. The API/schema blockers above remain separate.

## Fixes made

- Request Azure's `email` scope, required by
  [Supabase's Microsoft login guide](https://supabase.com/docs/guides/auth/social-login/auth-azure).
- Treat failure to open the provider browser as a failed login attempt.
- Release the login button's busy state after browser launch so dismissing or
  cancelling the browser does not permanently prevent another attempt.
- Resolve restored sessions in `didChangeDependencies`, after localization
  access is valid, rather than reading inherited widgets in `initState`.
- Handle authentication stream errors with a safe visible message.
- Return the session interactor to signed-out status after provider-launch
  failure.

Regression tests verify provider URLs and PKCE, Microsoft email scope, failed
browser launch, provider retry, restored-session initialization, and auth-stream
error handling. The final development build was installed and relaunched on
iPhone 17; its role-selection screen was visually confirmed without the
synthetic-preview banner.

## Verification

| Check | Result |
|---|---|
| Flutter analysis | No issues |
| Flutter unit/widget suite | 226 passed |
| Backend workspace suite | 560 passed, 1 storage integration test skipped, 0 failures |
| Workspace TypeScript checks | Passed for all 9 packages |
| TypeScript/file architecture boundaries | Passed |
| Dart feature boundaries | Passed: 83 feature files, 0 violations |
| Generated OpenAPI/Dart client drift | Passed |
| Native iPhone smoke test | Passed: 3 roles × 5 tabs × 2 languages |

The native smoke test uses a separate iPhone 17 Pro / iOS 26.5 simulator and
real native SQLite/preferences plugins with **synthetic data**. It exercises
startup, role selection, consent, preview login, and every primary navigation
destination. It asserts the selected tab and absence of Flutter exceptions and
captures 30 screenshots. An initial test-harness timer race was corrected with
a bounded wait for the role screen; the subsequent complete run passed.

Screenshots are in `/tmp/studafy-smoke-screenshots`. Selected teacher, student,
and parent screens in both languages were visually inspected. This is navigation
coverage, not proof of every form, live server mutation, purchase, notification,
or physical-device behavior.

## Remaining product observations

- Legacy preview teacher/parent screens still contain English interface text in
  Arabic mode. Navigation mirrors correctly; full legacy-preview translation
  remains incomplete. The preview teacher dashboard also uses a sample date.
- Student academic screens and messages, and the parent child list, showed
  empty states in the tested preview database. Those screens rendered without
  exceptions; populated and live-account workflows need separate verification.
- The real remote shells use different adapters from the preview. The teacher
  uses `TeacherTodayPage`, the parent uses `FamilyHomePage`, and academic and
  messaging screens use the API. Passing preview navigation cannot establish
  that these remote flows work with hosted school data.
- Remote file upload remains explicitly unavailable in the composition root.
  Store purchases and Apple sign-in were not exercised; Apple was not enabled
  in the hosted project's public auth settings, although the iOS UI offers it.
- Production startup remains intentionally blocked by `RuntimePolicy`.

## Reproduce

Real-provider development launch:

```sh
flutter run -d <iPhone-device-id> \
  --dart-define-from-file=config/dart-defines.development.json
```

Synthetic native navigation check (use a different simulator while signing in):

```sh
flutter drive -d <iPhone-device-id> \
  --driver=test_driver/iphone_smoke.dart \
  --target=integration_test/iphone_smoke_test.dart
```
