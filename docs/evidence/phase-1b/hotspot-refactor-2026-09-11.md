# Phase 1B hotspot decomposition — 2026-09-11

Scope: local repository refactor only. No Supabase, GitHub, staging, or
production mutation was performed.

## Structural result

| Former hotspot | Before | Current facade/entry | Extracted responsibility |
|---|---:|---:|---|
| `lib/main.dart` | 989 lines | 272 lines | Bootstrap initialization, teacher shell, and teacher dashboard presentation moved to bounded modules |
| `lib/parent_features.dart` | 4,425 lines | 47 lines | Shell, home, academics, insights, behaviour, account, messages, and their components split into 12 presentation files; largest is 582 lines |
| `lib/studafy_database.dart` | 1,333 lines | 106 lines | Six `lib/data/local/studafy_database_*.dart` modules; largest is the 467-line schema/seed module |
| `lib/data/study_coach_repository.dart` | 88 lines | Removed | Domain port/models, application containment policy, Supabase adapter, unavailable adapter, and presentation scope separated |
| `lib/teacher_features.dart` | 4,690 lines | 34 lines | Fourteen responsibility-focused legacy teacher presentation modules for shared UI, class workspace, gradebook, assessment, content, communications, chats, notifications, account, family, profile, policies, and connections; largest is 571 lines |

## Security and dependency result

- `main.dart`, parent presentation, and teacher-dashboard presentation contain
  no `StudafyDatabase`, `StudafyBackend`, raw SQL, or function-invocation call.
- Parent and teacher remote adapters throw stable feature-unavailable failures;
  they cannot fall back to synthetic SQLite data.
- `AppBootstrap` initializes SQLite only for the synthetic runtime.
- Study Coach attachment rejection occurs in `StudyCoachInteractor` before the
  repository is called. A recording-adapter test proves zero invocations.
- Supabase response errors are mapped to a generic Study Coach error instead of
  displaying provider response bodies.
- Architecture enforcement checks both normalized imports and forbidden data
  symbols, closing the Dart `part`-file loophole.
- A structural regression test requires the teacher library entry to remain
  below 75 lines, every extracted teacher module below 600 lines, and the
  existing 62 preview-database call sites to never increase. Those calls are
  explicitly legacy debt, not considered a migrated feature boundary.

## Verification

- `dart format`: 99 files checked, clean.
- Dart boundary checker: 41 feature files, 1 documented legacy exemption,
  0 violations.
- `flutter analyze`: no issues.
- `flutter test --concurrency=1`: 56 pass, 0 fail.
- Synthetic Android debug build: pass.
- Bun workspace: frozen install, format, lint, generated-client drift,
  boundaries, 9/9 type checks, and API/worker bundle builds pass; 47 tests pass
  and four service-backed tests were skipped because the already-verified
  disposable services were stopped.
- Deno Edge Functions: format, lint, frozen check, and 4/4 tests pass.
- Gitleaks source snapshot: 361 existing tracked/untracked non-ignored files,
  0 findings.
- New regression coverage: six structural hotspot assertions, three
  fail-closed repository/policy assertions, and a fourth negative architecture
  fixture for persistence hidden in a presentation part.

## Remaining bounded debt

This refactor does not claim that the entire Flutter prototype is migrated.
There are 98 direct preview-database calls remaining in legacy teacher modules,
the large student file, student linking, and the account page. The teacher
monolith is structurally removed, but its 62 direct calls deliberately remain
under `lib/legacy/teacher/` until repository-backed vertical slices replace
them; moving code did not disguise that boundary debt. Parent repository
results are temporarily map-shaped behind the port; each later API-backed
vertical slice must replace them with typed entities. Production remains
blocked, and no server route was activated.
