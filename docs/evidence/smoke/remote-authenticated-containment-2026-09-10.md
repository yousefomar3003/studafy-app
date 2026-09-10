# Authenticated synthetic containment smoke

Authorized project: `eamewgaptdfqzpmayavx` (`studafy light`) only.
Timestamp: `2026-09-10T18:18:07.053Z` (`2026-09-10 21:18:07` Riyadh).

An ephemeral, email-confirmed synthetic user was created for this test. Its
identity, password, access token, and substituted object path were kept only in
memory and were never printed or written to disk.

| Check | Result |
|---|---|
| Test file category | Synthetic nonexistent PDF path substitution |
| Study Coach | 503 `FILE_UPLOADS_DISABLED` |
| Study Coach request ID | `6b0fae50-552d-4c59-a230-7c5f82a3c4bb` |
| AI grading | 503 `AI_GRADING_DISABLED` |
| AI grading request ID | `d23ecd1d-aadc-43a7-8ef8-8f4b422cabd6` |
| Path echoed | No |
| Signed URL/token returned | No |
| Direct private-object read | Denied |
| Provider branch reached | No; both containment responses occur before provider logic |
| Ephemeral user cleanup | Deleted successfully |
| Remaining remote auth users | 0 |
| Remaining listed storage objects | 0 |

The synthetic project secret-name inventory contains only Supabase-managed
runtime entries. No Study Coach, grading, Calendar broker, purchase verifier,
or other AI-provider credential is configured, so there is no configured AI
provider account/log stream to inspect for this environment.

The test is reproducible with
`scripts/verify-synthetic-attachment-containment.ts`. It deliberately requires
an explicit synthetic confirmation flag and does not display credential values.
