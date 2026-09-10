# App-flow baseline checklist — synthetic mode

ARC-001 deliverable ("baseline … app flows"). Evidence date: 2026-09-10.
Method: automated coverage comes from the Flutter test suite (22 tests,
`docs/evidence/baselines/analyze-test-2026-09-10.txt`); the manual rows below
are for the owner to confirm on a device/emulator in `APP_ENV=synthetic`.
Nothing here uses real data or a real backend.

## Automated (test-covered)

| Flow | Evidence |
|---|---|
| Splash → role selection (teacher/student/parent) | `test/widget_test.dart` |
| Synthetic banner renders on every synthetic screen | `test/containment_test.dart` |
| Production env blocks startup (`ProductionReadinessBlockedPage`) | `test/containment_test.dart` |
| Invalid dart-define values block startup | `test/containment_test.dart` |
| AI grading upload/generate controls disabled | `test/containment_test.dart` (keys `ai-grading-upload-control`, `ai-grading-generate-control`) |
| Study Coach attachment control disabled; repository rejects attachments before network | `test/containment_test.dart` |
| Grading/attachment repository rejections | `test/containment_test.dart` |
| Insight engine calculations (attendance exclusion, not-yet-due, weights, thresholds) | `test/insight_engine_test.dart` |
| Source-level containment (no upload code, native release guards, migration drops upload policy) | `test/release_containment_test.dart` |

## Manual checklist (owner, synthetic mode)

| # | Flow | Expected |
|---|---|---|
| 1 | Cold start without dart-defines | Synthetic preview opens with yellow SYNTHETIC banner |
| 2 | Teacher role → classes/attendance/gradebook | Seeded preview data renders; all writes stay local |
| 3 | Teacher → schedule Google Meet | Friendly failure (no remote backend in synthetic mode) |
| 4 | Parent role → Insights+ paywall | Paywall renders; no purchase possible without backend |
| 5 | Student role → coach/quiz/flashcards | Attachment control disabled; coach requires backend |
| 6 | Settings → account deletion | Typed-confirmation flow renders (synthetic local only) |
| 7 | Language toggle English/العربية | Localized nav terms switch; RTL layout |

## Gap register

- No automated UI tests for the flows above beyond containment — test-depth
  expansion is Phase 1B/TEST work; passing status is not production assurance
  (matches the audit finding).
- Remote-mode flows (login consent, real notifications) cannot be baselined
  until a development environment exists (ADR-0004).
