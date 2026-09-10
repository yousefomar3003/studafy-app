# ADR-0012: Flutter feature boundaries and the first typed vertical slice

Status: Accepted. Decision-log: DL-019–DL-023, DL-025.
Date: 2026-09-10. Implements ARC-011 (Phase 1B).

## Context

The audit found 130 direct `StudafyDatabase` call sites from widgets, a
mutable `ActiveContextController` singleton with a demo fallback outside
synthetic builds, untyped `Map<String, Object?>` flowing through every
screen, and parent/student features importing `DeleteAccountPage` from
teacher_features.dart. ARC-011 requires removing this coupling one vertical
slice at a time, starting with "session + class read".

## Decision

1. **Feature folder structure** under `lib/features/{name}/`:
   `domain/` (entities + ports, no framework imports), `application/`
   (interactors, domain + core only), `data/` (adapters, may import
   sqflite/Supabase), `presentation/` (widgets, application + domain + core
   only). Enforced by `tools/check_dart_bounds.dart` in CI.

2. **Composition root** at `lib/app/app_dependencies.dart`: builds the
   interactors once per runtime policy (synthetic → demo/preview adapters,
   remote → Supabase adapters). Widgets receive interactors via
   constructor injection; no widget ever constructs a repository or sees
   an adapter type.

3. **First slice: session + class read**
   - `features/session/`: `SessionInteractor` (OAuth → consent → profile →
     matching membership → term resolution → hydrate the immutable context).
     The demo fallback in `ActiveContextController.switchRole` and
     `startDemoRole` now refuses every non-synthetic runtime — the Phase 1
     gate item "production flavour contains no demo authorization".
   - `features/classes/`: `ClassListInteractor` → `ClassroomRepository`
     port → `PreviewClassroomRepository` (wraps the existing
     `StudafyDatabase.classes()` — the old preview read path preserved) and
     `SupabaseClassroomRepository` (RLS-scoped PostgREST read of classrooms
     with terms + enrollment counts). The typed `ClassesPage` replaces the
     legacy `DatabaseClassesPage`; `ClassWorkspacePage` stays legacy, fed
     through a documented `toLegacyMap()` bridge (slice-2 debt).

4. **Account feature move**: `DeleteAccountPage` moved verbatim to
   `lib/features/account/presentation/` to break the parent/student →
   teacher cross-feature import. The account feature is legacy-exempt
   from the boundary rules until its own slice migrates it behind an
   `AccountRepository`.

5. **Dead code removal**: the unreachable static `ClassesPage` and
   `ClassDialog` in main.dart (1289–1372/1410–1515, verified never
   referenced by the shell) were removed.

6. **Typed contracts with generated-client drift detection**:
   `packages/contracts/openapi/v1.json` is the canonical OpenAPI 3.1 contract
   for `/v1/me` and `/v1/classrooms`. `scripts/generate-dart-client.ts`
   deterministically generates the checked-in Dart DTOs and transport client.
   CI rejects stale generation; bun tests compare OpenAPI schema keys and
   operation IDs with the zod contracts, and both TypeScript and Dart validate
   the shared fixture. No API routes are activated; the contracts exist for
   Phase 3's Hono implementation.

7. **Legacy countdown after the 2026-09-11 hotspot follow-up**:
   modules under `lib/legacy/teacher/`, `student_features.dart`,
   `student_linking.dart`, and `features/account/**` still contain direct
   preview-database calls and require later vertical slices.
   `teacher_features.dart` is only a 34-line compatibility library; its former
   4,690-line body is divided into 14 responsibility-focused legacy modules,
   each below 600 lines. A regression test counts the existing 62 teacher
   preview-database calls so decomposition cannot be mistaken for completing
   their repository migration. `main.dart`, `parent_features.dart`, the teacher
   dashboard, and Study Coach no longer call persistence/providers from
   presentation. `studafy_database.dart` is now a small facade over bounded
   local-data modules. The checker hard rule even for legacy remains: no file
   may import `features/*/data/`.

8. **SQL portability fix** (incidental): the ffi test suite exposed
   double-quoted SQL string literals in `studafy_database.dart` (28
   occurrences) that work on mobile SQLite but fail on strict desktop
   engines. All were converted to single-quoted literals — a mechanical
   portability fix, not a rewrite.

9. **Hotspot decomposition follow-up** (DL-025):
   - `main.dart` owns startup/theme/routes only; `AppBootstrap` owns adapter
     initialization and `app/teacher_shell.dart` owns cross-feature routing.
   - The parent UI is divided into page/component library parts under
     `features/parent/presentation`; all data access goes through an injected
     `ParentRepository`. The remote adapter is deliberately unavailable until
     its authenticated API slice exists, preventing SQLite fallback.
   - The teacher dashboard uses typed attendance/notebook contracts and an
     injected repository. Its remote adapter also fails closed.
   - `studafy_database.dart` is a 106-line facade; schema/seed, learning,
     assessments, teaching, operations, and account/family queries live in six
     `data/local` modules.
   - Study Coach now has separate domain, application-policy, data-adapter, and
     presentation-scope modules. Attachment rejection occurs in the
     application layer before provider invocation.
   - Boundary enforcement scans forbidden persistence/provider symbols as well
     as imports, including Dart `part` files.

## Boundary matrix (enforced by `tools/check_dart_bounds.dart`)

| Zone | May import | May NOT import |
|---|---|---|
| `features/*/domain/` | core (ids, failures, result, domain models) | any feature zone, data, app |
| `features/*/application/` | own domain, core | own data/presentation, other features, data-layer modules |
| `features/*/data/` | own domain, core, studafy_database, supabase_flutter | own presentation/application, other features |
| `features/*/presentation/` | own application + domain, core, Flutter | own data, other features, data-layer modules |

Relative and package imports are normalized before checking. Supabase and
SQLite packages and symbols are data-zone-only; unreviewed third-party/internal
imports fail closed. Dedicated negative tests prove provider-package,
relative presentation-to-data, and hidden part-file persistence violations are
rejected.

## Consequences

- The first slice contains zero widget SQL, zero provider calls, and zero
  dynamic transport casts — verified by the boundary checker + analyze +
  review.
- All 22 existing UX tests pass unchanged (plus 17 new tests: session
  interactor, classes adapter over ffi SQLite, contract drift, demo denial).
- The demo fallback is now structurally impossible outside synthetic builds.
- Future slices follow this pattern: add feature folder, implement port +
  adapters, extract presentation, delete the legacy code path, shrink the
  exemption list.
