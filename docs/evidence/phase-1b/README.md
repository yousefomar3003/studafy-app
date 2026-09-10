# Phase 1B (ARC-011) — Flutter boundaries and typed contracts

Status: implementation complete and locally re-verified; the current change
set still requires a GitHub push/CI run before the external CI acceptance
evidence is current. Date: 2026-09-10. Decision-log: DL-019–DL-023.
Architecture record: ADR-0012. Full verification output:
`verification-2026-09-10.txt`.
Hotspot follow-up evidence: `hotspot-refactor-2026-09-11.md`.

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
- **Typed contracts with generated-client drift detection**: canonical OpenAPI
  3.1 document + zod schemas + deterministic generated Dart DTO/transport
  client + shared fixture validation. CI runs `bun run generate:check`.
- **Hardened architecture check**: relative and package imports are normalized;
  provider packages are data-zone-only; unknown internal/third-party imports
  fail closed; three direct checker tests cover allowed and denied graphs.
- **Session widget state coverage**: consent-gated synthetic navigation and
  safe remote-provider failure rendering are exercised as widgets.
- **SQL portability fix**: 28 double-quoted SQL string literals in
  `studafy_database.dart` converted to single-quoted (exposed by the ffi
  test suite; works on mobile but fails on strict desktop engines).
- **Dev dependency**: `sqflite_common_ffi` (dev-only, pinned ^2.3.5).
- **Hotspot decomposition**: `main.dart`, parent presentation, teacher
  dashboard, preview database, and Study Coach were split into bounded modules;
  presentation-to-SQL/provider access was removed from those areas and remote
  parent/teacher adapters fail closed rather than opening preview SQLite.
- **Teacher monolith decomposition**: the 4,690-line
  `teacher_features.dart` is now a 34-line compatibility library over 14
  responsibility-focused modules (largest: 571 lines). The existing direct
  preview-database calls are isolated under `lib/legacy/teacher/`, counted, and
  prevented from increasing until their vertical slices migrate.

## Verification summary

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test --concurrency=1` | **56 pass** after teacher decomposition follow-up |
| New: session interactor | 9 tests (happy path, no-membership denial, consent failure, demo denial ×4, signOut, immutability) |
| New: classes adapter (ffi SQLite) | 4 tests (seeded list, bridge map, create, invite link) |
| New: contract/client drift | 5 Dart tests plus OpenAPI/Zod operation/schema alignment in Bun |
| New: architecture and session widgets | 4 boundary tests + 2 session widget state tests + 8 hotspot architecture/repository tests |
| Dart boundary checker | 41 feature files, 1 legacy-exempt, 0 violations (+ negative validated) |
| TS boundary checker | 9 members, 22 source files, 0 violations |
| Bun workspace tests | 51 pass, 0 fail with live Redis/Postgres |
| Deno frozen | check + test pass |
| Synthetic debug build | ✓ Built |
| `dart format` | Clean (99 files) |

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
- The remaining 98 direct `StudafyDatabase` calls are confined to the modules
  under `lib/legacy/teacher/`, `student_features.dart`, `student_linking.dart`,
  and the legacy-exempt account page. Parent and teacher-dashboard presentation
  no longer call SQLite. Their later slices must replace transitional
  map-shaped parent results with dedicated typed entities.
- The legacy `SessionService` and `SupabaseStudafyRepository` still serve
  non-migrated callers; they shrink as slices land.
- `features/account/**` is legacy-exempt (the DeleteAccountPage still does
  its own env-split internally).
