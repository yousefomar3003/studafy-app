# MVP interface and family consent

This supersedes the school-admin UI scope in the earlier frontend-school-operations report. School administration is deferred: the role selector, login routing, account role switcher and application routes expose teacher, student and parent only. Existing backend administration code remains for future work.

## Interface

The shared Material 3 theme now uses indigo, mint, softer surfaces, larger rounded cards, clear typography and consistent controls. Teacher and student homes use animated welcome panels that respect reduced-motion preferences. The parent home uses child profile tiles plus a persistent link-child tile in the main content. Teacher classroom tools use labelled, horizontally scrollable controls instead of a crowded app bar. Parent and teacher preview sessions use the same typed screens as remote sessions.

Students open **My ID & family** from their home to copy their Studafy student ID, inspect the requester's name and account ID, approve or decline requests, and revoke existing access. Parent requests explain that the student must approve them. Account IDs remain available from the account screen.

## Consent enforcement

New contract operations:
- GET /v1/me/student-family
- POST /v1/guardian-links/{guardianLinkId}/student-decision

Migration: supabase/migrations/202609210005_student_family_approval.sql.

The read returns only records owned by the authenticated student. The command independently checks student ownership inside its database transaction, locks the link and idempotency reservation, validates the transition, records an audit event, and completes the idempotent response atomically. Parents and unrelated accounts cannot approve a request. Pending/declined/revoked links grant no access under the existing authorization rules. Approved links expire after one year. The mobile child selector also refuses expired links.

Approval records the student's consent; it does not independently verify a person's legal identity. The confirmation asks the student to recognize their parent/guardian before sharing.

## Validation and deployment boundary

Backend integration tests run against local Postgres, including unauthorized approval, decline, approval, repeated requests, stale decisions and revocation. Widget tests exercise confirmation cancellation, approval and removal in English and Arabic at iPhone width. No new server credentials are included in client code.

The migration has been applied to local Postgres only. Hosted API and Supabase deployment are still required before these new operations work with real accounts. Simulator navigation uses synthetic data and does not establish that real Google/Microsoft login or hosted parent linking succeeds.

Final checks:
- flutter analyze: no issues.
- Flutter unit/widget suite: 305 passed.
- Family HTTP integration and route/permission catalogue: 15 passed (1,112 assertions).
- TypeScript workspace typecheck, generated-contract drift check, Dart feature boundaries and git diff whitespace check: passed.
- Xcode iPhone 17 Pro simulator: all 28 main tabs across three roles and two languages passed. Screenshots captured in /tmp/studafy-smoke-screenshots; parent English, student Arabic and teacher English homes visually inspected.
