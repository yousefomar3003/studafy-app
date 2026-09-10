# Phase 1B (ARC-011) — Flutter boundaries and typed contracts

Status: complete. Date: 2026-09-10. Decision-log: DL-019–DL-022.
Architecture record: ADR-0012. Full verification output:
`verification-2026-09-10.txt`.

## What was delivered

- **Feature folder structure** (`lib/features/{session,classes,account}/`)
  with domain/application/data/presentation zones and an enforced boundary
  matrix (`tools/check_dart_bounds.dart`, CI step added).
- **Session slice**: `SessionInteractor` — OAuth → consent → profile →
  matching membership → term resolution → hydrate `ActiveContextController`.
  The demo fallback (`startDemoRole`/`switchRole`) now refuses every
  non-synthetic runtime (the Phase 1 gate item).
- **Classes slice**: `ClassListInteractor` → `ClassroomRepository` port →
  `PreviewClassroomRepository` (wraps the old preview read) +
  `SupabaseClassroomRepository` (RLS PostgREST). Typed `ClassesPage`
  replaces `DatabaseClassesPage`; the legacy `ClassWorkspacePage` stays,
  fed through a documented `toLegacyMap()` bridge (slice-2 debt).
- **Composition root** (`lib/app/app_dependencies.dart`): synthetic →
  demo/preview adapters, remote → Supabase adapters; constructor injection.
- **Account feature move**: `DeleteAccountPage` moved to
  `lib/features/account/presentation/` — parent/student no longer import
  teacher_features.dart for it.
- **Dead code removed**: unreachable static `ClassesPage` + `ClassDialog`
  from main.dart (main.dart: 1,733 → 992 lines).
- **Typed contracts with drift detection**: `packages/contracts/src/v1/`
  zod schemas + shared fixture JSON + bun test (TS) + flutter test (Dart)
  cross-validation.
- **SQL portability fix**: 28 double-quoted SQL string literals in
  `studafy_database.dart` converted to single-quoted (exposed by the ffi
  test suite; works on mobile but fails on strict desktop engines).
- **Dev dependency**: `sqflite_common_ffi` (dev-only, pinned ^2.3.5).

## Verification summary

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test --concurrency=1` | **39 pass** (22 existing + 17 new) |
| New: session interactor | 9 tests (happy path, no-membership denial, consent failure, demo denial ×4, signOut, immutability) |
| New: classes adapter (ffi SQLite) | 4 tests (seeded list, bridge map, create, invite link) |
| New: contract drift | 4 tests (me parse + round-trip, classrooms parse + nullable round-trip) |
| Dart boundary checker | 13 feature files, 1 legacy-exempt, 0 violations (+ negative validated) |
| TS boundary checker | 9 members, 22 source files, 0 violations |
| Bun workspace tests | 50 pass, 0 fail (incl. 4 new v1 contract tests + fixture drift) |
| Deno frozen | check + test pass |
| Synthetic debug build | ✓ Built |
| `dart format` | Clean (45 files) |

## Acceptance criteria (instructions.md:1058) — met

- **"Slice contains no widget SQL/provider call/dynamic transport cast"**:
  the session and classes presentation/application layers import zero
  persistence/provider modules — enforced by the boundary checker and
  verified by analyze.
- **"Existing UX tests pass"**: all 22 original tests pass unchanged.
- **Phase 1 gate "production flavour contains no demo authorization"**:
  `startDemoRole` and `switchRole` refuse non-synthetic runtimes (tested).
- **Phase 1 gate "no direct persistence from migrated widgets"**: the
  migrated ClassesPage and session pages read through typed repositories
  only.

## Open items (next slices)

- `ClassWorkspacePage` is still legacy map-driven (slice-2 debt: migrate
  behind the ClassroomRepository).
- The remaining 108 direct `StudafyDatabase` call sites in
  teacher/student/parent features are legacy-exempt until their slices.
- The legacy `SessionService` and `SupabaseStudafyRepository` still serve
  non-migrated callers; they shrink as slices land.
- `features/account/**` is legacy-exempt (the DeleteAccountPage still does
  its own env-split internally).
