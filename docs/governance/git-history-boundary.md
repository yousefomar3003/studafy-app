# Git history boundary record

Status: formally bounded. Owner: repository owner (GitHub `@yousefomar3003`).
Recorded: 2026-09-10. Reference: SEC-001 risk register row "Historical secrets
cannot be inspected without repository history"; ARC-001 task "Restore/import
Git history".

## Boundary statement

The Studafy repository was re-established from a squashed snapshot. The
original development history is unrecoverable (owner confirmation,
2026-09-10). The entire verifiable history is therefore exactly two commits:

- `2dfffad` — Initial Studafy baseline
- `9e134f2` — Fix read-only dependency scan workflow

No claim is made about the absence of secrets in pre-baseline history. That
history cannot be inspected, and this limitation is accepted rather than left
as an open gate.

## Scope of scanning under this boundary

- The CI secret-scan job checks out complete history (`fetch-depth: 0`) and
  runs gitleaks plus the tracked-filename check. Under this boundary that
  coverage is 100% of verifiable history.
- The boundary covers commit content only. It does not cover pre-baseline
  artifacts, other machines, provider consoles, or any prior hosting of this
  code.

## Compensating constraints

1. Every credential currently in use was created for the post-baseline
   synthetic environment: the Supabase project `eamewgaptdfqzpmayavx` is
   synthetic and empty (zero users, rows, and storage objects), and no
   production or real-data environment exists.
2. Any pre-baseline secret is considered unverifiable. If a production
   environment is ever created, it must use newly issued credentials; never
   reuse a secret that could predate the baseline.
3. Pre-baseline artifacts (old backups, exported files, prior repositories)
   must not be reintroduced into this repository without a gitleaks scan and
   security review.
4. Rotation trigger: if any pre-baseline artifact is later discovered or the
   original history surfaces, reopen this record, scan the material on a
   dedicated branch, rotate anything implicated, and re-baseline.

## Review triggers

- Recovery of any original repository, backup, or machine containing prior
  history.
- Creation of the first production or real-data environment (re-evidence the
  Phase 0A log with named, separated owners first).
