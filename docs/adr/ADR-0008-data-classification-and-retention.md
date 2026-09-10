# ADR-0008: Data classification, retention, and family-data governance

Status: Deferred — blocks the Phase 7 pilot, any real student data, and
detailed Phase 3 family/verification design. Decision-log: DL-011, DL-014.
Date: 2026-09-10.

## Context

Studafy processes children's education, wellbeing, and communications data for
Saudi schools. Legal bases, retention periods, guardian verification
authority, student age ranges, export/correction workflow, and breach
procedures require qualified counsel (Saudi PDPL, children's data,
education-record obligations). ARC-001 requires these to be decided or
explicitly stopped.

## Decision

**Deferred.** Recorded working artifacts:

- `docs/inventory/data-classification-retention-draft.md` — draft
  classification and retention candidates per table, pending legal review.
- Wellbeing events are treated as potentially special-category child-safety
  data with the strictest proposed access and retention controls.
- `studafy_id` public-locator verification, guardian linking, and school
  provisioning workflows assume server-mediated, throttled verification; the
  QR scanner's hard-coded ID is non-functional and must never imply identity
  proof.

## Consequences

- The Phase 7 pilot and any real student/teacher data **cannot start** until
  retention/legal bases are decided by counsel.
- Phase 3 (AUTH-030/031) design proceeds for session/RBAC mechanics but
  guardian-verification authority and student age handling remain open inputs.
- The draft classification may be refined by engineering but legal approval is
  the unblocking event.
